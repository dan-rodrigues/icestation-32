// TODO: header

#include "vdp.h"

#include <stdint.h>
#include <stdbool.h>

int main() {
    vdp_enable_layers(SPRITES);
    // if alpha sprites are eventually used, need to reenable this one
    vdp_set_alpha_over_layers(0);

    const uint16_t tile_base = 0x0000;
    vdp_set_sprite_tile_base(tile_base);

    // TODO: upload the actual sprites, palettes...

    while(true) {}
}
