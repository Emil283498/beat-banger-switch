# Changelog

All notable changes to the port tooling and documentation.

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
