#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#include "vdp.h"
#include "vdp_regs.h"
#include "copper.h"
#include "math_util.h"

static const uint16_t SCREEN_HEIGHT = 480;

static void draw_layer_mask();
static void draw_raster_bars(uint16_t line_offset);

int main() {
    vdp_enable_copper(false);

    // TODO: opaque layer for masking
    vdp_enable_layers(SCROLL0);
    vdp_set_wide_map_layers(0);
    vdp_set_alpha_over_layers(0);

    // opaque tile for foreground
    vdp_set_layer_tile_base(0, 0x0000);
    vdp_set_vram_increment(1);
    vdp_seek_vram(0);
    vdp_fill_vram(0x20 / 2, 0x1111);

    // set all map tiles to use opaque tile
    vdp_set_layer_map_base(0, 0x1000);
    vdp_set_vram_increment(2);
    vdp_seek_vram(0x1000);
    // tile 00 for entire map
    vdp_fill_vram(0x1000, 0x0000);

    // palette for opaque color
    vdp_set_single_palette_color(1, 0xf088);

    uint16_t line_offset = 0;

    vdp_wait_frame_ended();

    while (true) {
//        draw_raster_bars(line_offset);
        draw_layer_mask();
        vdp_enable_copper(true);

        vdp_wait_frame_ended();

        line_offset++;
    }

    return 0;
}

// plain old shift-and-subtract
// this can be replaced with newton's method to find reciprocal

uint32_t full_divide(uint32_t dividend, uint32_t divisor) {
    uint32_t quotient = 0;
    uint32_t quotientMask = 1 << 31;

    uint64_t extendedDivisor = ((uint64_t)divisor) << 31;
    uint64_t extendedDividend = dividend;

    while (quotientMask) {
        if (extendedDivisor <= extendedDividend) {
            extendedDividend -= extendedDivisor;
            quotient |= quotientMask;
        }

        extendedDivisor >>= 1;
        quotientMask >>= 1;
    }

    return quotient;
}

// triangle mask
static void draw_layer_mask() {
    cop_ram_seek(0);

    // TODO: variable points
    uint16_t top_x, top_y;
    uint16_t mid_x, mid_y;
    uint16_t bottom_x, bottom_y;

    top_x = 600;
    top_y = 16;

    mid_x = 500;
    mid_y = 100;

    bottom_x = 250;
    bottom_y = 400;

    // top to mid

    // must be interpolated to mid_x per line
    uint32_t x = top_x << 16;
    uint32_t x_m = x;

    int16_t dx = top_x - mid_x;
    int16_t dy = mid_y - top_y;

    int16_t dx_m = top_x - bottom_x;
    int16_t dy_m = bottom_y - top_y;

    // actually want dx/dy since the y increments per line but x changes variably

    // (sign...)
    int32_t delta_x = full_divide(dx * 0x10000, dy);
    int32_t delta_x_m = full_divide(dx_m * 0x10000, dy_m);

    if (dx > 0) {
        delta_x = -delta_x;
    }

    for (uint16_t y = top_y; y < mid_y; y++) {
        uint16_t e1 = x / 0x10000;
        uint16_t e2 = x_m / 0x10000 + 2;

        if (e1 == e2) {
            continue;
        }

        uint16_t left = MIN(e1, e2);
        uint16_t right = MAX(e1, e2);

        cop_set_target_x(left);
        cop_wait_target_y(y);

        cop_write(&VDP_LAYER_ENABLE, SCROLL0);

        if ((right - left) > 2) {
            cop_wait_target_x(right);
        }

        cop_write(&VDP_LAYER_ENABLE, 0);

        // delta update for next line
        x += delta_x;
        x_m += delta_x_m;
    }

    cop_write(&VDP_LAYER_ENABLE, 0);

    // fixed triangle:
//    for (uint8_t i = 0; i < 200; i++) {
//        uint16_t center = 240 + 848 / 2;
//        uint16_t left = center - i;
//        uint16_t right = center + i;
//
//        if (left == right) {
//            continue;
//        }
//
//        cop_set_target_x(left);
//        cop_wait_target_y(i);
//
//        cop_write(&VDP_LAYER_ENABLE, SCROLL0);
//
//        if ((right - left) > 2) {
//            cop_wait_target_x(right);
//        }
//
//        cop_write(&VDP_LAYER_ENABLE, 0);
//    }

    cop_jump(0);
}

static void draw_raster_bars(uint16_t line_offset) {
    static const uint16_t color_masks[] = {
        0xff00, 0xf0f0, 0xf00f, 0xffff, 0xfff0, 0xf0ff, 0xff0f, 0xffff
    };
    const size_t color_mask_count = sizeof(color_masks) / sizeof(uint16_t);
    const uint8_t bar_height = 32;

    COPBatchWriteConfig config = {
        .mode = CWM_DOUBLE,
        .reg = &VDP_PALETTE_ADDRESS
    };

    cop_ram_seek(0);

    cop_set_target_x(0);
    cop_wait_target_y(0);

    uint16_t line = 0;
    while (line < SCREEN_HEIGHT) {
        uint16_t selected_line = line + line_offset;
        uint16_t bar_offset = selected_line % bar_height;
        uint16_t visible_bar_height = bar_height - bar_offset;
        // clip if the bar "runs over the bottom of the screen"
        visible_bar_height = MIN(SCREEN_HEIGHT - line, visible_bar_height);

        // at some point these will have to be broken up
        // since the horizontal updates have to be woven into this table too
        config.batch_count = visible_bar_height - 1;
        config.batch_wait_between_lines = true;
        cop_start_batch_write(&config);

        uint8_t mask_selected = (selected_line / bar_height) % color_mask_count;
        uint16_t color_mask = color_masks[mask_selected];

        for (uint8_t bar_y = 0; bar_y < visible_bar_height; bar_y++) {
            uint16_t color = 0;
            uint8_t bar_y_offset = bar_y + bar_offset;
            uint8_t y = bar_y_offset % (bar_height / 2);

            if (bar_y_offset < (bar_height / 2)) {
                color = 0xf000 | y << 8 | y << 4 | y;
                color &= color_mask;
            } else {
                color = 0xffff - (y << 8) - (y << 4) - y;
                color &= color_mask;
            }

            cop_add_batch_double(&config, 0, color);
        }

        line += visible_bar_height;

        // must wait 1 line or else it'll immediately start processing the *next* line
        if (line < SCREEN_HEIGHT) {
            cop_wait_target_y(line);
        }
    }

    cop_jump(0);
}
