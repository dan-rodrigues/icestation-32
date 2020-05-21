// TODO: header

#include "vdp.h"

#include <stdint.h>
#include <stdbool.h>

#include "tiles.h"
#include "palette.h"

void draw_crystal_sprite(uint8_t *base_sprite_id, uint16_t base_tile, uint16_t x, uint16_t y);

// TODO relocate
int16_t cos(uint16_t angle);
int16_t sin(uint16_t angle);

int32_t sys_multiply(int16_t a, int16_t b);

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
    vdp_set_single_palette_color(0, 0xf088);

    // place a sprite

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

        // TODO: some pattern arrangement
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

            draw_crystal_sprite(&base_sprite_id, crystal_tile_base, sprite_x, sprite_y);
        }

        vdp_wait_frame_ended();

        base_sprite_id = 0;
        frame_counter++;
    }
}

void draw_crystal_sprite(uint8_t *base_sprite_id, uint16_t base_tile, uint16_t x, uint16_t y) {
    vdp_seek_sprite(*base_sprite_id);
    vdp_write_sprite_meta(x, y | SPRITE_16_TALL | SPRITE_16_WIDE, base_tile);
    vdp_write_sprite_meta(x + 16, y | SPRITE_16_TALL | SPRITE_16_WIDE, base_tile + 2);
    vdp_write_sprite_meta(x, (y + 16) | SPRITE_16_TALL | SPRITE_16_WIDE, base_tile + 0x20);
    vdp_write_sprite_meta(x + 16, (y + 16) | SPRITE_16_TALL | SPRITE_16_WIDE, base_tile + 0x22);

    *base_sprite_id += 4;
}

// TODO: relocate to common section

#include "sin.h"

// dsp mmio

volatile uint32_t *const SYS_MUL_BASE = (uint32_t *)0x030000;

// mind the sign on these when unsigned is added later

#define SYS_MUL_A (*((volatile int16_t *)SYS_MUL_BASE + 0))
#define SYS_MUL_B (*((volatile int16_t *)SYS_MUL_BASE + 2))

#define SYS_MUL_RESULT (*((volatile int32_t *)SYS_MUL_BASE + 0))

static const uint16_t SIN_PERIOD = 0x400;
static const uint16_t SIN_HALF_PERIOD = SIN_PERIOD / 2;
static const uint16_t SIN_QUARTER_PERIOD = SIN_PERIOD / 4;

static const int16_t SIN_MAX = 0x4000;

int16_t cos(uint16_t angle) {
    return sin(angle + SIN_QUARTER_PERIOD);
}

int16_t sin(uint16_t angle) {
    angle &= (SIN_PERIOD - 1);

    // special cases to avoid "flat spots" in the sin wave
    if (angle == SIN_QUARTER_PERIOD) {
        return SIN_MAX;
    } else if (angle == SIN_HALF_PERIOD) {
        return 0;
    } else if (angle == (3 * SIN_QUARTER_PERIOD)) {
        return -SIN_MAX;
    }

    uint16_t index = angle;
    index = (angle & SIN_QUARTER_PERIOD ? -index : index);
    index &= (SIN_QUARTER_PERIOD - 1);

    // TODO: generate an actual table of 16bit ints, add something to utils for this instead of using xxd
    int16_t sin = ((int16_t *)_Users_dan_rodrigues_Documents_sin_bin)[index];

    return (angle & SIN_HALF_PERIOD ? -sin : sin);
}

// dsp mult

int32_t sys_multiply(int16_t a, int16_t b) {
    SYS_MUL_A = a;
    SYS_MUL_B = b;

    // DSP disabeld temporarily
    return SYS_MUL_RESULT;
}
