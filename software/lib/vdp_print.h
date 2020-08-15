// vdp_print.h
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#ifndef vdp_print_h
#define vdp_print_h

#include <stdint.h>
#include <stdarg.h>

#include "vdp.h"

void vp_print_init(void);

void vp_printf(uint8_t x, uint8_t y, uint8_t palette, VDPLayer layer, uint16_t vram_base, const char *fmt, ...);

void vp_clear_row(uint8_t y, VDPLayer layer, uint16_t vram_base);

uint8_t vp_center_string_x(const char *string);

#endif /* vdp_print_h */
