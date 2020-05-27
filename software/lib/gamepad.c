#include "gamepad.h"

static const volatile uint32_t *PAD_BASE = (uint32_t *)0x400000;

static const uint32_t PAD_LATCH = 1 << 0;
static const uint32_t PAD_CLK = 1 << 1;

#define PAD_IO (*((volatile uint32_t *) PAD_BASE + 0))

uint16_t pad_read_p1() {
    const uint8_t button_count = 16;
    uint16_t inputs = 0;

    // latch current pad inputs
    PAD_IO = PAD_LATCH;
    // (confirm if this happens too fast at full speed CPU)
    PAD_IO = 0;

    for (uint8_t i = 0; i < button_count; i++) {
        // read current input bit
        inputs <<= 1;
        inputs |= PAD_IO & 1;
        // clock in next bit
        PAD_IO = PAD_CLK;
        PAD_IO = 0;
    }

    return inputs;
}
