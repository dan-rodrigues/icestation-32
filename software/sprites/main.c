// TODO: header

#include "vdp.h"

#include <stdint.h>
#include <stdbool.h>

#include "tiles.h"
#include "palette.h"

void draw_crystal_sprite(uint8_t *base_sprite_id, uint16_t base_tile, uint16_t x, uint16_t y);

int main() {
    vdp_enable_layers(SPRITES);
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
    vdp_set_single_palette_color(0, 0xf007);

    // place a sprite

    const int16_t base_x = 50;
    const int16_t base_y = 50;

    const uint8_t crystal_total_frames = 8;
    const uint8_t crystal_frame_width = 32;

    uint16_t frame_counter = 0;

    while(true) {
        vdp_clear_all_sprites();

        uint8_t base_sprite_id = 0;

        uint8_t crystal_frame = frame_counter / 4;
        crystal_frame &= (crystal_total_frames - 1);
        uint16_t crystal_tile_base = (crystal_frame & 3) * crystal_frame_width / 8;
        crystal_tile_base += (crystal_frame & 4) ? 0x40 : 0;

        draw_crystal_sprite(&base_sprite_id, crystal_tile_base, base_x, base_y);

        vdp_wait_frame_ended();

        frame_counter++;
    }
}

void draw_crystal_sprite(uint8_t *base_sprite_id, uint16_t base_tile, uint16_t x, uint16_t y) {
    vdp_seek_sprite(*base_sprite_id);
    vdp_write_sprite_meta(x, y | SPRITE_16_TALL | SPRITE_16_WIDE, base_tile);
    vdp_write_sprite_meta(x + 16, y | SPRITE_16_TALL | SPRITE_16_WIDE, base_tile + 2);
    vdp_write_sprite_meta(x, (y + 16) | SPRITE_16_TALL | SPRITE_16_WIDE, base_tile + 0x20);
    vdp_write_sprite_meta(x + 16, (y + 16) | SPRITE_16_TALL | SPRITE_16_WIDE, base_tile + 0x22);

    *base_sprite_id += 4 * 2;
}
