VIDORA - a Premiere Pro-style video editor for Windows, by Imal Madhusanka
==========================================================================

Start
  Installer (.msi): VIDORA is in the Start menu and on the desktop.
  Portable (.zip): unzip the VIDORA folder anywhere (a pen drive works too) and double-click
  VIDORA.exe. "Create Desktop Shortcut.bat" adds VIDORA to the desktop and the Start menu.

Your settings
  Installed: %APPDATA%\VIDORA (logs in %APPDATA%\VIDORA\Logs).
  Portable: the "data" folder next to VIDORA.exe (delete portable.txt to use %APPDATA%\VIDORA).

Sinhala text
  Titles and captions can be typed in Sinhala: VIDORA includes the Noto Sans Sinhala and
  Noto Serif Sinhala fonts.

If VIDORA doesn't open
  VIDORA draws with DirectX 12 or Vulkan. If the window flashes and closes, update the graphics
  driver, or start it from PowerShell in this folder with another backend:
      $env:WGPU_BACKEND = "dx12"     (or "vulkan")
      & .\VIDORA.exe
  The log in %APPDATA%\VIDORA\Logs says what went wrong.

vidora-cli.exe is the command-line tool (vidora-cli help): batch export, project inspection and
an MCP server for automation.

Updates and problems: https://github.com/imalmadhusankaphotography-creator/VIDORA

VIDORA is built on FilmCraft by the ArtCraft team and the FilmCraft contributors
(https://github.com/storytold/filmcraft, MIT OR Apache-2.0). It is not made or endorsed by the
ArtCraft Team. Licences: LICENSE-MIT, LICENSE-APACHE, NOTICE, OFL-NotoSinhala.txt (the bundled
Noto Sinhala fonts).
