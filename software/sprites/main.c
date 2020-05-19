// TODO: header

#include "vdp.h"

#include <stdint.h>
#include <stdbool.h>

#include "tiles.h"
#include "palette.h"

int main() {
    vdp_enable_layers(SPRITES);
    // if alpha sprites are eventually used, need to reenable this one
    vdp_set_alpha_over_layers(0);

    const uint16_t tile_base = 0x0000;
    vdp_set_sprite_tile_base(tile_base);

    // tiles

    vdp_set_vram_increment(1);
    vdp_seek_vram(tile_base);
    for (uint16_t i = 0; i < tiles_length / 2; i++) {
        vdp_write_vram(tiles[i * 2] | tiles[i * 2 + 1] << 8);
    }

    // palette

    vdp_seek_palette(0);
    for (uint16_t i = 0; i < palette_length / 2; i++) {
        vdp_write_palette_color(palette[i * 2] | palette[i * 2 + 1] << 8);
    }

    // place a sprite

    vdp_clear_all_sprites();

    vdp_write_single_sprite_meta(0, 16, 16 | SPRITE_16_TALL | SPRITE_16_WIDE, 0);

    while(true) {}
}
