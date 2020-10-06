// vdp_regs.h
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#ifndef vdp_regs_h
#define vdp_regs_h

#include "vdp.h"

// these register locations are kept in a separate header to avoid importing them using vdp.h
// only code that actually needs to know reg locations should include this (i.e. copper program)

static VDP_REG VDP_HSCROLL_BASE = VDP_BASE + 0x10;
static VDP_REG VDP_VSCROLL_BASE = VDP_BASE + 0x14;

#define VDP_LAYER_ENABLE (*((VDP_REG) VDP_BASE + 11))
#define VDP_ALPHA_OVER_ENABLE (*((VDP_REG) VDP_BASE + 12))
#define VDP_SCROLL_WIDE_MAP_ENABLE (*((VDP_REG) VDP_BASE + 13))

#define VDP_MATRIX_A (*((VDP_REG) VDP_HSCROLL_BASE + 1))
#define VDP_MATRIX_B (*((VDP_REG) VDP_HSCROLL_BASE + 2))
#define VDP_MATRIX_C (*((VDP_REG) VDP_HSCROLL_BASE + 3))
#define VDP_MATRIX_D (*((VDP_REG) VDP_VSCROLL_BASE + 0))

#define VDP_AFFINE_TRANSLATE_X (*((VDP_REG) VDP_HSCROLL_BASE + 0))
#define VDP_AFFINE_TRANSLATE_Y (*((VDP_REG) VDP_VSCROLL_BASE + 1))

#define VDP_AFFINE_PRETRANSLATE_X (*((VDP_REG) VDP_VSCROLL_BASE + 2))
#define VDP_AFFINE_PRETRANSLATE_Y (*((VDP_REG) VDP_VSCROLL_BASE + 3))

#define VDP_SPRITE_TILE_BASE (*((VDP_REG) VDP_BASE + 7))
#define VDP_SPRITE_BLOCK_ADDRESS (*((VDP_REG) VDP_BASE + 0))
#define VDP_SPRITE_DATA (*((VDP_REG) VDP_BASE + 1))

#define VDP_PALETTE_ADDRESS (*((VDP_REG) VDP_BASE + 2))
#define VDP_PALETTE_WRITE_DATA (*((VDP_REG) VDP_BASE + 3))

#define VDP_VRAM_ADDRESS (*((VDP_REG) VDP_BASE + 4))
#define VDP_VRAM_WRITE_DATA (*((VDP_REG) VDP_BASE + 5))
#define VDP_ADDRESS_INCREMENT (*((VDP_REG) VDP_BASE + 6))

#define VDP_ENABLE_COPPER (*((VDP_REG) VDP_BASE + 8))

#define VDP_SCROLL_TILE_ADDRESS_BASE (*((VDP_REG) VDP_BASE + 9))
#define VDP_SCROLL_MAP_ADDRESS_BASE (*((VDP_REG) VDP_BASE + 10))

#endif /* vdp_regs_h */
