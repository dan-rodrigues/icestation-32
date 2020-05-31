#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#include "vdp.h"
#include "vdp_regs.h"
#include "copper.h"
#include "math_util.h"

int main() {
    vdp_enable_copper(false);

    vdp_enable_layers(0);
    vdp_set_wide_map_layers(0);
    vdp_set_alpha_over_layers(0);

    COPBatchWriteConfig config = {
        .mode = CWM_DOUBLE,
        .reg = &VDP_PALETTE_ADDRESS
    };

    static const uint16_t color_masks[] = {
        0xff00, 0xf0f0, 0xf00f, 0xffff, 0xfff0, 0xf0ff, 0xff0f, 0xffff
    };
    const size_t color_mask_count = sizeof(color_masks) / sizeof(uint16_t);
    const uint8_t bar_height = 32;

    uint16_t line_offset = 0;
    const uint16_t screen_height = 480;

    while (true) {
        cop_ram_seek(0);

        cop_set_target_x(0);
        cop_wait_target_y(0);

        uint16_t line = 0;
        while (line < screen_height) {
            uint16_t selected_line = line + line_offset;
            uint16_t bar_offset = selected_line % bar_height;
            uint16_t visible_bar_height = bar_height - bar_offset;
            // clip if the bar "runs over the bottom of the screen"
            visible_bar_height = MIN(screen_height - line, visible_bar_height);

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
        }

        cop_jump(0);

        vdp_enable_copper(true);

        vdp_wait_frame_ended();

        line_offset++;
    }

    return 0;
}
