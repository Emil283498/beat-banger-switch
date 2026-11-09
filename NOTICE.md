# Third-party notices and legal information

## Beat Banger (the game)

**Beat Banger** and all of its assets (music, videos, images, levels, code) are
the property of **bun fun** and their respective authors.

This repository does **not** contain, host or distribute:

- the game itself;
- the decompiled project (`game/src`, `game/assets`, ...);
- game data (`data/`);
- packed resources (`beat-banger.pck`);
- built executables (`beat-banger.nro`, `.elf`).

To use this port you must own a legal copy of Beat Banger. The port is
unofficial and is not affiliated with, endorsed by, or supported by bun fun.

Do not redistribute game files. Keep your builds for personal use.

## Godot Engine

- Godot Engine — Copyright © Godot Engine contributors, MIT License.
  https://godotengine.org/
- [`calosguilherme/godot-switch-nro`](https://github.com/calosguilherme/godot-switch-nro)
  — Nintendo Switch platform port, MIT License.

## devkitPro / libnx / Mesa

- devkitPro, devkitA64, libnx, switch-mesa — their respective licenses.
  https://devkitpro.org/

## Libraries used by the engine build

- Theora / libogg / libvorbis — BSD-style licenses (Xiph.Org).
- mbedTLS — Apache License 2.0.
- Mesa / OpenGL — MIT-style licenses.

## CA certificates (for HTTPS)

Builds use the Mozilla CA bundle shipped with Godot
(`thirdparty/certs/ca-bundle.crt`, MPL 2.0). It is embedded into the produced
`.pck` at build time; it is not stored in this repository.

## FFmpeg

The optional PC converter uses **FFmpeg** to turn `.webm` into `.ogv`.
FFmpeg is not bundled here and is not part of the console build. If you
redistribute FFmpeg binaries, follow its LGPL/GPL terms.

## Original work in this repository

The scripts and documentation in this repository are original work and are
released under the MIT License (see `LICENSE`). They are provided "as is",
without warranty of any kind.
