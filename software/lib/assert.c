#include "assert.h"

void assert(bool assertion) {
    // for now we'll just trap the cpu
    // eventually this can upload a font, print some context etc.
    if (!assertion) {
        __asm__("ebreak");
    }
}
