@echo off
setlocal
set "EXE=%~dp0VIDORA.exe"
if not exist "%EXE%" (
  echo VIDORA.exe isn't next to this file.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$w = New-Object -ComObject WScript.Shell;" ^
  "foreach ($dir in @([Environment]::GetFolderPath('Desktop'), (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'))) {" ^
  "  $s = $w.CreateShortcut((Join-Path $dir 'VIDORA.lnk')); $s.TargetPath = '%EXE%'; $s.WorkingDirectory = '%~dp0'; $s.IconLocation = '%EXE%,0'; $s.Description = 'VIDORA video editor'; $s.Save() }"
if errorlevel 1 (
  echo Couldn't create the shortcuts.
) else (
  echo VIDORA is on the desktop and in the Start menu.
)
pause
