#ifndef vdp_print_h
#define vdp_print_h

#include <stdint.h>

#include "vdp.h"

void print(const char *string, uint8_t x, uint8_t y, uint8_t palette, VDPLayer layer, uint16_t vram_base);

#endif /* vdp_print_h */
