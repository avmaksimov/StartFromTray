#Requires -Version 5.1
# StartFromTray update coordinator; only -Check and -Update are public modes.
[CmdletBinding(DefaultParameterSetName = 'Check')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Check')]
    [switch]$Check,
    [Parameter(Mandatory = $true, ParameterSetName = 'Update')]
    [switch]$Update
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\')
$exe = Join-Path $root 'StartFromTray.exe'
$statePath = Join-Path $root 'StartFromTray.update.ini'
$logPath = Join-Path $root 'StartFromTray.update.log'
$apiUrl = 'https://api.github.com/repos/avmaksimov/StartFromTray/releases/latest'
$apiHeaders = @{ 'User-Agent'='StartFromTray-Updater'; 'Accept'='application/vnd.github+json'; 'Cache-Control'='no-cache' }
$exitCode = 0
$tempDir = $null
$mutex = $null
$mutexHeld = $false
$installStarted = $false
$localVersion = $null
$latestVersion = ''
$state = [ordered]@{ Check = [ordered]@{}; Update = [ordered]@{} }

function Write-UpdateLog([string]$Message) {
    $line = ('{0}  UPDATE   {1}{2}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff'), $Message, "`r`n")
    Write-Host $Message
    try {
        if ((Test-Path -LiteralPath $logPath -PathType Leaf) -and
            (Get-Item -LiteralPath $logPath).Length -ge 5MB) {
            $old = $logPath + '.1'
            if (Test-Path -LiteralPath $old) { Remove-Item -LiteralPath $old -Force }
            Move-Item -LiteralPath $logPath -Destination $old
        }
        [IO.File]::AppendAllText($logPath, $line, [Text.Encoding]::UTF8)
    }
    catch { Write-Warning "Unable to append update log: $($_.Exception.Message)" }
}

function Read-UpdateState {
    if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) { return }
    $section = ''
    foreach ($line in [IO.File]::ReadAllLines($statePath)) {
        if ($line -match '^\s*\[(Check|Update)\]\s*$') { $section = $Matches[1]; continue }
        if ($section -and $line -match '^\s*([A-Za-z][A-Za-z0-9]*)=(.*)$') {
            $state[$section][$Matches[1]] = $Matches[2]
        }
    }
}

function Save-UpdateState {
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($section in @('Check','Update')) {
        [void]$lines.Add("[$section]")
        foreach ($key in $state[$section].Keys) {
            $value = [string]$state[$section][$key]
            $value = $value.Replace("`r",' ').Replace("`n",' ').Trim()
            [void]$lines.Add("$key=$value")
        }
        [void]$lines.Add('')
    }
    $temporary = $statePath + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    try {
        [IO.File]::WriteAllText($temporary, ($lines -join "`r`n"), [Text.UTF8Encoding]::new($false))
        if (Test-Path -LiteralPath $statePath -PathType Leaf) {
            [IO.File]::Replace($temporary, $statePath, $null)
        }
        else { [IO.File]::Move($temporary, $statePath) }
    }
    finally {
        if (Test-Path -LiteralPath $temporary) {
            Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
        }
    }
}

