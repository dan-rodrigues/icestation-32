#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#include "vdp.h"
#include "vdp_regs.h"
#include "copper.h"

int main() {
    // atleast one layer active is needed to enable display
    // could revist this, color 0 by itself is useful
    vdp_enable_copper(false);
    
    vdp_enable_layers(0);
    vdp_set_wide_map_layers(0);
    vdp_set_alpha_over_layers(0);

    cop_ram_seek(0);

    cop_set_target_x(0);
    cop_wait_target_y(32);

    // should probably have a separate for config and in-progress write
    COPBatchWriteConfig config = {
        .mode = CWM_DOUBLE,
        .reg = &VDP_PALETTE_ADDRESS,
        .batch_count = 1 - 1,
        .batch_wait_between_lines = false
    };

    // teal
    cop_start_batch_write(&config);
    cop_add_batch_double(&config, 0, 0xf088);

    cop_wait_target_y(64);

    // yellow
    cop_start_batch_write(&config);
    cop_add_batch_double(&config, 0, 0xf880);

    // half wide block, enabled / disabled midline

    for (uint8_t i = 0; i < 32; i++) {
        cop_set_target_x(0);
        cop_wait_target_y(96 + i);

        cop_wait_target_x(240 + 256);

        // green
        cop_start_batch_write(&config);
        cop_add_batch_double(&config, 0, 0xf080);

        cop_wait_target_x(1100 - 256);

        // brown
        cop_start_batch_write(&config);
        cop_add_batch_double(&config, 0, 0xf440);
    }

    // bar test

    // TODO: some sort of enable/disable test midline

    static const uint16_t color_masks[] = {
        0xff00, 0xf0f0, 0xf00f, 0xffff, 0xfff0, 0xf0ff, 0xff0f, 0xffff
    };
    const size_t color_mask_count = sizeof(color_masks) / sizeof(uint16_t);
    const uint8_t bar_height = 32;

    uint16_t line_offset = 0;
    const uint16_t screen_height = 512 - 192;

    cop_set_target_x(0);

    const uint8_t batch_size = 32 - 1;

//    config.batch_count = batch_size;
//    config.batch_wait_between_lines = true;
//    cop_start_batch_write(&config);

    uint16_t line = line_offset;
    while (line < screen_height) {
        config.batch_count = batch_size;
        config.batch_wait_between_lines = true;
        cop_start_batch_write(&config);

        uint8_t mask_selected = (line / bar_height) % color_mask_count;
        uint16_t color_mask = color_masks[mask_selected];

        for (uint8_t bar_y = line % bar_height; bar_y < bar_height; bar_y++) {
            uint16_t color = 0;
            uint8_t y = bar_y % (bar_height / 2);

            if (bar_y < bar_height / 2) {
                color = 0xf000 | y << 8 | y << 4 | y;
                color &= color_mask;
            } else {
                color = 0xffff - (y << 8) - (y << 4) - y;
                color &= color_mask;
            }

            cop_add_batch_double(&config, 0, color);
        }

        line += bar_height;
    }

    cop_jump(0);

    vdp_enable_copper(true);

    while (true) {
        vdp_wait_frame_ended();

        // back to gray
//        vdp_set_single_palette_color(0, 0xf888);
    }

    return 0;
}
