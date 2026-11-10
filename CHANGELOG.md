# Changelog

All notable changes to the port tooling and documentation.

## [Unreleased] — performance pass

Video and menu stutter on the console.

### Added
- `scripts/otimizar-videos-switch.ps1` — transcode game `.ogv` videos to
  720p / max 30 fps (libtheora + Vorbis) with backups of the originals.
- `scripts/converter-videos-mods.ps1`: `-MaxFps` (default 30) and `-Ffprobe`;
  mod videos are no longer copied at 60 fps.
- `exportar-pck.ps1` now fails if fewer than 9 `assets/video/*.ogv` end up in
  the `.pck` (attract videos are loaded at runtime).

### Changed
- Switch: resolution pinned to 1280×720, vsync always on, `Engine.max_fps = 60`
  (`SettingsManager.set_fps()` is actually called now).
- `chromatic_abberation.gdshader`: dropped `filter_linear_mipmap` — it forced a
  full-screen mipmap every frame.
- `attract_screen.gd`: videos are loaded one at a time instead of four large
  `preload`s (~400 MB, multi-second stall).
- `SceneManager`: the 2 s diagnostic pulse now only runs when `dados/pulso`
  exists (it flushed to the SD card every 2 s).
- `include_filter="*.crt,*.ogv"` so runtime-loaded videos stay in the `.pck`.

### Fixed
- `SettingsManager.set_chromatic_abberation()` read `reduce_motion` by mistake.

## [0.1.0] — 2026-11-09

First public release of the tooling and documentation.

### Added
- `scripts/exportar-pck.ps1` — import, export and verify a Switch `.pck`
  (checks that `data/` is excluded and that the CA bundle is included).
- `scripts/converter-videos-mods.ps1` — convert mod `.webm` videos to
  Theora `.ogv` and rewrite the mod configs.
- `scripts/wsl/build-godot.sh` — build the Godot Switch engine with scons.
- `scripts/wsl/finalizar.sh` + `empacotar-nativo.sh` — package a `.nro`.
- `scripts/wsl/verificar-nro.sh` — inspect a produced `.nro`.
- Full documentation: install, updating, testing/diagnostics, build and
  porting notes.

### Port changes documented
- Save reliability: direct write of `game.sav`, copy-based backups
  `game.sav.bak1..3`, recovery on load.
- Mods: FAT/exFAT-safe folder names, deletion without `move_to_trash`,
  compile-time fix for the missing `WebSocketPeer` (GSpot stub).
- Online: HTTPS via `cacert.crt` and
  `network/tls/certificate_bundle_override`.
- Video: Theora playback kept; `.webm` → `.ogv` conversion for mods;
  final video disabled on Switch when no `.ogv` exists.
- HOME/sleep pause via the platform focus hook.
