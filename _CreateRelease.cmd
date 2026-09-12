@echo off
if defined CREATE_RELEASE_INNER goto :run_script

setlocal
set "CREATE_RELEASE_INNER=1"
call "%~f0" %*
set "CREATE_RELEASE_EXIT=%ERRORLEVEL%"
echo.
pause
exit /b %CREATE_RELEASE_EXIT%

:run_script
setlocal EnableExtensions DisableDelayedExpansion

rem Builds StartFromTray in Release Win32 mode and creates a portable Win32 archive.
rem The archive contains release files directly at its root.
rem Put this file in the repository root and run it without arguments.

set "ROOT=%~dp0"
pushd "%ROOT%" || exit /b 1

set "APP_NAME=StartFromTray"
set "BUILD_MODE=Release Win32"
set "ARCH_NAME=win32"
set "PROJECT_FILE=%ROOT%%APP_NAME%.lpi"
set "EXE_FILE=%ROOT%%APP_NAME%.exe"
set "LANG_DIR=%ROOT%Langs"

set "LAZBUILD="
for %%I in (lazbuild.exe) do set "LAZBUILD=%%~$PATH:I"
if not defined LAZBUILD if exist "C:\Programs\Lazarus\lazbuild.exe" (
  set "LAZBUILD=C:\Programs\Lazarus\lazbuild.exe"
)

if not defined LAZBUILD (
  echo ERROR: lazbuild.exe was not found.
  echo Add the Lazarus directory to PATH or install Lazarus in:
  echo   C:\Programs\Lazarus
  popd
  exit /b 2
)

where powershell.exe >nul 2>&1
if errorlevel 1 (
  echo ERROR: Windows PowerShell was not found.
  popd
  exit /b 3
)

if not exist "%PROJECT_FILE%" (
  echo ERROR: Project file was not found:
  echo   "%PROJECT_FILE%"
  popd
  exit /b 4
)

echo Building %APP_NAME% in "%BUILD_MODE%" mode...
rem This command-line override does not change the mode selected in the Lazarus IDE.
"%LAZBUILD%" --build-all --build-mode="%BUILD_MODE%" "%PROJECT_FILE%"
if errorlevel 1 (
  echo ERROR: Release build failed.
  popd
  exit /b 5
)

if not exist "%EXE_FILE%" (
  echo ERROR: The build completed without creating:
  echo   "%EXE_FILE%"
  popd
  exit /b 6
)

set "EXE_PATH=%EXE_FILE%"
set "PE_MACHINE="
for /f "usebackq delims=" %%A in (`powershell.exe -NoLogo -NoProfile -Command "$b=[IO.File]::ReadAllBytes($env:EXE_PATH); if ($b.Length -lt 64) { exit 1 }; $p=[BitConverter]::ToInt32($b,60); if (($p -lt 0) -or ($p + 6 -gt $b.Length)) { exit 1 }; '{0:X4}' -f [BitConverter]::ToUInt16($b,$p+4)"`) do set "PE_MACHINE=%%A"

if /I not "%PE_MACHINE%"=="014C" (
  echo ERROR: The generated executable is not a 32-bit i386 Windows application.
  echo Expected PE machine 014C, got "%PE_MACHINE%".
  echo Check the Target OS and Target CPU settings of build mode "%BUILD_MODE%".
  popd
  exit /b 16
)

if not exist "%LANG_DIR%\*.ini" (
  echo ERROR: No language files were found in:
  echo   "%LANG_DIR%"
  popd
  exit /b 7
)

for %%F in (LICENSE README.md README.ru.md) do (
  if not exist "%ROOT%%%F" (
    echo ERROR: Required file "%%F" was not found.
    popd
    exit /b 8
  )
)

set "VERSION="
for /f "usebackq delims=" %%V in (`powershell.exe -NoLogo -NoProfile -Command "$v=(Get-Item -LiteralPath $env:EXE_PATH).VersionInfo; if ($v.FileVersion) { '{0}.{1}.{2}' -f $v.FileMajorPart,$v.FileMinorPart,$v.FilePrivatePart }"`) do set "VERSION=%%V"

if not defined VERSION (
  echo ERROR: The file version could not be read from:
  echo   "%EXE_FILE%"
  popd
  exit /b 9
)

