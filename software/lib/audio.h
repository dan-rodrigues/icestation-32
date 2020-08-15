// audio.h
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#ifndef audio_h
#define audio_h

#include <stdint.h>
#include <stddef.h>

static const void *const AUDIO_BASE = (void *)0x80000;

typedef volatile uint16_t *const AUDIO_REG;

typedef enum {
    AUDIO_FLAG_LOOP = (1 << 0)
} __attribute__((packed)) AudioFlags;

typedef struct {
    volatile int8_t left, right;
} __attribute__((packed)) AudioVolumes;

typedef struct {
    volatile uint16_t sample_start_address;

    uint8_t flags_padding;
    volatile uint8_t flags;

    volatile uint16_t sample_end_address;
    volatile uint16_t sample_loop_address;
    volatile AudioVolumes volumes;
    volatile uint16_t pitch;

    // (unused padding)
    uint16_t padding[2];

} __attribute__((packed)) AudioChannel;

typedef struct {
    volatile AudioChannel channels[8];
} __attribute__((packed)) Audio;

// Writes:

static Audio *const AUDIO = (Audio*)(AUDIO_BASE + 0x000);
static AUDIO_REG AUDIO_GB_BASE = (AUDIO_REG)(AUDIO_BASE + 0x200);

#define AUDIO_GB_PLAY (*((AUDIO_REG) AUDIO_GB_BASE + 0))
#define AUDIO_GB_STOP (*((AUDIO_REG) AUDIO_GB_BASE + 1))

// Reads:

#define AUDIO_STATUS_PLAYING (*((AUDIO_REG) AUDIO_BASE + 0))
#define AUDIO_STATUS_ENDED (*((AUDIO_REG) AUDIO_BASE + 1))
#define AUDIO_STATUS_BUSY ((*((AUDIO_REG) AUDIO_BASE + 2)) & 0x01)

// Utility functions:

void audio_set_aligned_addresses(volatile AudioChannel *channel, const int16_t *start, size_t length);

#endif /* audio_h */
