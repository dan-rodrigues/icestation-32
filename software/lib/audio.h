// audio.h
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#ifndef audio_h
#define audio_h

#include <stdint.h>
#include <stddef.h>

static const void *const AUDIO_BASE = (uint32_t *)0x80000;

typedef volatile uint32_t *const AUDIO_REG;

typedef enum {
    AUDIO_FLAG_LOOP = (1 << 0)
} __attribute__((packed)) AudioFlags;

typedef struct {
    volatile int8_t left, right;
} __attribute__((packed)) AudioVolumes;

typedef struct {
    volatile uint16_t sample_start_address;

    volatile uint8_t flags;
    uint8_t flags_padding;

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

typedef struct {
    uint16_t start;
    uint16_t end;
    uint16_t loop;
} AudioAlignedAddresses;

/**
 * Set sample start address and length for a channel. The specified length is in
 * 16-bit units. The loop address will be the same as the end address, so if
 * looping is enabled the entire sample will loop.
 */
void audio_set_aligned_addresses(volatile AudioChannel *channel, const int16_t *start, size_t length);

/**
 * Compute sample start address and length for a channel. The specified length
 * is in 16-bit units.
 */
void audio_aligned_addresses(const int16_t *start, size_t length, AudioAlignedAddresses *addresses);

#endif /* audio_h */
