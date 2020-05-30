#include <stdint.h>
#include <stdbool.h>

#include "vdp.h"
#include "copper.h"

// can aim for just color 0 driving this

int main() {
    // atleast one layer active is needed to enable display
    // could revist this, color 0 by itself is useful
    vdp_enable_copper(false);
    
    vdp_enable_layers(0);
    vdp_set_wide_map_layers(0);
    vdp_set_alpha_over_layers(0);

    // WIP: copper setup
    /*
     #define VDP_PALETTE_ADDRESS (*((volatile uint16_t *) VDP_BASE + 2))
     #define VDP_PALETTE_WRITE_DATA (*((volatile uint16_t *) VDP_BASE + 3))
     */

    cop_ram_seek(0);

    cop_set_target_x(0);
    cop_wait_target_y(32);

    // should probably have a separate for config and in-progress write
    COPBatchWriteConfig config = {
        .mode = CWM_DOUBLE,
        .reg = 0x02,
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

        cop_wait_target_x(400);

        // green
        cop_start_batch_write(&config);
        cop_add_batch_double(&config, 0, 0xf080);

        cop_wait_target_x(400 + 256);

        // brown
        cop_start_batch_write(&config);
        cop_add_batch_double(&config, 0, 0xf440);
    }

    // batch write

    const uint8_t test_batch_count = 32;

    cop_set_target_x(0);
    
    config.batch_count = test_batch_count - 1;
    config.batch_wait_between_lines = true;
    cop_start_batch_write(&config);

    for (uint8_t i = 0; i < test_batch_count / 2; i++) {
        // (other color components too)
        cop_add_batch_double(&config, 0, 0xf000 | (i/2 << 8));
    }
    for (uint8_t i = 0; i < test_batch_count / 2; i++) {
        cop_add_batch_double(&config, 0, 0xf800 - (i/2 << 8));
    }

    // fade up
//    for (uint8_t i = 0; i < 16; i++) {
//        cop_add_batch_double(&config, 0, 0xf000 + (i << 4));
//    }
    // fade down
//    for (uint8_t i = 0; i < 16; i++) {
//        cop_add_batch_double(&config, 0, 0xf080 - (i << 4));
//    }

    cop_jump(0);

    vdp_enable_copper(true);

    while (true) {
        vdp_wait_frame_ended();

        // back to gray
        vdp_set_single_palette_color(0, 0xf888);
    }

    return 0;
}
