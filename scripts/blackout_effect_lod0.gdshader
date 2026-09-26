shader_type canvas_item;
render_mode unshaded;

// Variante de blackout_effect.gdshader sin mipmaps. Mientras el paso del
// desenfoque es de menos de 4 px el shader lee siempre el nivel 0 (lod = 0), y los
// mipmaps no se usan; generarlos cada fotograma cuesta mucho en una GPU floja.
// blackout_controller.gd usa esta mientras lod es 0: la imagen sale igual.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
#include "res://scripts/blackout_effect.gdshaderinc"
