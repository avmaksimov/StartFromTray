#requires -Version 5.1
<#
Creates a portable StartFromTray Win32 release.
- Increments BuildNr in StartFromTray.lpi exactly once.
- Builds with Lazarus without an additional auto-increment.
- Verifies the generated EXE architecture and version.
- Packs the EXE, documentation under Docs/, languages, and MMC configuration.
- Uses a hand-maintained _FileList.txt with wildcard masks for release selection.
- Writes SHA-256 and restores the original .lpi if any step fails.

Run from PowerShell:
    .\_Create-Release.ps1

When launched via Explorer's "Run with PowerShell", the script waits for
one keypress before closing its temporary console. In an existing terminal,
no pause is needed. No parameters or additional scripts are required.
#>

# Explorer starts the script in a temporary PowerShell window. Detect that
# launch by its parent process, rather than adding a command-line switch.
$shouldPause = $false
if ($Host.Name -eq 'ConsoleHost') {
    try {
        $selfProcess = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $PID" -ErrorAction Stop
        if ($null -ne $selfProcess -and $selfProcess.ParentProcessId -gt 0) {
            $parentProcess = Get-Process -Id $selfProcess.ParentProcessId -ErrorAction Stop
            $shouldPause = $parentProcess.ProcessName -ieq 'explorer'
        }
    }
    catch {
        # If the parent cannot be determined, proceed without a pause.
    }
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$appName = 'StartFromTray'
$architecture = 'win32'
$buildMode = 'Release Win32'
$fileListPath = Join-Path $root '_FileList.txt'

$projectFile = Join-Path $root 'StartFromTray.lpi'
$exeFile = Join-Path $root 'StartFromTray.exe'
$languageDir = Join-Path $root 'Langs'
# Accept both source names; package documentation as Docs/ in either case.
$docsDir = Join-Path $root 'Docs'
if (-not (Test-Path -LiteralPath $docsDir -PathType Container)) {
    $docsDir = Join-Path $root 'docs'
}
$mmcFile = Join-Path $root 'mmc-remote.ini'
$updateFile = Join-Path $root 'update.ps1'
$installFile = Join-Path $root 'install.ps1'
$distDir = Join-Path $root 'dist'
$backupFile = $projectFile + '.release.bak'

$requiredDocs = @('LICENSE', 'README.md', 'README.ru.md', 'INTEGRATION.ru.md')

function Get-FileRules([string]$ListPath) {
    if (-not (Test-Path -LiteralPath $ListPath -PathType Leaf)) {
        throw "File mask list not found: $ListPath"
    }
    $rules = New-Object System.Collections.Generic.List[object]
    foreach ($raw in [IO.File]::ReadAllLines($ListPath, [Text.Encoding]::UTF8)) {
        $pattern = $raw.Trim().Replace('\','/')
        if ($pattern -eq '' -or $pattern.StartsWith('#')) { continue }
        $exclude = $pattern.StartsWith('!')
        if ($exclude) { $pattern = $pattern.Substring(1) }
        if ([string]::IsNullOrWhiteSpace($pattern) -or
            $pattern.StartsWith('/') -or $pattern -match '^[A-Za-z]:' -or
            $pattern -match '[<>:"|]' -or
            $pattern -match '(^|/)\.\.?(/|$)') {
            throw "Unsafe file mask: $raw"
        }
        foreach ($part in $pattern.Split('/')) {
            if ($part -eq '' -or $part.EndsWith('.') -or $part.EndsWith(' ')) {
                throw "Invalid file mask: $raw"
            }
        }
        $regexText = New-Object System.Text.StringBuilder
        [void]$regexText.Append('^')
        foreach ($ch in $pattern.ToCharArray()) {
            if ($ch -eq '*') { [void]$regexText.Append('[^/]*') }
            elseif ($ch -eq '?') { [void]$regexText.Append('[^/]') }
            else { [void]$regexText.Append([regex]::Escape([string]$ch)) }
        }
        [void]$regexText.Append('$')
        $rules.Add([pscustomobject]@{ Pattern=$pattern; Exclude=$exclude;
            Regex=[regex]::new($regexText.ToString(), [Text.RegularExpressions.RegexOptions]::IgnoreCase) })
    }
    if (@($rules | Where-Object { -not $_.Exclude }).Count -eq 0) {
        throw 'No inclusion masks in _FileList.txt.'
    }
    return $rules.ToArray()
}

function Test-FileRules([string]$RelativeName, [object[]]$Rules) {
    $selected = $false
    $name = $RelativeName.Replace('\','/')
    foreach ($rule in $Rules) {
        if ($rule.Regex.IsMatch($name)) { $selected = -not $rule.Exclude }
    }
    return $selected
}


$stagingDir = $null
$zipFile = $null
$hashFile = $null
$backupCreated = $false
$completed = $false
$exitCode = 1

try {
    if (-not (Test-Path -LiteralPath $projectFile -PathType Leaf)) {
        throw "Project file not found: $projectFile"
    }
    if (-not (Test-Path -LiteralPath $mmcFile -PathType Leaf)) {
        throw "MMC configuration not found: $mmcFile"
    }
    foreach ($script in @($updateFile, $installFile)) {
        if (-not (Test-Path -LiteralPath $script -PathType Leaf)) {
            throw "Release script not found: $script"
        }
    }
    foreach ($name in $requiredDocs) {
        $path = Join-Path $docsDir $name
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Required documentation file not found: $path"
        }
    }

    $fileRules = @(Get-FileRules $fileListPath)

    $lazbuildCommand = Get-Command -Name lazbuild.exe -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    $lazbuild = $null
    if ($null -ne $lazbuildCommand) {
        $lazbuild = $lazbuildCommand.Source
    }
    if (-not $lazbuild) {
        $candidates = @(
            'C:\Programs\Lazarus\lazbuild.exe',
            'C:\lazarus\lazbuild.exe',
            (Join-Path $env:ProgramFiles 'Lazarus\lazbuild.exe')
        )
        $lazbuild = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
            Select-Object -First 1
    }
    if (-not $lazbuild) {
        throw 'lazbuild.exe not found. Add Lazarus to PATH or install it in a standard location.'
    }

    # lazbuild normally knows the FPC executable through its Lazarus configuration,
    # but Fppkg also searches PATH. Derive an absolute FPC path from the detected
    # Lazarus installation when possible; do not assume a fixed drive or version.
    if (-not (Get-Command -Name fpc.exe -CommandType Application -ErrorAction SilentlyContinue)) {
        $fpcRoot = Join-Path (Split-Path -Parent $lazbuild) 'fpc'
        if (Test-Path -LiteralPath $fpcRoot -PathType Container) {
            $fpcExecutable = Get-ChildItem -LiteralPath $fpcRoot -Filter 'fpc.exe' -File -Recurse -ErrorAction SilentlyContinue |
                Sort-Object @{ Expression = { $_.DirectoryName -notmatch '\\x86_64-win64$' } }, FullName |
                Select-Object -First 1
            if ($null -ne $fpcExecutable) {
                $env:PATH = $fpcExecutable.DirectoryName + ';' + $env:PATH
                Write-Host "FPC found at: $($fpcExecutable.FullName)"
            }
        }
    }

    # Keep an exact byte-for-byte backup, preserving BOM and line endings.
    $originalBytes = [System.IO.File]::ReadAllBytes($projectFile)
    $hasBom = $originalBytes.Length -ge 3 -and
        $originalBytes[0] -eq 239 -and
        $originalBytes[1] -eq 187 -and
        $originalBytes[2] -eq 191
    $utf8 = [System.Text.UTF8Encoding]::new($hasBom, $true)
    $offset = if ($hasBom) { 3 } else { 0 }
    $projectText = $utf8.GetString($originalBytes, $offset, $originalBytes.Length - $offset)

    [xml]$projectXml = $projectText
    $versionInfo = $projectXml.CONFIG.ProjectOptions.VersionInfo
    if ($null -eq $versionInfo -or $versionInfo.UseVersionInfo.Value -ne 'True') {
        throw 'Version information is missing or disabled in StartFromTray.lpi.'
    }

    $major = [int]$versionInfo.MajorVersionNr.Value
    $minor = [int]$versionInfo.MinorVersionNr.Value
    $build = [int]$versionInfo.BuildNr.Value
    if ($major -lt 0 -or $major -gt 65535 -or
        $minor -lt 0 -or $minor -gt 65535 -or
        $build -lt 0 -or $build -ge 65535) {
        throw "Invalid or exhausted project version: $major.$minor.$build"
    }

    $nextBuild = $build + 1
    $version = "$major.$minor.$nextBuild"
    $packageName = "$appName-v$version-$architecture"
    $stagingDir = Join-Path $distDir $packageName
    $zipFile = Join-Path $distDir "$packageName.zip"
    $hashFile = $zipFile + '.sha256'

    foreach ($path in @($stagingDir, $zipFile, $hashFile, $backupFile)) {
        if (Test-Path -LiteralPath $path) {
            throw "Output or backup already exists; nothing changed: $path"
        }
    }

    $buildMatches = [regex]::Matches($projectText, '<BuildNr\s+Value="([0-9]+)"\s*/>')
    if ($buildMatches.Count -ne 1 -or $buildMatches[0].Groups[1].Value -ne [string]$build) {
        throw 'Unexpected BuildNr declaration in StartFromTray.lpi.'
    }
    $valueGroup = $buildMatches[0].Groups[1]
    $modifiedText = $projectText.Substring(0, $valueGroup.Index) +
        [string]$nextBuild + $projectText.Substring($valueGroup.Index + $valueGroup.Length)

    Write-Host "Release version: $version (Build $build -> $nextBuild)"
    Write-Host "Lazarus: $lazbuild"

    # Backup is never overwritten. It is restored if release creation fails.
    [System.IO.File]::WriteAllBytes($backupFile, $originalBytes)
    $backupCreated = $true
    [System.IO.File]::WriteAllText($projectFile, $modifiedText, $utf8)

    Write-Host "Building $appName in '$buildMode' mode..."
    & $lazbuild '--build-all' '--no-write-project' "--build-mode=$buildMode" $projectFile
    if ($LASTEXITCODE -ne 0) {
        throw "Lazarus build failed (exit code $LASTEXITCODE)."
    }
    if (-not (Test-Path -LiteralPath $exeFile -PathType Leaf)) {
        throw "Compiled EXE was not created: $exeFile"
    }

    # Verify PE signature and i386 machine ID (014C).
    $exeBytes = [System.IO.File]::ReadAllBytes($exeFile)
    if ($exeBytes.Length -lt 64 -or $exeBytes[0] -ne 0x4D -or $exeBytes[1] -ne 0x5A) {
        throw 'Generated EXE has an invalid DOS/PE header.'
    }
    $peOffset = [BitConverter]::ToInt32($exeBytes, 60)
    if ($peOffset -lt 0 -or $peOffset + 6 -gt $exeBytes.Length -or
        [BitConverter]::ToUInt32($exeBytes, $peOffset) -ne 0x00004550) {
        throw 'Generated EXE has an invalid PE signature.'
    }
    $machine = [BitConverter]::ToUInt16($exeBytes, $peOffset + 4)
    if ($machine -ne 0x014C) {
        throw ('Expected Win32/i386 PE machine 014C, got {0:X4}.' -f $machine)
    }

    $fileVersion = [Diagnostics.FileVersionInfo]::GetVersionInfo($exeFile)
    $actualVersion = '{0}.{1}.{2}' -f $fileVersion.FileMajorPart,
        $fileVersion.FileMinorPart, $fileVersion.FilePrivatePart
    if ($actualVersion -ne $version) {
        throw "Compiled EXE version $actualVersion differs from expected $version."
    }

    # Evaluate the file masks against package-relative paths. All docs source
    # files are published under Docs/, regardless of docs/ spelling in Git.
    $selectedFiles = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::OrdinalIgnoreCase)
    $protected = @('startfromtray.ini','items.xml','filters.ini',
        'langs/default.ini','_filelist.txt','install.psd1',
        'startfromtray.update.ini','startfromtray.update.log',
        'startfromtray.update.log.1','startfromtray.tray.log')
    $sources = New-Object System.Collections.Generic.List[object]
    foreach ($file in @(Get-ChildItem -LiteralPath $root -File -Force)) {
        $sources.Add([pscustomobject]@{ Name=$file.Name; Path=$file.FullName })
        if ($file.Name -ieq 'CHANGELOG.md') {
            $sources.Add([pscustomobject]@{ Name='Docs/CHANGELOG.md'; Path=$file.FullName })
        }
    }
    foreach ($folder in @('Langs','Docs')) {
        $sourceFolder = if ($folder -eq 'Docs') { $docsDir } else { $languageDir }
        if (-not (Test-Path -LiteralPath $sourceFolder -PathType Container)) { continue }
        foreach ($file in @(Get-ChildItem -LiteralPath $sourceFolder -File -Recurse -Force)) {
            $relative = $file.FullName.Substring($sourceFolder.Length).TrimStart('\','/').Replace('\','/')
            $sources.Add([pscustomobject]@{ Name=($folder + '/' + $relative); Path=$file.FullName })
        }
    }
    foreach ($source in $sources) {
        if (-not (Test-FileRules $source.Name $fileRules)) { continue }
        if ($protected -contains $source.Name.ToLowerInvariant()) {
            throw "File mask selects protected data: $($source.Name)"
        }
        $attributes = [IO.File]::GetAttributes($source.Path)
        if (($attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Cannot package a symbolic link: $($source.Name)"
        }
        if ($selectedFiles.ContainsKey($source.Name)) {
            throw "More than one source for file: $($source.Name)"
        }
        $selectedFiles.Add($source.Name, $source.Path)
    }
    $releaseNames = @($selectedFiles.Keys | Sort-Object)
    foreach ($required in @('StartFromTray.exe','update.ps1','install.ps1','mmc-remote.ini')) {
        if (-not $selectedFiles.ContainsKey($required)) {
            throw "Required file not included by _FileList.txt: $required"
        }
    }
    foreach ($required in $requiredDocs) {
        if (-not $selectedFiles.ContainsKey("Docs/$required")) {
            throw "Required documentation not included by _FileList.txt: Docs/$required"
        }
    }
    if (@($releaseNames | Where-Object { $_ -like 'Langs/*.ini' }).Count -eq 0) {
        throw 'No language files selected by _FileList.txt.'
    }
    foreach ($name in $releaseNames) {
        $destination = Join-Path $stagingDir ($name.Replace('/', '\'))
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Copy-Item -LiteralPath $selectedFiles[$name] -Destination $destination -Force
    }
    # Keep the hand-written masks intact, in the archive for first-run registration.
    Copy-Item -LiteralPath $fileListPath -Destination (Join-Path $stagingDir '_FileList.txt') -Force

    # Do not package user-specific/generated files:
    # StartFromTray.ini, Items.xml, Filters.ini, Langs/Default.ini.
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    Write-Host "Creating: $zipFile"
    [System.IO.Compression.ZipFile]::CreateFromDirectory(
        $stagingDir, $zipFile, [System.IO.Compression.CompressionLevel]::Optimal, $false)

    $archive = [System.IO.Compression.ZipFile]::OpenRead($zipFile)
    try {
        # ZIP entry names from .NET Framework may use either slash style.
        # Normalize them before checking the required package contents.
        $entries = @($archive.Entries | ForEach-Object { $_.FullName.Replace('\', '/') })
        foreach ($name in @("$appName.exe", 'mmc-remote.ini', 'update.ps1', 'install.ps1', '_FileList.txt')) {
            if ($entries -cnotcontains $name) {
                throw "Missing ZIP entry: $name"
            }
        }
        # The ZIP must match the generated inventory, apart from that inventory itself.
        $archiveFileNames = @($entries | Where-Object { $_ -notmatch '/$' -and $_ -cne '_FileList.txt' })
        $missingFiles = @($releaseNames | Where-Object { $archiveFileNames -cnotcontains $_ })
        $unexpectedFiles = @($archiveFileNames | Where-Object { $releaseNames -cnotcontains $_ })
        if ($missingFiles.Count -gt 0 -or $unexpectedFiles.Count -gt 0) {
            throw 'ZIP contents differ from files selected by _FileList.txt.'
        }
        foreach ($name in $requiredDocs) {
            $entry = "Docs/$name"
            if ($entries -cnotcontains $entry) {
                throw "Missing ZIP entry: $entry"
            }
        }
        $hasLanguages = @($entries | Where-Object { $_ -like 'Langs/*.ini' }).Count -gt 0
        if (-not $hasLanguages) {
            throw 'ZIP is missing Langs/*.ini files.'
        }
    }
    finally {
        $archive.Dispose()
    }

    $digest = (Get-FileHash -LiteralPath $zipFile -Algorithm SHA256).Hash.ToLowerInvariant()
    $hashLine = "$digest *$([System.IO.Path]::GetFileName($zipFile))`r`n"
    [System.IO.File]::WriteAllText($hashFile, $hashLine, [System.Text.Encoding]::ASCII)

    $completed = $true
    $exitCode = 0
    Write-Host ''
    Write-Host 'Release package created successfully.' -ForegroundColor Green
    Write-Host "ZIP:    $zipFile"
    Write-Host "SHA256: $hashFile"
}
catch {
    Write-Host ''
    Write-Host ("ERROR: " + $_.Exception.Message) -ForegroundColor Red
}
finally {
    if ($backupCreated) {
        $restored = $false
        if (-not $completed) {
            try {
                [System.IO.File]::Copy($backupFile, $projectFile, $true)
                $restored = $true
                Write-Host 'Restored the original StartFromTray.lpi.'
            }
            catch {
                Write-Warning "Could not restore StartFromTray.lpi. Original is preserved at $backupFile. $($_.Exception.Message)"
            }
        }
        if ($completed -or $restored) {
            try {
                Remove-Item -LiteralPath $backupFile -Force -ErrorAction Stop
            }
            catch {
                Write-Warning "Could not remove project backup: $backupFile ($($_.Exception.Message))"
            }
        }
    }

    if ($completed) {
        try {
            Remove-Item -LiteralPath $stagingDir -Recurse -Force -ErrorAction Stop
        }
        catch {
            Write-Warning "Could not remove staging directory: $stagingDir"
        }
    }
    else {
        # Remove only outputs whose nonexistence was verified before the build.
        if ($backupCreated) {
            foreach ($path in @($hashFile, $zipFile, $stagingDir)) {
                if ($null -ne $path -and (Test-Path -LiteralPath $path)) {
                    try { Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction Stop }
                    catch { Write-Warning "Could not remove partial output: $path" }
                }
            }
        }
    }
}

if ($shouldPause) {
    Write-Host ''
    Write-Host 'Press any key to close...' -NoNewline
    try {
        $null = [Console]::ReadKey($true)
    }
    catch {
        # Some PowerShell hosts do not support reading a single key.
        try { $null = Read-Host } catch { }
    }
    Write-Host ''
}

exit $exitCode
