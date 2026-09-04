@echo off
setlocal EnableExtensions
cd /d "%~dp0"
set "ROOT=%CD%"

rem ---- Find Git -------------------------------------------------------------
set "GIT="
for /f "delims=" %%G in ('where git.exe 2^>nul') do if not defined GIT set "GIT=%%G"
if not defined GIT (
  for /f "delims=" %%G in ('dir /b /s /a:-d "%LOCALAPPDATA%\GitHubDesktop\app-*\resources\app\git\cmd\git.exe" 2^>nul') do if not defined GIT set "GIT=%%G"
)
if not defined GIT (
  echo [ERROR] Git was not found.
  echo Install Git for Windows or GitHub Desktop, then try again.
  pause
  exit /b 1
)

rem ---- Update repo -----------------------------------------------------------
echo.
echo === Updating GodotVSCodex ===
"%GIT%" switch main >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Could not switch to main.
  echo You may have local changes that need to be committed or stashed first.
  pause
  exit /b 1
)

"%GIT%" pull --ff-only origin main
if errorlevel 1 (
  echo.
  echo [ERROR] Pull failed. Nothing was reset or deleted.
  echo Open GitHub Desktop to resolve the repo state, then run this again.
  pause
  exit /b 1
)

rem ---- Find Godot 4.7 --------------------------------------------------------
set "GODOT="
if defined GODOT_BIN if exist "%GODOT_BIN%" set "GODOT=%GODOT_BIN%"

if not defined GODOT (
  for /f "delims=" %%G in ('where godot4.exe 2^>nul') do if not defined GODOT set "GODOT=%%G"
)
if not defined GODOT (
  for /f "delims=" %%G in ('where godot.exe 2^>nul') do if not defined GODOT set "GODOT=%%G"
)

for %%G in (
  "%ROOT%\Godot_v4.7-stable_win64.exe"
  "%ROOT%\Godot_v4.7-stable_mono_win64.exe"
  "%ProgramFiles%\Godot\Godot.exe"
  "%ProgramFiles%\Godot Engine\Godot.exe"
  "%ProgramFiles(x86)%\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
) do (
  if not defined GODOT if exist "%%~G" set "GODOT=%%~G"
)

if not defined GODOT (
  echo Searching Downloads/Desktop for Godot...
  for /f "usebackq delims=" %%G in (`powershell -NoProfile -Command "$roots=@([Environment]::GetFolderPath('Desktop'),(Join-Path $env:USERPROFILE 'Downloads')); $f=Get-ChildItem -Path $roots -Filter 'Godot_v4.7*.exe' -File -Recurse -ErrorAction SilentlyContinue ^| Sort-Object LastWriteTime -Descending ^| Select-Object -First 1 -ExpandProperty FullName; if($f){$f}"`) do if not defined GODOT set "GODOT=%%G"
)

if not defined GODOT (
  echo.
  echo [ERROR] Godot 4.7 was not found.
  echo Put Godot in PATH, place the Godot .exe in this repo folder,
  echo or set a GODOT_BIN environment variable pointing to Godot.
  pause
  exit /b 1
)

echo.
echo === Launching game ===
echo Godot: "%GODOT%"
start "" "%GODOT%" --path "%ROOT%"
exit /b 0
