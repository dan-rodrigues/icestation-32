// audio.c
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#include "audio.h"

void audio_set_aligned_addresses(volatile AudioChannel *channel, const int16_t *start, size_t length) {
    AudioAlignedAddresses addresses;
    audio_aligned_addresses(start, length, &addresses);

    channel->sample_start_address = addresses.start;
    channel->sample_end_address = addresses.end;
    channel->sample_loop_address = addresses.loop;
}

void audio_aligned_addresses(const int16_t *start, size_t length, AudioAlignedAddresses *addresses) {
    const uintptr_t cpu_flash_base = 0x1000000;
    const size_t adpcm_block_size = 0x400; // in bytes

    uintptr_t block_start = (((size_t)start - cpu_flash_base)) / adpcm_block_size;
    uintptr_t block_end = block_start + (length + (adpcm_block_size / 2 - 1)) / (adpcm_block_size / 2);

    addresses->start = block_start;
    addresses->end = block_end;
    addresses->loop = block_start;
}
