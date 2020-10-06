// copper.h
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#ifndef copper_h
#define copper_h

#include <stdint.h>
#include <stdbool.h>

#include "vdp.h"

typedef enum {
    CWM_SINGLE = 0,
    CWM_DOUBLE = 1,
    CWM_QUAD = 2
} COPWriteMode;

typedef struct  {
    COPWriteMode mode;
    VDP_REG reg;
    uint8_t batch_count;
    bool batch_wait_between_lines;

    int8_t batches_written;
} COPBatchWriteConfig;

void cop_ram_seek(uint16_t address);
uint16_t cop_ram_get_write_index(void);

void cop_set_target_x(uint16_t target_x);
void cop_set_target_y(uint16_t target_y);

void cop_wait_target_x(uint16_t target_x);
void cop_wait_target_y(uint16_t target_y);

void cop_write(VDP_REG reg, uint16_t data);
void cop_write_compressed(VDP_REG reg, uint8_t data, bool increment_target_y);

void cop_start_batch_write(COPBatchWriteConfig *config);
void cop_add_batch_single(COPBatchWriteConfig *config, uint16_t data);
void cop_add_batch_double(COPBatchWriteConfig *config, uint16_t data0, uint16_t data1);
void cop_add_batch_quad(COPBatchWriteConfig *config, uint16_t data0, uint16_t data1, uint16_t data2, uint16_t data3);

void cop_jump(uint16_t address);

void cop_assert_config_consistent(const COPBatchWriteConfig *config);

#endif /* copper_h */
