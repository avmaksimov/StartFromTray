#requires -Version 5.1
<#
Creates a portable StartFromTray Win32 release.
- Increments BuildNr in StartFromTray.lpi exactly once.
- Builds with Lazarus without an additional auto-increment.
- Verifies the generated EXE architecture and version.
- Packs the EXE, documentation under Docs/, languages, and MMC configuration.
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

    $languageFiles = @(Get-ChildItem -LiteralPath $languageDir -Filter '*.ini' -File |
        Where-Object { $_.Name -ine 'Default.ini' })
    if ($languageFiles.Count -eq 0) {
        throw "No distributable language files found in: $languageDir"
    }

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

    New-Item -ItemType Directory -Path (Join-Path $stagingDir 'Langs') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $stagingDir 'Docs') -Force | Out-Null
    Copy-Item -LiteralPath $exeFile -Destination (Join-Path $stagingDir "$appName.exe")
    Copy-Item -LiteralPath $mmcFile -Destination (Join-Path $stagingDir 'mmc-remote.ini')
    Copy-Item -LiteralPath $updateFile -Destination (Join-Path $stagingDir 'update.ps1')
    Copy-Item -LiteralPath $installFile -Destination (Join-Path $stagingDir 'install.ps1')
    foreach ($name in $requiredDocs) {
        Copy-Item -LiteralPath (Join-Path $docsDir $name) -Destination (Join-Path $stagingDir 'Docs')
    }
    $changelog = Join-Path $root 'CHANGELOG.md'
    if (Test-Path -LiteralPath $changelog -PathType Leaf) {
        Copy-Item -LiteralPath $changelog -Destination (Join-Path (Join-Path $stagingDir 'Docs') 'CHANGELOG.md')
    }
    foreach ($languageFile in $languageFiles) {
        Copy-Item -LiteralPath $languageFile.FullName -Destination (Join-Path $stagingDir 'Langs')
    }

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
        foreach ($name in @("$appName.exe", 'mmc-remote.ini', 'update.ps1', 'install.ps1')) {
            if ($entries -cnotcontains $name) {
                throw "Missing ZIP entry: $name"
            }
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
