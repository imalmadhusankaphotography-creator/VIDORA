# VIDORA app icon

Imal Madhusanka's VIDORA logo, a V that folds into a play button in blue-to-violet light, on a
rounded black tile. The 16-32 px icons crop tighter so the symbol stays readable in the taskbar
and title bar. `vidora-wordmark-light.png` / `-dark.png` add the name for the About dialog and the
Home screen (light lettering for dark themes, dark for light themes).

Every file here is made from `packaging/vidora/logo/vidora-logo.png` by

    python3 packaging/vidora/make_logo_assets.py

The file names stay FilmCraft's (`filmcraft.ico`, `ai.storyteller.filmcraft.png`, …) because the build
(`apps/filmcraft/build.rs`, `apps/filmcraft/src/main.rs`) and packaging scripts look for them.
