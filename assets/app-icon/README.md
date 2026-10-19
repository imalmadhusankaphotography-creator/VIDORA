# VIDORA app icon

The VIDORA icon: a white V on a navy-to-blue tile with film-strip perforations along the top and
bottom edges (the perforations are left out at 16-32 px, where they would only blur).

It is a placeholder until Imal Madhusanka's own VIDORA logo is added. Every file here is made by
`packaging/vidora/make_icons.py`; to use a new logo run

    python3 packaging/vidora/make_icons.py path/to/logo.png [--small path/to/small-logo.png]

The file names stay FilmCraft's (`filmcraft.ico`, `ai.storyteller.filmcraft.png`, …) because the build
(`apps/filmcraft/build.rs`, `apps/filmcraft/src/main.rs`) and packaging scripts look for them.
