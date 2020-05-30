#ifndef copper_h
#define copper_h

#include <stdint.h>

void cop_ram_seek(uint16_t address);

// op writes
void cop_set_target_x(uint16_t target_x);

void cop_wait_target_x(uint16_t target_x);
void cop_wait_target_y(uint16_t target_y);

// some way to hide the reg is ideal but may not be possible
// if const. prop optimisations are good enough could have a map function

// easier solution:
// or: just import a separate header with VDP regs, for use only by callers of this

void cop_write(uint8_t reg, uint16_t data);

// signal that it's done for the frame (assertions etc)
void cop_done();

void cop_jump(uint16_t address);

#endif /* copper_h */
