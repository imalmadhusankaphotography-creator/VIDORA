<p align="center"><img src="packaging/vidora/logo/vidora-icon.png" width="128" alt="VIDORA logo"></p>

# VIDORA

**A Premiere Pro-style video editor for Windows, by Imal Madhusanka.**

VIDORA is a free, open-source non-linear video editor: Source and Program monitors, a multi-track
timeline with every trim tool, Lumetri-style colour grading with scopes, effects and transitions,
keyframes, titles and captions (Sinhala included), a full audio mixer with loudness meters, and
export to H.264 MP4, ProRes, DNxHR and more. It reads FCP7 XML, FCPXML, AAF, OMF, EDL and
OpenTimelineIO, so timelines move between VIDORA and other editors.

VIDORA is built on [FilmCraft](https://github.com/storytold/filmcraft) (v0.9.0), the pure-Rust
video editor by the ArtCraft team and the FilmCraft contributors. It is not made or endorsed by the
ArtCraft Team.

## Download

Get the latest version from [**Releases**](https://github.com/imalmadhusankaphotography-creator/VIDORA/releases):

| File | What it is |
|---|---|
| `VIDORA-<version>-windows-x64.msi` | Installer: VIDORA in the Start menu and on the desktop |
| `VIDORA-<version>-windows-x64-portable.zip` | No installation: unzip and run `VIDORA.exe` (works from a pen drive) |

Every push to `main` also builds both, under the run's **Artifacts** on the
[Actions](https://github.com/imalmadhusankaphotography-creator/VIDORA/actions) tab.

Windows may warn about an unknown publisher the first time (the files aren't code-signed):
choose **More info ▸ Run anyway**.

### සිංහලෙන්

- අලුත්ම VIDORA එක **Releases** page එකෙන් download කරන්න.
- `.msi` එක install කළාම Start menu එකේ සහ desktop එකේ VIDORA එනවා.
- `portable.zip` එක unzip කරලා `VIDORA.exe` double-click කරන්න. Install කරන්න ඕන නැහැ.
- Titles සහ captions වල සිංහලෙන් type කරන්න පුළුවන් (Noto Sinhala fonts ඇතුළත්).

## If VIDORA doesn't open

VIDORA draws with DirectX 12 or Vulkan. If the window flashes and closes, update the graphics
driver, or start it from PowerShell in VIDORA's folder with the other backend:

```powershell
$env:WGPU_BACKEND = "dx12"     # or "vulkan"
& .\VIDORA.exe
```

The log is in `%APPDATA%\VIDORA\Logs`.

## Building

VIDORA builds on GitHub Actions (`.github/workflows/vidora-windows.yml`). To build on a Windows PC
with Rust, the Windows SDK and WiX v5 (`dotnet tool install --global wix --version 5.0.2`):

```powershell
pwsh packaging/vidora/package.ps1          # -> dist\VIDORA-<version>-windows-x64.msi and -portable.zip
pwsh packaging/vidora/package.ps1 -NoMsi   # portable zip only, no WiX needed
```

For development, `cargo run --release -p filmcraft` starts the app (the crate names are still
FilmCraft's; that keeps updates from FilmCraft simple).

## How VIDORA differs from FilmCraft

- VIDORA name, logo and links everywhere in the app (`packaging/vidora/make_logo_assets.py` makes the icons); settings live in `%APPDATA%\VIDORA`, so VIDORA
  and FilmCraft can be installed side by side.
- No ArtCraft logos or community links (FilmCraft's brand licence asks forks to remove them).
- Noto Sans Sinhala and Noto Serif Sinhala are built in, for Sinhala titles and captions.
- Windows installer and portable zip from `packaging/vidora/`.

`packaging/vidora/UPDATING.md` explains how a new FilmCraft release is brought into VIDORA.

## Licence

MIT OR Apache-2.0, like FilmCraft (`LICENSE-MIT`, `LICENSE-APACHE`, `NOTICE`). Bundled fonts and
other assets keep their own open licences, listed in `ATTRIBUTION.md`. The VIDORA name and logo
belong to Imal Madhusanka and are not covered by the code licence.
