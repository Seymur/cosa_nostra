# Cosa Nostra

A first-person crime-boss sandbox built with Godot 4.7 and a small Rust GDExtension.
Grow weed, process it, and build up your operation.

> Work in progress. Mechanics, art and UI are placeholders in many places.

## Features

- **First-person controller** with sprinting, crouching, jumping and limited air control.
- **Hotbar and backpack inventory** with stacking, drag and drop, and dropping items by throwing them from your hand.
- **Placeable props** with a ghost preview, surface validation and optional snapping (planters, walls and more).
- **Weed growing loop**
  1. Place a planter and hold a **Weed Seed Pouch** (10 seeds) to plant a seed.
  2. Hold the **Watering Can** to water it; growth then runs through four stages (seedling, young, flowering, harvest).
  3. Use the **Garden Shears** on the fully grown plant to harvest Weed Leaves straight into your inventory.
- **In-game clock** (Rust GDExtension) with days, seasons, speed control and pause. Plant growth follows it.
- **Interaction HUD**: crosshair progress ring for timed actions, planter stats and action hints, and notifications.
- **Remappable input** through the [GUIDE](https://github.com/godotneko/guide) addon.
- **Localization** in 16 languages.

## Controls

| Action | Input |
|---|---|
| Move / look | WASD / mouse |
| Jump / crouch / sprint | Space / crouch key / sprint key |
| Use held item / interact | Left mouse button |
| Pick up a placed prop | Hold X (empty hands) |
| Select hotbar slot | Mouse wheel |
| Drop item | G |
| Toggle snapping | Key bound to *Snap* |

Plant watering and harvesting need the left mouse button held until the ring around the crosshair fills.

## Project layout

```
godot/   Godot project (open this folder in the editor)
  actors/      player controller
  items/       held items (seed pouch, watering can, shears, ...)
  props/       placeable world objects (planter, door, ...)
  scripts/     shared base classes (Interactable, Equippable, Removable, ...)
  ui/          HUD, hotbar, inventory, menus
  input/       GUIDE actions and mapping contexts
  models/      3D models, including the weed plant growth stages
  localization/ translations
rust/    GDExtension crate (game clock)
```

## Getting started

Requirements:

- [Godot 4.7](https://godotengine.org/download)
- [Rust](https://rustup.rs/) (stable, edition 2024)

Build the extension, then open the project:

```sh
cd rust
cargo build            # debug build used by the editor
cd ../godot
godot --editor         # or import godot/project.godot from the Godot project manager
```

For a release build run `cargo build --release`; the paths for each platform are listed in
`godot/CosaNostra.gdextension`.

## Credits

- [GUIDE](https://github.com/godotneko/guide) for input handling (see `godot/addons/guide/LICENSE.md`).
- [godot-rust](https://github.com/godot-rust/gdext) for the GDExtension bindings.
