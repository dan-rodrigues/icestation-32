// TODO: header

#include "vdp.h"

#include <stdint.h>
#include <stdbool.h>

#include "tiles.h"
#include "palette.h"

int main() {
    vdp_enable_layers(SPRITES);
    // if alpha sprites are eventually used, need to reenable this one
    vdp_set_alpha_over_layers(SPRITES);

    const uint16_t tile_base = 0x0000;
    vdp_set_sprite_tile_base(tile_base);

    // tiles

    vdp_set_vram_increment(1);
    vdp_seek_vram(tile_base);
    for (uint16_t i = 0; i < _Users_dan_rodrigues_Documents_tiles_bin_len / 2; i++) {
        vdp_write_vram(_Users_dan_rodrigues_Documents_tiles_bin[i * 2] | _Users_dan_rodrigues_Documents_tiles_bin[i * 2 + 1] << 8);
    }

    // palette

    vdp_seek_palette(0);
    for (uint16_t i = 0; i < _Users_dan_rodrigues_Documents_palette_bin_len / 2; i++) {
        vdp_write_palette_color(_Users_dan_rodrigues_Documents_palette_bin[i * 2] | _Users_dan_rodrigues_Documents_palette_bin[i * 2 + 1] << 8);
    }

    // random color?
//    vdp_set_single_palette_color(0, 0xf00f);

    // place a sprite

    vdp_clear_all_sprites();

    vdp_write_single_sprite_meta(0, 16, 16 | SPRITE_16_TALL | SPRITE_16_WIDE, 0);

    while(true) {}
}
