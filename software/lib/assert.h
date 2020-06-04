// assert.h
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#ifndef assert_h
#define assert_h

#include <stdbool.h>

void assert(bool assertion);
void fatal_error(void);

#endif /* assert_h */
