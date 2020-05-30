#ifndef copper_h
#define copper_h

#include <stdint.h>
#include <stdbool.h>

void cop_ram_seek(uint16_t address);

// op writes
void cop_set_target_x(uint16_t target_x);

void cop_wait_target_x(uint16_t target_x);
void cop_wait_target_y(uint16_t target_y);

// some way to hide the reg is ideal but may not be possible
// if const. prop optimisations are good enough could have a map function

// easier solution:
// or: just import a separate header with VDP regs, for use only by callers of this

typedef enum {
    CWM_SINGLE = 0,
    CWM_DOUBLE = 1,
    CWM_QUAD = 2
} COPWriteMode;

typedef struct  {
    COPWriteMode mode;
    uint8_t reg;
    uint8_t batch_count;
    bool batch_wait_between_lines;

    int8_t batches_written;
} COPBatchWriteConfig;

void cop_write(uint8_t reg, uint16_t data);

// params
void cop_start_batch_write(COPBatchWriteConfig *config);
void cop_add_batch_single(COPBatchWriteConfig *config, uint16_t data);
void cop_add_batch_double(COPBatchWriteConfig *config, uint16_t data0, uint16_t data1);
void cop_add_batch_quad(COPBatchWriteConfig *config, uint16_t data0, uint16_t data1, uint16_t data2, uint16_t data3);

// signal that it's done for the frame (assertions etc)
void cop_done();

void cop_jump(uint16_t address);

#endif /* copper_h */
