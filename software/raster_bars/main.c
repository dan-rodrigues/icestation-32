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
    // paddr
    cop_write(0x02, 0);
    // pdata
    cop_write(0x03, 0xf088);

    cop_jump(0);

    vdp_enable_copper(true);

    while (true) {
        vdp_wait_frame_ended();

        // back to gray
        vdp_set_single_palette_color(0, 0xf888);
    }

    return 0;
}
