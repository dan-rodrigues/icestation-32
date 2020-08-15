// audio.c
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#include "audio.h"

void audio_set_aligned_addresses(volatile AudioChannel *channel, const int16_t *start, size_t length) {
    const size_t cpu_flash_base = 0x100000;
    const size_t adpcm_block_size = 0x400;

    size_t block_start = (((size_t)start - cpu_flash_base)) / adpcm_block_size;
    size_t block_end = block_start + (length + (adpcm_block_size / 2 - 1)) / (adpcm_block_size / 2);

    channel->sample_start_address = block_start;
    channel->sample_end_address = block_end;
}