function Set-CheckState([string]$Result, [string]$Version, [string]$ErrorText) {
    $state.Check['LastCheckUnix'] = [string][DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $state.Check['Result'] = $Result
    $state.Check['LatestVersion'] = $Version
    $state.Check['CurrentVersion'] = [string]$localVersion
    $state.Check['Error'] = $ErrorText
    Save-UpdateState
}

function Set-InstallState([string]$Status, [int]$Code, [string]$ErrorText) {
    $state.Update['Status'] = $Status
    $state.Update['ErrorCode'] = [string]$Code
    $state.Update['Error'] = $ErrorText
    $state.Update['Version'] = $latestVersion
    $state.Update['TimeUnix'] = [string][DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $state.Update['Reported'] = '0'
    Save-UpdateState
}

function Get-InstalledVersion {
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw "Executable not found: $exe" }
    $v = [Diagnostics.FileVersionInfo]::GetVersionInfo($exe)
    return [version]('{0}.{1}.{2}' -f $v.FileMajorPart, $v.FileMinorPart, $v.FilePrivatePart)
}

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

function Initialize-InstallManifest {
    # Never consume the developer's hand-maintained _FileList.txt from Git.
    if (Test-Path -LiteralPath (Join-Path $root 'StartFromTray.lpi') -PathType Leaf) { return }
    $manifest = Join-Path $root 'install.psd1'
    $fileList = Join-Path $root '_FileList.txt'
    if (Test-Path -LiteralPath $manifest -PathType Leaf) { return }
    if (-not (Test-Path -LiteralPath $fileList -PathType Leaf)) { return }

    $rules = @(Get-FileRules $fileList)
    $protected = @('startfromtray.ini','items.xml','filters.ini',
        'langs/default.ini','install.psd1','_filelist.txt',
        'startfromtray.update.ini','startfromtray.update.log',
        'startfromtray.update.log.1','startfromtray.tray.log')
    $names = New-Object System.Collections.Generic.List[string]
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($file in @(Get-ChildItem -LiteralPath $root -File -Recurse -Force)) {
        $name = $file.FullName.Substring($root.Length).TrimStart('\','/').Replace('\','/')
        if (-not (Test-FileRules $name $rules)) { continue }
        if ($protected -contains $name.ToLowerInvariant()) {
            throw "File mask selects protected data: $name"
        }
        if (($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "File mask matches symbolic link: $name"
        }
        if (-not $seen.Add($name)) { throw "Repeated package file: $name" }
        $names.Add($name)
    }
    foreach ($required in @('StartFromTray.exe','update.ps1','install.ps1')) {
        if (-not $seen.Contains($required)) { throw "Required file not found: $required" }
    }
    $manifestLines = New-Object System.Collections.Generic.List[string]
    [void]$manifestLines.Add('@{')
    [void]$manifestLines.Add("    'version' = '$localVersion'")
    [void]$manifestLines.Add("    'installed-files' = @(")
    foreach ($name in @($names | Sort-Object)) {
        [void]$manifestLines.Add("        '$($name.Replace("'", "''"))'")
    }
    [void]$manifestLines.Add('    )')
    [void]$manifestLines.Add('}')
    $tmp = $manifest + '.new-' + [guid]::NewGuid().ToString('N')
    try {
        [IO.File]::WriteAllText($tmp, (($manifestLines -join "`r`n") + "`r`n"),
            [Text.UTF8Encoding]::new($false))
        [IO.File]::Move($tmp, $manifest)
    }
    finally {
        if (Test-Path -LiteralPath $tmp -PathType Leaf) {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        }
    }
    # The rules stay in the source repository, but not the installed program.
    try { Remove-Item -LiteralPath $fileList -Force -ErrorAction Stop }
    catch { Write-UpdateLog "install.psd1 created; could not delete _FileList.txt: $($_.Exception.Message)" }
    Write-UpdateLog "Registered $($names.Count) files in install.psd1."
}

function Get-LatestRelease {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $release = Invoke-RestMethod -Uri $apiUrl -Headers $apiHeaders -UseBasicParsing -TimeoutSec 25
    if (-not $release.tag_name -or $release.prerelease -or $release.draft) {
        throw 'GitHub returned an invalid release version.'
    }
    $tagMatch = [regex]::Match([string]$release.tag_name, '^v([0-9]+\.[0-9]+\.[0-9]+)$')
    if (-not $tagMatch.Success) { throw 'GitHub returned an invalid release version.' }
    $versionText = $tagMatch.Groups[1].Value
    $versionValue = [version]$versionText
    $archiveName = "StartFromTray-v$versionText-win32.zip"
    $asset = @($release.assets | Where-Object { $_.name -ceq $archiveName })
    if ($asset.Count -ne 1) { throw "Release asset not found or ambiguous: $archiveName" }
    $digestMatch = [regex]::Match([string]$asset[0].digest, '^sha256:([0-9a-fA-F]{64})$')
    if (-not $digestMatch.Success) {
        throw 'Release ZIP lacks a SHA-256 digest in GitHub metadata.'
    }
    $sha256 = $digestMatch.Groups[1].Value.ToUpperInvariant()
    if ($asset[0].browser_download_url -notlike "https://github.com/avmaksimov/StartFromTray/releases/download/*") {
        throw 'Unexpected release asset origin.'
    }
    return [pscustomobject]@{ Version = $versionValue; VersionText=$versionText;
        AssetUrl=$asset[0].browser_download_url; Sha256=$sha256; FileName=$archiveName }
}

function Verify-ExtractedArchive([string]$ExtractedRoot) {
    $mustExist = @('StartFromTray.exe','install.ps1','update.ps1','mmc-remote.ini','_FileList.txt')
    foreach ($name in $mustExist) {
        if (-not (Test-Path -LiteralPath (Join-Path $ExtractedRoot $name) -PathType Leaf)) {
            throw "Archive is missing $name"
        }
    }
    $allFiles = @(Get-ChildItem -LiteralPath $ExtractedRoot -File -Recurse -Force)
    if ($allFiles.Count -eq 0 -or $allFiles.Count -gt 200) { throw 'Unexpected release file count.' }
    # The downloaded package must contain only files allowed by its rules.
    $rules = @(Get-FileRules (Join-Path $ExtractedRoot '_FileList.txt'))
    foreach ($file in $allFiles) {
        $relative = $file.FullName.Substring($ExtractedRoot.Length).TrimStart('\','/').Replace('\','/')
        if ($relative -eq '_FileList.txt') { continue }
        if (-not (Test-FileRules $relative $rules)) {
            throw "Unexpected file in release archive: $relative"
        }
    }
    $newExe = Join-Path $ExtractedRoot 'StartFromTray.exe'
    $v = [Diagnostics.FileVersionInfo]::GetVersionInfo($newExe)
    $extractedVersion = [version]('{0}.{1}.{2}' -f $v.FileMajorPart, $v.FileMinorPart, $v.FilePrivatePart)
    if ($extractedVersion -ne [version]$latestVersion) {
        throw "Archive executable version $extractedVersion differs from release $latestVersion."
    }
}

try {
    $mutex = New-Object System.Threading.Mutex($false, 'Local\StartFromTray.Update.{3A55B01F-07C3-4DC7-A7C0-C71A78C10B66}')
    try { $mutexHeld = $mutex.WaitOne(5000) }
    catch [Threading.AbandonedMutexException] { $mutexHeld = $true }
    if (-not $mutexHeld) { throw 'Another update operation is already running.' }
    Read-UpdateState
    $localVersion = Get-InstalledVersion

    if ($Check) {
        # Registration is local and non-disruptive. A read-only folder must
        # never prevent an otherwise successful update check.
        try { Initialize-InstallManifest }
        catch { Write-UpdateLog "Could not initialize install.psd1: $($_.Exception.Message)" }
        # Every explicit or hourly check contacts GitHub; do not reuse the
        # previous 24-hour result, which would defeat hourly monitoring.
        try {
            $release = Get-LatestRelease
            $latestVersion = $release.VersionText
            $exitCode = if ($release.Version -gt $localVersion) { 10 } else { 0 }
            Set-CheckState $(if ($exitCode -eq 10) { 'Available' } else { 'Current' }) $latestVersion ''
            Write-UpdateLog "Checked GitHub Releases: installed=$localVersion latest=$latestVersion code=$exitCode"
        }
        catch {
            $exitCode = 20
            Set-CheckState 'Error' '' $_.Exception.Message
            Write-UpdateLog "Version check failed: $($_.Exception.Message)"
        }
    }
    elseif ($Update) {
        Set-InstallState 'Running' 0 ''
        try { $release = Get-LatestRelease }
        catch {
            $exitCode = 20
            $message = $_.Exception.Message
            Set-InstallState 'Failed' $exitCode $message
            Write-UpdateLog "Update check failed: $message"
        }
        if ($exitCode -eq 0) {
            $latestVersion = $release.VersionText
            if ($release.Version -le $localVersion) {
                Set-InstallState 'Current' 0 ''
                Write-UpdateLog "Already current: $localVersion"
            }
            else {
                $tempDir = Join-Path $env:TEMP ('StartFromTray-Update-' + [guid]::NewGuid().ToString('N'))
                $zipFile = Join-Path $tempDir $release.FileName
                $extractDir = Join-Path $tempDir 'extracted'
                try {
                    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
                    Write-UpdateLog "Downloading verified release $latestVersion from GitHub."
                    Invoke-WebRequest -Uri $release.AssetUrl -Headers @{ 'User-Agent'='StartFromTray-Updater' } -OutFile $zipFile -UseBasicParsing -TimeoutSec 180 | Out-Null
                    $actualHash = (Get-FileHash -LiteralPath $zipFile -Algorithm SHA256).Hash
                    if ($actualHash -ine $release.Sha256) { throw 'Downloaded archive SHA-256 does not match GitHub release metadata.' }
                    Write-UpdateLog "Archive verified: SHA-256=$actualHash"
                    Add-Type -AssemblyName System.IO.Compression.FileSystem
                    $zip = [IO.Compression.ZipFile]::OpenRead($zipFile)
                    try {
                        $sum = 0L
                        $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
                        foreach ($entry in $zip.Entries) {
                            $path = $entry.FullName.Replace('\','/')
                            if ($path.StartsWith('/') -or $path -match '^[A-Za-z]:' -or
                                $path -match '(^|/)\.\.?(/|$)' -or
                                -not $seen.Add($path)) { throw "Unsafe ZIP entry: $path" }
                            $sum += $entry.Length
                            if ($sum -gt 200MB) { throw 'Uncompressed archive is unexpectedly large.' }
                        }
                    }
                    finally { $zip.Dispose() }
                    [IO.Compression.ZipFile]::ExtractToDirectory($zipFile, $extractDir)
                    Verify-ExtractedArchive $extractDir
                }
                catch {
                    $exitCode = 30
                    $message = $_.Exception.Message
                    Set-InstallState 'Failed' $exitCode $message
                    Write-UpdateLog "Download/verification failed: $message"
                }
                if ($exitCode -eq 0) {
                    try {
                        Write-UpdateLog "Handing over installation of $latestVersion."
                        $installStarted = $true
                        & (Join-Path $extractDir 'install.ps1') -TargetPath $root
                        Write-UpdateLog "Updated successfully to $latestVersion."
                        Set-InstallState 'Success' 0 ''
                        try {
                            Start-Process -FilePath $exe -WorkingDirectory $root -ErrorAction Stop | Out-Null
                            Write-UpdateLog 'Restarted StartFromTray.'
                        }
                        catch {
                            $exitCode = 60
                            $message = $_.Exception.Message
                            Set-InstallState 'Failed' $exitCode $message
                            Write-UpdateLog "Restart failed: $message"
                        }
                    }
                    catch {
                        $message = $_.Exception.Message
                        $exitCode = if ($message.StartsWith('STOP_FAILED:')) { 40 } else { 50 }
                        Set-InstallState 'Failed' $exitCode $message
                        Write-UpdateLog "Installation failed: $message"
                        # Restore the UI after a rolled-back installation failure.
                        # The GUI will read the Failed/Reported=0 state on startup.
                        try {
                            $stillRunning = @(Get-Process -Name StartFromTray -ErrorAction SilentlyContinue |
                                Where-Object { try { $_.Path -and ([IO.Path]::GetFullPath($_.Path) -ieq $exe) } catch { $false } }).Count -gt 0
                            if (-not $stillRunning -and (Test-Path -LiteralPath $exe -PathType Leaf)) {
                                Start-Process -FilePath $exe -WorkingDirectory $root -ErrorAction Stop | Out-Null
                                Write-UpdateLog 'Restarted the existing application after installation failure.'
                            }
                        }
                        catch { Write-UpdateLog "Recovery restart failed: $($_.Exception.Message)" }
                    }
                }
            }
        }
    }
}
catch {
    $message = $_.Exception.Message
    $exitCode = if ($Update) { 50 } else { 20 }
    try {
        if ($Update) { Set-InstallState 'Failed' $exitCode $message }
        else { Set-CheckState 'Error' '' $message }
    }
    catch { Write-Warning "Could not save update status: $($_.Exception.Message)" }
    Write-UpdateLog "ERROR: $message"
}
finally {
    if ($tempDir -and (Test-Path -LiteralPath $tempDir)) {
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    if ($mutexHeld) { try { $mutex.ReleaseMutex() } catch { } }
    if ($mutex) { $mutex.Dispose() }
}
exit $exitCode
