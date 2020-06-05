// main.c
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#include "vdp.h"
#include "vdp_regs.h"
#include "copper.h"
#include "math_util.h"

static const int16_t SCALE_Q_1 = 0x0100;

static const uint16_t TILE_BASE = 0x0000;
static const uint16_t MAP_BASE = 0x1000;

static void draw_raster_bars(uint16_t line_offset);

int main() {
    vdp_enable_copper(false);
    vdp_enable_layers(0);

    // TODO: can eventually alpha blend onto the checkerboard

    // tiles (8x8 font, common to both layers)
//    vdp_set_layer_tile_base(0, TILE_BASE);
//    vdp_set_layer_tile_base(1, TILE_BASE);

    // the polygon layer (also showing the text) is a full wdith 1024x512 layer
    vdp_set_wide_map_layers(SCROLL0);
    // this layer is also alpha blended onto the checkboard background
    vdp_set_alpha_over_layers(SCROLL0);

    // checkerboard background (512x512, tiled repeatedly)
    vdp_set_layer_map_base(1, MAP_BASE);
    vdp_seek_vram(MAP_BASE + 1);
    vdp_set_vram_increment(2);

    const uint8_t checkerboard_dimension = 4;
    const uint16_t opaque_tile = ' ';

    for (uint8_t y = 0; y < 64; y++) {
        uint8_t y_even = (y / checkerboard_dimension) & 1;

        for (uint8_t x = 0; x < 64; x++) {
            const uint8_t light_palette = 1;
            const uint8_t dark_palette = 2;

            uint8_t x_even = (x / checkerboard_dimension) & 1;
            bool is_dark = y_even ^ x_even;

            uint8_t palette = is_dark ? dark_palette : light_palette;
            uint16_t map_word = opaque_tile | palette << SCROLL_MAP_PAL_SHIFT;
            vdp_write_vram(map_word);
        }
    }

    // initialize all map tiles to the empty opaque tile (space character)

    vdp_set_layer_map_base(0, MAP_BASE);
    vdp_set_vram_increment(2);
    vdp_seek_vram(MAP_BASE + 0);
    vdp_fill_vram(0x2000, opaque_tile);

    // checkerboard scrolling background palette

    const uint8_t checkerboard_bright_palette_id = 0x11;
    const uint16_t checkerboard_bright_color = 0xfaaa;
    vdp_set_single_palette_color(checkerboard_bright_palette_id, checkerboard_bright_color);

    const uint8_t checkerboard_dark_palette_id = 0x21;
    const uint16_t checkerboard_dark_color = 0xf000;
    vdp_set_single_palette_color(checkerboard_dark_palette_id, checkerboard_dark_color);

    uint32_t frame_counter = 0;
    uint16_t line_offset = 0;
    uint16_t scroll = 0;

    vdp_wait_frame_ended();

    while (true) {
        // this wait must happen before changing copper enable state
        // there is risk of contention with VDP register writes otherwise
        draw_raster_bars(line_offset);

        vdp_wait_frame_ended();
        vdp_enable_copper(false);

        frame_counter++;
        line_offset++;

        if (frame_counter % 2) {
            scroll++;
        }
    }

    return 0;
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
    cop_wait_target_x(2);

    vdp_enable_copper(true);

    uint16_t line = 0;
    while (line < SCREEN_ACTIVE_HEIGHT) {
        uint16_t selected_line = line + line_offset;
        uint16_t bar_offset = selected_line % bar_height;
        uint16_t visible_bar_height = bar_height - bar_offset;
        // clip if the bar "runs over the bottom of the screen"
        visible_bar_height = MIN(SCREEN_ACTIVE_HEIGHT - line, visible_bar_height);

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
        if (line < SCREEN_ACTIVE_HEIGHT) {
            cop_wait_target_y(line);
        }
    }

    cop_jump(0);
}
