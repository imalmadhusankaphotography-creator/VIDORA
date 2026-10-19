# Bringing a new FilmCraft release into VIDORA

VIDORA's history starts fresh (it doesn't carry FilmCraft's commits), so an update applies the
changes between two FilmCraft releases as a patch. `packaging/vidora/UPSTREAM` records the release
VIDORA is on now.

```sh
# 1. FilmCraft's changes from the release VIDORA is on to the new one (here v0.10.0)
git clone https://github.com/storytold/filmcraft ../filmcraft-upstream
git -C ../filmcraft-upstream diff v0.9.0 v0.10.0 -- . ':!docs/brand' ':!.github' > /tmp/filmcraft.patch

# 2. Apply them; --3way leaves conflict markers where VIDORA changed the same lines
git apply --3way /tmp/filmcraft.patch

# 3. Rename the "FilmCraft" strings the new release added, and check nothing is left
python3 packaging/vidora/rebrand_strings.py
python3 packaging/vidora/rebrand_strings.py --check

# 4. Record the new base, then build and commit
#    (edit packaging/vidora/UPSTREAM: tag and commit)
cargo check --locked -p filmcraft -p filmcraft-cli
```

Places that conflict most often (VIDORA changed them by hand, not by the script):

- `crates/ui-egui/src/links.rs`, `menus.rs` (Help menu), `header.rs` (no Discord button),
  `panels/import_mode.rs` (Home links), `panels/dialogs.rs` (About), `brand.rs` (VIDORA wordmark)
- `apps/filmcraft/build.rs` (exe name, author, copyright), `apps/filmcraft/src/native_menu.rs`
- `assets/app-icon/*` (VIDORA icon: regenerate with `packaging/vidora/make_logo_assets.py`)
- `README.md`, `NOTICE`, `ATTRIBUTION.md`, `LICENSE-MIT`
- Keep FilmCraft's ArtCraft marks (`docs/brand/`) and workflows (`.github/workflows/` other than
  `vidora-windows.yml`) out.
- `crates/text/src/layout.rs` (ZWJ and other joiners stay in the face of the cluster before
  them, so Sinhala conjuncts like ශ්‍රී shape correctly in fallback) and the Japanese craft-fonts
  test in `crates/text/src/fonts.rs`
- `crates/gpu/src/adapter.rs` (`intel_through_dx12`: Intel GPUs draw through DirectX 12, not
  Intel's Vulkan driver) and `crates/gpu/src/export_renderer.rs` (exports pick their GPU the same way)
