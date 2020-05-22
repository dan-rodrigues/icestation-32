#include "vdp.h"
#include "math_util.h"

#include <stdint.h>
#include <stdbool.h>

#include "tiles.h"
#include "palette.h"

void draw_crystal_sprite(uint8_t *base_sprite_id, uint16_t base_tile, uint8_t palette, uint16_t x, uint16_t y);

int main() {
    vdp_enable_layers(SPRITES);
    vdp_set_alpha_over_layers(SPRITES);

    const uint16_t tile_base = 0x0000;
    vdp_set_sprite_tile_base(tile_base);

    // tiles

    vdp_set_vram_increment(1);
    vdp_seek_vram(tile_base);

    for (uint16_t i = 0; i < tiles_length; i++) {
        vdp_write_vram(tiles[i] & 0xffff);
        vdp_write_vram(tiles[i] >> 16);
    }

    // palette

    const uint8_t yellow_palette = 0;
    const uint8_t red_palette = 1;
    const uint8_t green_palette = 0;
    const uint8_t magenta_palette = 0;

    vdp_seek_palette(0);

    // yellow
    for (uint16_t i = 0; i < palette_length; i++) {
        vdp_write_palette_color(palette[i]);
    }
    // red
    for (uint16_t i = 0; i < palette_length; i++) {
        vdp_write_palette_color(palette[i] & 0xff00);
    }
    // green
    for (uint16_t i = 0; i < palette_length; i++) {
        vdp_write_palette_color(palette[i] & 0xf0f0);
    }
    // magenta
    for (uint16_t i = 0; i < palette_length; i++) {
        uint16_t color = palette[i];
        vdp_write_palette_color((color & 0xff00) | (color & 0x00f0) >> 4);
    }

    // background color

    vdp_set_single_palette_color(0, 0xf088);

    // sprite pattern arrangement
    
    const int16_t screen_center_x = 848 / 2;
    const int16_t screen_center_y = 480 / 2;

    // first row of 32x32 animation frames
    const uint8_t crystal_frames_bank_0 = 0x000;
    // second row of 32x32 animation frames
    const uint8_t crystal_frames_bank_1 = 0x040;

    const uint8_t crystal_total_frames = 8;
    const uint8_t crystal_frame_width = 32;

    uint16_t frame_counter = 0;

    uint8_t base_sprite_id = 0;

    while(true) {
        vdp_clear_all_sprites();

        uint8_t crystal_frame = frame_counter / 4;
        crystal_frame &= (crystal_total_frames - 1);
        uint16_t crystal_tile_base = (crystal_frame & 3) * crystal_frame_width / 8;
        crystal_tile_base += (crystal_frame & 4) ? crystal_frames_bank_1 : crystal_frames_bank_0;

        const uint8_t circle_sprites = 16;
        const uint16_t angle_step = 1024 / circle_sprites;
        const int16_t circle_radius = 192;

        const int16_t sprite_x_offset = -16;
        const int16_t sprite_y_offset = -16;

        for (uint8_t i = 0; i < circle_sprites; i++) {
            uint16_t angle = i * angle_step + frame_counter;
            int16_t sin_t = sin(angle);
            int16_t cos_t = cos(angle);

            int16_t sprite_x = sys_multiply(cos_t, -circle_radius) / 0x4000;
            int16_t sprite_y = sys_multiply(sin_t, -circle_radius) / 0x4000;

            sprite_x += screen_center_x + sprite_x_offset;
            sprite_y += screen_center_y + sprite_y_offset;

            draw_crystal_sprite(&base_sprite_id, crystal_tile_base, yellow_palette, sprite_x, sprite_y);
        }

        vdp_wait_frame_ended();

        base_sprite_id = 0;
        frame_counter++;
    }
}

void draw_crystal_sprite(uint8_t *base_sprite_id, uint16_t base_tile, uint8_t palette, uint16_t x, uint16_t y) {
    vdp_seek_sprite(*base_sprite_id);

    for (uint8_t i = 0; i < 4; i++) {
        bool right_column = (i & 1);
        bool bottom_row = (i & 2);

        uint16_t x_block = x + (right_column ? 0x10 : 0);

        uint16_t y_block = y + (bottom_row ? 0x10 : 0);
        y_block |= SPRITE_16_TALL | SPRITE_16_WIDE;

        uint16_t g_block = base_tile;
        g_block += (right_column ? 0x02 : 0);
        g_block += (bottom_row ? 0x20 : 0);
        g_block |= palette << SPRITE_PAL_SHIFT;

        vdp_write_sprite_meta(x_block, y_block, g_block);
        *base_sprite_id += 1;
    }
}
