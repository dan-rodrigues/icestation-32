#ifndef vdp_print_h
#define vdp_print_h

#include <stdint.h>

#include "vdp.h"

void vp_print(const char *string, uint8_t x, uint8_t y, uint8_t palette, VDPLayer layer, uint16_t vram_base);

uint8_t vp_center_string_x(const char *string);

#endif /* vdp_print_h */
