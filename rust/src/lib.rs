use godot::prelude::*;

mod clock;

struct CosaNostraExtension;

#[gdextension]
unsafe impl ExtensionLibrary for CosaNostraExtension {}
