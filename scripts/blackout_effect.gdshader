shader_type canvas_item;
render_mode unshaded;

// Con mipmaps: el desenfoque lee de un nivel ya suavizado para rellenar el hueco
// entre lecturas (ver abajo).
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
// Todo lo demas esta en el .gdshaderinc, compartido con blackout_effect_lod0,
// que es este mismo shader sin mipmaps (ver blackout_controller.gd).
#include "res://scripts/blackout_effect.gdshaderinc"
