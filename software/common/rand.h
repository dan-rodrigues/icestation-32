// rand.h: generate random bits
//
// Copyright (C) 2020 Mara "vmedea" <vmedea@protonmail.com>
//
// SPDX-License-Identifier: MIT

#ifndef rand_h
#define rand_h

#include <stdint.h>

/**
 * Seed random number generator.
 */
void srand(uint32_t s);

/**
 * LFSR "random" bits implementation. This does not generate strong randomness,
 * only unpredictability fine for visual effects and such.
 */
uint32_t randbits(uint8_t nbits);

#endif
