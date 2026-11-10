#Requires -Version 5.1
# StartFromTray portable installer. No interactive per-file confirmation.
# Run only from a verified release extracted under TEMP by update.ps1.
[CmdletBinding()]
param([string]$TargetPath = '')

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$sourceRoot = [IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\')
if ([string]::IsNullOrWhiteSpace($TargetPath)) { $TargetPath = $sourceRoot }
$targetRoot = [IO.Path]::GetFullPath($TargetPath).TrimEnd('\')
$manifestName = 'install.psd1'
$manifest = Join-Path $targetRoot $manifestName
$logPath = Join-Path $targetRoot 'StartFromTray.update.log'
$workDir = Join-Path $env:TEMP ('StartFromTray-Install-' + [guid]::NewGuid().ToString('N'))
$stagedDir = Join-Path $workDir 'stage'
$backupDir = Join-Path $workDir 'backup'
$completed = $false
$rollbackOk = $true
$operations = New-Object System.Collections.Generic.List[object]
$backupIndex = @{}

function Write-InstallLog([string]$Text) {
    $line = ('{0}  INSTALL  {1}{2}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff'), $Text, "`r`n")
    Write-Host $Text
    try { [IO.File]::AppendAllText($logPath, $line, [Text.Encoding]::UTF8) }
    catch { Write-Warning "Could not write update log: $($_.Exception.Message)" }
}

function Assert-SafeRelativePath([string]$Relative) {
    if ([string]::IsNullOrWhiteSpace($Relative) -or
        $Relative.StartsWith('/') -or $Relative.StartsWith('\') -or
        $Relative -match '^[A-Za-z]:' -or
        $Relative -match '[<>:"|?*]' -or
        $Relative -match '(?i)(^|/|\\)\.\.?($|/|\\)') {
        throw "Unsafe package file name: $Relative"
    }
    $parts = $Relative.Replace('\','/').Split('/')
    foreach ($part in $parts) {
        if ($part.Length -eq 0 -or $part.EndsWith('.') -or $part.EndsWith(' ') -or
            $part.IndexOfAny([char[]]@(0,10,13)) -ge 0) {
            throw "Unsafe package path component: $Relative"
        }
    }
}

function Assert-NoReparsePath([string]$FullPath) {
    $current = $FullPath
    while (-not [string]::IsNullOrWhiteSpace($current) -and (Test-Path -LiteralPath $current)) {
        $attributes = (Get-Item -LiteralPath $current -Force -ErrorAction Stop).Attributes
        if (($attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Refusing to follow a symbolic link/junction: $current"
        }
        $parent = [IO.Path]::GetDirectoryName($current)
        if ($parent -eq $current) { break }
        $current = $parent
    }
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

function New-ManifestText([string[]]$Names, [string]$Version) {
    $lines = New-Object System.Collections.Generic.List[string]
    [void]$lines.Add('@{')
    [void]$lines.Add("    'version' = '$($Version.Replace("'","''"))'")
    [void]$lines.Add("    'installed-files' = @(")
    foreach ($name in $Names) {
        [void]$lines.Add("        '$($name.Replace("'","''"))'")
    }
    [void]$lines.Add('    )')
    [void]$lines.Add('}')
    return (($lines -join "`r`n") + "`r`n")
}

function Stop-InstalledApplication([string]$ExePath) {
    # Only the executable at this exact path can be stopped.
    $target = [IO.Path]::GetFullPath($ExePath)
    $instances = New-Object System.Collections.Generic.List[object]
    foreach ($candidate in @(Get-Process -Name StartFromTray -ErrorAction SilentlyContinue)) {
        $candidatePath = $null
        try { $candidatePath = $candidate.Path } catch { }
        if (-not $candidatePath) {
            throw "Unable to identify running StartFromTray PID $($candidate.Id). Installation will not start."
        }
        if ([IO.Path]::GetFullPath($candidatePath) -ieq $target) {
            $instances.Add($candidate)
        }
    }
    if ($instances.Count -eq 0) { return }

    if (-not ('StartFromTrayExitSignal' -as [type])) {
        Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class StartFromTrayExitSignal {
    private const string PropName = "StartFromTray.MainWindow.{3A55B01F-07C3-4DC7-A7C0-C71A78C10B66}";
    private const string MessageName = "StartFromTray.RequestExit.{3A55B01F-07C3-4DC7-A7C0-C71A78C10B66}";
    private delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr data);
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumWindowsProc callback, IntPtr data);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern IntPtr GetProp(IntPtr hwnd, string name);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern uint RegisterWindowMessage(string name);
    [DllImport("user32.dll", SetLastError=true)] private static extern bool PostMessage(IntPtr hwnd, uint msg, IntPtr wp, IntPtr lp);
    public static bool RequestExit(int targetPid) {
        uint message = RegisterWindowMessage(MessageName);
        if (message == 0) return false;
        bool posted = false;
        EnumWindows(delegate(IntPtr hwnd, IntPtr unused) {
            uint pid;
            GetWindowThreadProcessId(hwnd, out pid);
            if (pid == (uint)targetPid && GetProp(hwnd, PropName) != IntPtr.Zero) {
                posted = PostMessage(hwnd, message, IntPtr.Zero, IntPtr.Zero);
                return false;
            }
            return true;
        }, IntPtr.Zero);
        return posted;
    }
}
'@
    }

    foreach ($proc in $instances) {
        $pidToStop = $proc.Id
        $signaled = [StartFromTrayExitSignal]::RequestExit($pidToStop)
        Write-InstallLog "RequestExit PID=$pidToStop sent=$signaled"
        if (-not $proc.WaitForExit(10000)) {
            # Process identity is rechecked before the forced termination.
            $live = Get-Process -Id $pidToStop -ErrorAction SilentlyContinue
            if ($null -ne $live) {
                $livePath = $null
                try { $livePath = $live.Path } catch { }
                if (-not $livePath -or [IO.Path]::GetFullPath($livePath) -ine $target) {
                    throw "Unable to verify the process before force-closing PID $pidToStop."
                }
                Write-InstallLog "PID=$pidToStop ignored graceful exit; forcing termination."
                Stop-Process -Id $pidToStop -Force -ErrorAction Stop
                if (-not $proc.WaitForExit(10000)) { throw "StartFromTray PID $pidToStop did not terminate." }
            }
        }
    }
    foreach ($candidate in @(Get-Process -Name StartFromTray -ErrorAction SilentlyContinue)) {
        $path = $null
        try { $path = $candidate.Path } catch { }
        if (-not $path) { throw "Could not verify running StartFromTray PID $($candidate.Id)." }
        if ([IO.Path]::GetFullPath($path) -ieq $target) {
            throw 'StartFromTray is still running; no files were replaced.'
        }
    }
}

try {
    if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) { throw "Source folder missing: $sourceRoot" }
    if (-not (Test-Path -LiteralPath $targetRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $targetRoot -Force | Out-Null
    }
    Assert-NoReparsePath $targetRoot
    if ($sourceRoot -ieq $targetRoot) {
        throw 'In-place installation is unnecessary. Start the application; the first update check registers its files.'
    }

    # Expand the hand-written masks against the VERIFIED SOURCE ZIP, never
    # against files already present in the target directory.
    $fileList = Join-Path $sourceRoot '_FileList.txt'
    $rules = @(Get-FileRules $fileList)
    $protected = @('startfromtray.ini','items.xml','filters.ini','langs/default.ini',
        'install.psd1','_filelist.txt','startfromtray.update.ini',
        'startfromtray.update.log','startfromtray.update.log.1','startfromtray.tray.log')
    $entries = New-Object System.Collections.Generic.List[object]
    $names = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($file in @(Get-ChildItem -LiteralPath $sourceRoot -File -Recurse -Force)) {
        $relative = $file.FullName.Substring($sourceRoot.Length).TrimStart('\','/').Replace('\','/')
        if ($relative -eq '_FileList.txt') { continue }
        Assert-SafeRelativePath $relative
        if (-not (Test-FileRules $relative $rules)) {
            throw "Unexpected file not selected by package masks: $relative"
        }
        if ($protected -contains $relative.ToLowerInvariant()) {
            throw "Package masks select protected data: $relative"
        }
        if (-not $names.Add($relative)) { throw "Duplicate package file: $relative" }
        $from = $file.FullName
        Assert-NoReparsePath $from
        $destination = Join-Path $targetRoot ($relative.Replace('/','\'))
        Assert-NoReparsePath $destination
        $entries.Add([pscustomobject]@{
            Relative=$relative; Source=$from; Destination=$destination;
            Hash=(Get-FileHash -LiteralPath $from -Algorithm SHA256).Hash
        })
    }
    foreach ($required in @('StartFromTray.exe','install.ps1','update.ps1')) {
        if (-not $names.Contains($required)) { throw "Required release file missing: $required" }
    }

    $oldNames = New-Object System.Collections.Generic.List[string]
    if (Test-Path -LiteralPath $manifest -PathType Leaf) {
        Assert-NoReparsePath $manifest
        $state = Import-PowerShellDataFile -LiteralPath $manifest
        if ($state -isnot [hashtable] -or $state['installed-files'] -isnot [array]) {
            throw 'Existing installation manifest is invalid.'
        }
        foreach ($oldName in $state['installed-files']) {
            if ($oldName -isnot [string]) { throw 'Existing manifest has invalid file names.' }
            Assert-SafeRelativePath $oldName
            if (-not ($protected -contains $oldName.ToLowerInvariant())) { $oldNames.Add($oldName) }
        }
    }
    $removed = @($oldNames | Where-Object { -not $names.Contains($_) })

    New-Item -ItemType Directory -Path $stagedDir -Force | Out-Null
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    $changes = New-Object System.Collections.Generic.List[object]
    foreach ($entry in $entries) {
        if (Test-Path -LiteralPath $entry.Destination -PathType Container) {
            throw "A directory conflicts with the package file: $($entry.Relative)"
        }
        $unchanged = (Test-Path -LiteralPath $entry.Destination -PathType Leaf) -and
            ((Get-FileHash -LiteralPath $entry.Destination -Algorithm SHA256).Hash -ieq $entry.Hash)
        if ($unchanged) { continue }
        $copyPath = Join-Path $stagedDir ($entry.Relative.Replace('/', '\'))
        New-Item -ItemType Directory -Path (Split-Path -Parent $copyPath) -Force | Out-Null
        Copy-Item -LiteralPath $entry.Source -Destination $copyPath -Force
        if ((Get-FileHash -LiteralPath $copyPath -Algorithm SHA256).Hash -ine $entry.Hash) {
            throw "Staging hash mismatch: $($entry.Relative)"
        }
        $changes.Add([pscustomobject]@{ Relative=$entry.Relative; Source=$copyPath; Destination=$entry.Destination })
    }

    # Save rollback copies before closing the GUI and making any changes.
    $backupList = @($changes | ForEach-Object { $_.Destination }) +
        @($removed | ForEach-Object { Join-Path $targetRoot ($_.Replace('/','\')) }) + @($manifest)
    $backupIndex = @{}
    foreach ($path in $backupList) {
        Assert-NoReparsePath $path
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $backup = Join-Path $backupDir ([guid]::NewGuid().ToString('N'))
            Copy-Item -LiteralPath $path -Destination $backup -Force
            $backupIndex[$path.ToLowerInvariant()] = $backup
        }
    }
    $newVersion = [Diagnostics.FileVersionInfo]::GetVersionInfo((Join-Path $sourceRoot 'StartFromTray.exe'))
    $version = '{0}.{1}.{2}' -f $newVersion.FileMajorPart, $newVersion.FileMinorPart, $newVersion.FilePrivatePart
    Write-InstallLog "Prepared version $version; new/replaced=$($changes.Count); obsolete=$($removed.Count)."

    if ($changes.Count -gt 0 -or $removed.Count -gt 0) {
        try { Stop-InstalledApplication (Join-Path $targetRoot 'StartFromTray.exe') }
        catch { throw "STOP_FAILED: $($_.Exception.Message)" }
    }

    foreach ($item in $changes) {
        Assert-NoReparsePath $item.Destination
        $folder = Split-Path -Parent $item.Destination
        if (-not (Test-Path -LiteralPath $folder)) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
        $tmp = $item.Destination + '.new-' + [guid]::NewGuid().ToString('N')
        # Record before touching the destination so even a partial failure rolls back.
        $operations.Add([pscustomobject]@{ Action='REPLACE'; Target=$item.Destination })
        try {
            Copy-Item -LiteralPath $item.Source -Destination $tmp -Force
            Move-Item -LiteralPath $tmp -Destination $item.Destination -Force
        }
        finally { if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue } }
        Write-InstallLog "Installed $($item.Relative)"
    }
    foreach ($relative in $removed) {
        $obsolete = Join-Path $targetRoot ($relative.Replace('/','\'))
        Assert-NoReparsePath $obsolete
        if (Test-Path -LiteralPath $obsolete -PathType Leaf) {
            $operations.Add([pscustomobject]@{ Action='REMOVE'; Target=$obsolete })
            Remove-Item -LiteralPath $obsolete -Force
            Write-InstallLog "Removed obsolete $relative"
        }
    }
    $newManifest = New-ManifestText -Names ([string[]]@($names | Sort-Object)) -Version $version
    $manifestTmp = $manifest + '.new-' + [guid]::NewGuid().ToString('N')
    $operations.Add([pscustomobject]@{ Action='MANIFEST'; Target=$manifest })
    try {
        [IO.File]::WriteAllText($manifestTmp, $newManifest, [Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $manifestTmp -Destination $manifest -Force
    }
    finally { if (Test-Path -LiteralPath $manifestTmp) { Remove-Item -LiteralPath $manifestTmp -Force -ErrorAction SilentlyContinue } }
    Write-InstallLog "Installation complete: $version."
    $completed = $true
    # A portable archive may have been extracted manually before the update.
    # The inventory is a one-use initialization aid, not a permanent file.
    $staleList = Join-Path $targetRoot '_FileList.txt'
    if (Test-Path -LiteralPath $staleList -PathType Leaf) {
        try { Remove-Item -LiteralPath $staleList -Force -ErrorAction Stop }
        catch { Write-InstallLog "Could not remove _FileList.txt: $($_.Exception.Message)" }
    }
}
catch {
    $failure = $_.Exception.Message
    if ($operations.Count -gt 0) {
        Write-InstallLog "Installation failed: $failure; rolling back."
        for ($i = $operations.Count - 1; $i -ge 0; $i--) {
            $item = $operations[$i]
            try {
                $backup = $backupIndex[$item.Target.ToLowerInvariant()]
                if ($backup) {
                    Copy-Item -LiteralPath $backup -Destination $item.Target -Force
                }
                elseif (Test-Path -LiteralPath $item.Target -PathType Leaf) {
                    Remove-Item -LiteralPath $item.Target -Force
                }
            }
            catch {
                $rollbackOk = $false
                Write-InstallLog "ROLLBACK FAILED: $($item.Target): $($_.Exception.Message)"
            }
        }
    }
    Write-InstallLog "ERROR: $failure"
    throw
}
finally {
    if ($completed -or $rollbackOk) {
        if (Test-Path -LiteralPath $workDir) {
            Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    else { Write-InstallLog "Recovery copies retained: $backupDir" }
}
