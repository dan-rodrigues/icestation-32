// ym2151.h
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#ifndef ym2151_h
#define ym2151_h

#include <stdint.h>
#include <stddef.h>

static void * const AUDIO_BASE = (uint32_t *)0x80000;

typedef volatile uint32_t * const AUDIO_REG;

#define YM2151_REG_ADDRESS (*((AUDIO_REG) AUDIO_BASE + 0))
#define YM2151_REG_DATA (*((AUDIO_REG) AUDIO_BASE + 1))

#define YM2151_PRESCALER (*((AUDIO_REG) AUDIO_BASE + 2))

#define YM2151_STATUS (*((AUDIO_REG) AUDIO_BASE + 0))


#endif /* ym2151_h */
