#define STACK 0x00010000

    .section .text.reset
    .global irq

reset_vec:
    lui sp, %hi(STACK)
    addi sp, sp, %lo(STACK)
    j start
