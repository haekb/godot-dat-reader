# DAT Reader

This will import Lithtech DAT files and allow Godot to load worlds as meshes. 

## Supported Formats

This plugin currently supports DAT versions:
-  Lithtech 1.0                     (DAT v56)
-  Lithtech 1.5                     (DAT v57)
-  Kiss Psycho Circus (Custom 1.5)  (DAT v127)
-  Lithtech 2.x                     (DAT v66)
-  Lithtech Talon                   (DAT v70)
-  Lithtech PS2                     (LTB v66)

Map versions v56, v57, and v127 all have lightmap support.

## Usage

Use `WorldBuilder.gd`'s `build` function to import textures at runtime.

Note this plugin is pretty messy right now, and doesn't load game entities yet.

## Installation

Simply drop this into `<GodotProject>/Addons/LTDatReader`.

## Research

Some research 010 Editor binary templates are available in `/Research`.