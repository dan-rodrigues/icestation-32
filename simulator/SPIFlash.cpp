#include "SPIFlash.hpp"

#include <cassert>

// minimal at start:

// assume power up
// assume SPI only

void SPIFlash::load(std::vector<uint8_t> source, size_t offset) {
    const size_t flash_size = 0x1000000;
    assert(source.size() + offset < flash_size);

    data.resize(flash_size);

    // not so efficient assuming vector allocates this up front


    std::copy(source.begin() , source.end(), &data[offset]);
}

uint8_t SPIFlash::update(bool csn, bool clk, uint8_t io) {
    bool csn_prev = this->csn;
    bool clk_prev = this->clk;

    bool should_deactivate = csn && !csn_prev;
    bool should_activate = !csn && csn_prev;

    if (should_deactivate) {
        // this is duping the init declaration, could reuse in a common function
        // that is also called in init
        io = 0;
        bit_count = 0;
    } else if (should_activate) {
        state = State::CMD;
        read_index = 0;
        buffer = 0;
        // ...
    }

    bool clk_rose = clk && !clk_prev;
    if (!csn && clk_rose) {
        clk_tick(io);
    }

    // ...

    this->csn = csn;
    this->clk = clk;

    return 0;
}

void SPIFlash::clk_tick(uint8_t io) {
    switch (state) {
        case State::CMD:
            read_bits(io, 1);

            if (byte_count == 1) {
                // common transition conditions?
                byte_count = 0;
                state = State::ADDRESS;
            }
            break;
        case State::ADDRESS:
            read_bits(io, 1);

            if (bit_count == 0) {
                // FIXME: confirm address order
                read_index <<= 8;
                read_index |= buffer;
            }

            if (byte_count == 3) {
                byte_count = 0;
                state = State::XIP_CMD;
            }
            break;
        case State::XIP_CMD:
            // catch M5-4 only
            break;
        case State::DUMMY:
            // configurable wait time
            break;
        case State::DATA:
            // start returning bytes
            break;
    }
}

void SPIFlash::read_bits(uint8_t io, uint8_t count) {
    // SPI only for now
    assert(count == 1);

    buffer <<= 1;
    buffer |= io & 1;

    bit_count += count;

    // shouldn't expect byte crossing?
    if (bit_count >= 8) {
        bit_count -= 8;
        byte_count++;
    }
}
