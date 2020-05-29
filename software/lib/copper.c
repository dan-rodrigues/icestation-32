#include "copper.h"

#include <stddef.h>

#include "assert.h"

// volatile is strictly correct here considering a coprocessor is reading this
// in practice it might
static volatile uint16_t * const COP_RAM = (uint16_t *)0x50000;
static const size_t COP_RAM_SIZE = 0x1000 / sizeof(uint16_t);

static uint16_t current_address = 0;

// 3bit ops

static const uint8_t OP_SHIFT = 13;

typedef enum {
    SET_TARGET_X = 0,
    WAIT_TARGET_Y = 1,
    WRITE_REG = 2,
    JUMP = 3
} Op;

void cop_ram_seek(uint16_t address) {
    current_address = address;
}

void cop_set_target_x(uint16_t target_x) {
    uint16_t op_word = SET_TARGET_X << OP_SHIFT; // macro..
    op_word |= target_x;
    COP_RAM[current_address++] = op_word;
}

void cop_wait_target_y(uint16_t target_y) {
    uint16_t op_word = WAIT_TARGET_Y << OP_SHIFT;
    op_word |= target_y;
    COP_RAM[current_address++] = op_word;
}

void cop_write(uint8_t reg, uint16_t data) {
    uint16_t op_word = WRITE_REG << OP_SHIFT;
    op_word |= reg;
    COP_RAM[current_address++] = op_word;
    COP_RAM[current_address++] = data;
}

void cop_jump(uint16_t address) {
    assert(address < COP_RAM_SIZE);

    uint16_t op_word = JUMP << OP_SHIFT;
    op_word |= address;
    COP_RAM[current_address++] = op_word;
}