echo(%VERSION%| findstr /r /x "[0-9][0-9.]*" >nul
if errorlevel 1 (
  echo ERROR: Unexpected file version "%VERSION%".
  popd
  exit /b 10
)

set "DIST_DIR=%ROOT%dist"
set "PACKAGE_NAME=%APP_NAME%-v%VERSION%-%ARCH_NAME%"
set "STAGE_DIR=%DIST_DIR%\%PACKAGE_NAME%"
set "ZIP_FILE=%DIST_DIR%\%PACKAGE_NAME%.zip"
set "HASH_FILE=%ZIP_FILE%.sha256"

if exist "%STAGE_DIR%" (
  echo ERROR: The staging directory already exists:
  echo   "%STAGE_DIR%"
  echo Delete it after checking its contents, then run this script again.
  popd
  exit /b 11
)

if exist "%ZIP_FILE%" (
  echo ERROR: The release archive already exists:
  echo   "%ZIP_FILE%"
  echo Delete or rename it, then run this script again.
  popd
  exit /b 12
)

if not exist "%DIST_DIR%" mkdir "%DIST_DIR%"
if errorlevel 1 goto :copy_error

mkdir "%STAGE_DIR%"
if errorlevel 1 goto :copy_error

mkdir "%STAGE_DIR%\Langs"
if errorlevel 1 goto :copy_error

copy /y "%EXE_FILE%" "%STAGE_DIR%\%APP_NAME%.exe" >nul
if errorlevel 1 goto :copy_error

for %%F in (LICENSE README.md README.ru.md) do (
  copy /y "%ROOT%%%F" "%STAGE_DIR%\%%F" >nul
  if errorlevel 1 goto :copy_error
)

if exist "%ROOT%CHANGELOG.md" (
  copy /y "%ROOT%CHANGELOG.md" "%STAGE_DIR%\CHANGELOG.md" >nul
  if errorlevel 1 goto :copy_error
)

for %%F in ("%LANG_DIR%\*.ini") do (
  if /I not "%%~nxF"=="Default.ini" (
    copy /y "%%~fF" "%STAGE_DIR%\Langs\%%~nxF" >nul
    if errorlevel 1 goto :copy_error
  )
)

rem User-specific/generated files are intentionally not copied:
rem StartFromTray.ini, Items.xml, Filters.ini and Langs\Default.ini.

set "STAGE_PATH=%STAGE_DIR%"
set "ZIP_PATH=%ZIP_FILE%"
set "HASH_PATH=%HASH_FILE%"

echo Creating "%ZIP_FILE%"...
powershell.exe -NoLogo -NoProfile -Command "Compress-Archive -Path (Join-Path $env:STAGE_PATH '*') -DestinationPath $env:ZIP_PATH -CompressionLevel Optimal"
if errorlevel 1 goto :archive_error

powershell.exe -NoLogo -NoProfile -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; $z=[IO.Compression.ZipFile]::OpenRead($env:ZIP_PATH); try { if (-not $z.GetEntry('StartFromTray.exe')) { exit 1 }; if (-not $z.GetEntry('LICENSE')) { exit 1 }; if (-not $z.GetEntry('README.md')) { exit 1 }; if (-not $z.GetEntry('README.ru.md')) { exit 1 }; if (-not ($z.Entries | Where-Object { $_.FullName -like 'Langs/*.ini' } | Select-Object -First 1)) { exit 1 } } finally { $z.Dispose() }"
if errorlevel 1 goto :archive_error

powershell.exe -NoLogo -NoProfile -Command "$h=Get-FileHash -LiteralPath $env:ZIP_PATH -Algorithm SHA256; ($h.Hash.ToLowerInvariant() + ' *' + [IO.Path]::GetFileName($env:ZIP_PATH)) | Set-Content -LiteralPath $env:HASH_PATH -Encoding ASCII"
if errorlevel 1 goto :hash_error

rmdir /s /q "%STAGE_DIR%"

echo.
echo Release package created successfully:
echo   "%ZIP_FILE%"
echo SHA-256:
echo   "%HASH_FILE%"
popd
exit /b 0

:copy_error
echo ERROR: Could not prepare the release directory.
echo Check the partially created directory:
echo   "%STAGE_DIR%"
popd
exit /b 13

:archive_error
echo ERROR: Could not create or validate the ZIP archive.
echo The staging directory was kept for inspection:
echo   "%STAGE_DIR%"
popd
exit /b 14

:hash_error
echo ERROR: The ZIP was created, but its SHA-256 file could not be written.
echo   "%ZIP_FILE%"
popd
exit /b 15
