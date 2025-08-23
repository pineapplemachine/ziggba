# ZigGBA

ZigGBA is an SDK for creating Game Boy Advance games using the [Zig](https://ziglang.org/) programming language. It is currently in a WIP/experimental state. This repository is a maintained fork of [wendigojaeger/ZigGBA](https://github.com/wendigojaeger/ZigGBA).

Many thanks to [TONC](https://gbadev.net/tonc/) and [GBATEK](https://problemkaputt.de/gbatek.htm), both of which have been major inspirations and resources for this project.

Generated documentation for ZigGBA is available at
[pineapplemachine.github.io/ziggba/master/](https://pineapplemachine.github.io/ziggba/master/). Documentation is split between the `build` library which contains tools for building code targeting the GBA, and the `gba` library which provides an API and other runtime utilities for code running on the GBA.

For bug reports and feature requests, please submit a [GitHub issue](https://github.com/pineapplemachine/ziggba/issues). For general questions and support, you can submit an issue or you can visit the [gbadev Discord server](https://discord.gg/7DBJvgW9bb) which has a `#ziggba` channel for discussions specifically about this project, as well as other channels for more general discussions about GBA development.

## Usage

ZigGBA currently uses Zig 0.14.1. The tool [`anyzig`](https://github.com/marler8997/anyzig) is recommended for managing Zig installations.

With `git` and `zig` installed, follow these steps to download ZigGBA and build the example ROMs:

```bash
# Download this git repository
git clone https://github.com/pineapplemachine/ziggba.git
# Navigate to the downloaded directory
cd ziggba
# Build `gba.text` font data used by examples
zig build font
# Compile example ROMs, outputted to `zig-out/bin/`
zig build
```

ZigGBA's `zig build` will write example ROMs to `zig-out/bin/`. These are files with a `*.gba` extension which can be run on a GBA using special hardware, or which can run in emulators such as [mGBA](https://github.com/mgba-emu/mgba), [Mesen](https://github.com/SourMesen/Mesen2/), [no$gba](https://problemkaputt.de/gba.htm), and [NanoBoyAdvance](https://github.com/nba-emu/NanoBoyAdvance).

Pass the `-Dgdb` flag to `zig build` to also output an `*.elf` file containing debug symbols.

See the [ziggba-example](https://www.github.com/pineapplemachine/ziggba-example) repository for an example of a project which uses ZigGBA as a dependency.

## Showcase

First example running on an emulator:

![First example emulator image](docs/images/FirstExampleEmulator.png)

First example running on real hardware:

![First example real hardware image](docs/images/FirstExampleRealHardware.png)
