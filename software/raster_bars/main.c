#include <stdint.h>
#include <stdbool.h>

#include "vdp.h"
#include "copper.h"

// can aim for just color 0 driving this

int main() {
    // atleast one layer active is needed to enable display
    // could revist this, color 0 by itself is useful
    vdp_enable_layers(0);
    vdp_set_wide_map_layers(0);
    vdp_set_alpha_over_layers(0);

    vdp_set_single_palette_color(0, 0xf888);

    while (true) {

    }

    return 0;
}
