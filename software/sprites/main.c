#include "vdp.h"
#include "math_util.h"

#include <stdint.h>
#include <stdbool.h>

#include "tiles.h"
#include "palette.h"

void draw_crystal_sprite(uint8_t *base_sprite_id, uint16_t base_tile, uint8_t palette, uint16_t x, uint16_t y);

// sprite pattern arrangement

static const uint8_t YELLOW_PALETTE = 0;
static const uint8_t RED_PALETTE = 1;
static const uint8_t GREEN_PALETTE = 2;
static const uint8_t MAGENTA_PALETTE = 3;

// background colors to cycle through
// note the format is ARGB16 so all example colors for the background are alpha = 100%
static const uint16_t CYCLED_BACKGROUND_COLORS[] = {0xf088, 0xf600, 0xf888, 0xf000};

// sprite circle arrangements

typedef struct {
    uint8_t sprite_count;
    uint16_t angle_delta;
    int16_t radius;
    uint8_t palette;
} CircleArrangement;

static const CircleArrangement CIRCLE_ARRANGEMENTS[] = {
    {.sprite_count = 32, .angle_delta = SIN_PERIOD / 32, .radius = 192, .palette = YELLOW_PALETTE},
    {.sprite_count = 16, .angle_delta = SIN_PERIOD / 16, .radius = 128, .palette = GREEN_PALETTE},
    {.sprite_count = 8, .angle_delta = SIN_PERIOD / 8, .radius = 64, .palette = RED_PALETTE},
    {.sprite_count = 1, .angle_delta = SIN_PERIOD / 1, .radius = 0, .palette = MAGENTA_PALETTE},
};

static const size_t CIRCLE_ARRANGEMENT_COUNT = sizeof(CIRCLE_ARRANGEMENTS) / sizeof(CircleArrangement);

// sprite animation metadata

static const uint8_t CRYSTAL_ANIMATION_FRAMES = 8;
static const uint8_t CRYSTAL_FRAME_WIDTH = 32;

// options to toggle

// layers must be opted into alpha compositing
// without it enabled, the "alpha" channel is treated as an intensity from black to the original color
// with it enabled, the alpha channel is used to blend with the topmost opaque layer beneath it
static const bool ENABLE_SPRITE_ALPHA = true;

// this enables immediate animation for use in the simulator since the frame rate is much lower
static const bool ENABLE_FAST_ANIMATION = false;

int main() {
    // layer configuration (only sprites are used here)
    vdp_enable_layers(SPRITES);
    vdp_set_alpha_over_layers(ENABLE_SPRITE_ALPHA ? SPRITES : 0);

    const uint16_t tile_base = 0x0000;
    vdp_set_sprite_tile_base(tile_base);

    // tile upload

    vdp_set_vram_increment(1);
    vdp_seek_vram(tile_base);

    for (uint16_t i = 0; i < tiles_length; i++) {
        vdp_write_vram(tiles[i] & 0xffff);
        vdp_write_vram(tiles[i] >> 16);
    }

    // palette upload

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

    uint16_t frame_counter = 0;
    uint8_t base_sprite_id = 0;

    vdp_clear_all_sprites();

    while(true) {
        // first row of 32x32 animation frames
        const uint8_t crystal_frames_bank_0 = 0x000;
        // second row of 32x32 animation frames
        const uint8_t crystal_frames_bank_1 = 0x040;

        uint8_t crystal_frame = frame_counter / 4;
        crystal_frame &= (CRYSTAL_ANIMATION_FRAMES - 1);
        uint16_t crystal_tile_base = (crystal_frame & 3) * CRYSTAL_FRAME_WIDTH / 8;
        crystal_tile_base += (crystal_frame & 4) ? crystal_frames_bank_1 : crystal_frames_bank_0;

        uint8_t back_color_index = frame_counter / (ENABLE_FAST_ANIMATION ? 1: 0x80) & 3;

        vdp_set_single_palette_color(0, CYCLED_BACKGROUND_COLORS[back_color_index]);

        for (uint8_t circle = 0; circle < CIRCLE_ARRANGEMENT_COUNT; circle++) {
            CircleArrangement arrangement = CIRCLE_ARRANGEMENTS[circle];

            int16_t radius = arrangement.radius;
            uint8_t palette = arrangement.palette;
            uint8_t sprite_count = arrangement.sprite_count;
            uint16_t angle_delta = arrangement.angle_delta;

            uint16_t angle = frame_counter;

            for (uint8_t i = 0; i < sprite_count; i++) {
                const int16_t screen_center_x = 848 / 2;
                const int16_t screen_center_y = 480 / 2;

                int16_t sin_t = sin(angle);
                int16_t cos_t = cos(angle);

                int16_t sprite_x = sys_multiply(cos_t, -radius) / SIN_MAX;
                int16_t sprite_y = sys_multiply(sin_t, -radius) / SIN_MAX;

                sprite_x += screen_center_x;
                sprite_y += screen_center_y;

                draw_crystal_sprite(&base_sprite_id, crystal_tile_base, palette, sprite_x, sprite_y);

                angle += angle_delta;
            }
        }

        vdp_wait_frame_ended();

        base_sprite_id = 0;
        frame_counter++;
    }
}

void draw_crystal_sprite(uint8_t *base_sprite_id, uint16_t base_tile, uint8_t palette, uint16_t x, uint16_t y) {
    const int16_t sprite_x_offset = -16;
    const int16_t sprite_y_offset = -16;

    vdp_seek_sprite(*base_sprite_id);

    for (uint8_t i = 0; i < 4; i++) {
        bool right_column = (i & 1);
        bool bottom_row = (i & 2);

        uint16_t x_block = x + sprite_x_offset + (right_column ? 0x10 : 0);

        uint16_t y_block = y + sprite_y_offset + (bottom_row ? 0x10 : 0);
        y_block |= SPRITE_16_TALL | SPRITE_16_WIDE;

        uint16_t g_block = base_tile;
        g_block += (right_column ? 0x02 : 0);
        g_block += (bottom_row ? 0x20 : 0);
        g_block |= palette << SPRITE_PAL_SHIFT;

        vdp_write_sprite_meta(x_block, y_block, g_block);
        *base_sprite_id += 1;
    }
}
