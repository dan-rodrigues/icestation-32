#include "SPIFlash.hpp"

#include <cassert>
#include <iostream>

// minimal at start: assume power up state, assume SPI only etc

void SPIFlash::load(const std::vector<uint8_t> &source, size_t offset) {
    const size_t flash_size = 0x1000000;
    assert(source.size() + offset < flash_size);
    data.resize(flash_size);

    defined_ranges.insert(Range(offset, source.size()));

    std::copy(source.begin(), source.end(), &data[offset]);
}

uint8_t SPIFlash::update(bool csn, bool clk, uint8_t io) {
    bool csn_prev = this->csn;
    bool clk_prev = this->clk;
    this->csn = csn;
    this->clk = clk;

    bool still_deactivated = csn_prev && csn;
    if (still_deactivated) {
        return 0;
    }

    bool should_deactivate = csn && !csn_prev;
    bool should_activate = !csn && csn_prev;
    if (should_deactivate) {
        // ...
    } else if (should_activate) {
        state = State::CMD;
        read_index = 0;
        buffer = 0;
        byte_count = 0;
        cmd = 0; // optional?
        bit_count = 0;
    }

    bool clk_rose = clk && !clk_prev;
    bool clk_fell = !clk && clk_prev;

    uint8_t io_updated = 0;
    if (!csn && clk_rose) {
        io_updated = posedge_tick(io);
    } else if (!csn && clk_fell) {
        io_updated = negedge_tick(io);
    }

    return io_updated;
}

uint8_t SPIFlash::negedge_tick(uint8_t io) {
    switch (state) {
        case State::DATA:
            // (bonus assertion: deassertion of CS before complete byte is read)
            if (bit_count == 0) {
                assert(read_index <= data.size());
                assert(index_is_defined(read_index));
                send_byte = data[read_index++];
            }

            return send_bits(1);
        default:
            break;
    }

    return 0;
}

uint8_t SPIFlash::posedge_tick(uint8_t io) {
    switch (state) {
        case State::CMD:
            read_bits(io, 1);

            if (byte_count == 1) {
                // common transition conditions?
                byte_count = 0;
                state = State::ADDRESS;
                cmd = buffer;

                assert(cmd == 0x03);
            }
            break;
        case State::ADDRESS:
            read_bits(io, 1);

            if (bit_count == 0) {
                read_index <<= 8;
                read_index |= buffer;
            }

            if (byte_count == 3) {
                byte_count = 0;

                state = State::DATA;
//                state = State::XIP_CMD;

                // assume attempts to read the bitstream are not intentional
                const size_t flash_user_base = 0x10000;
                assert(read_index >= flash_user_base);
            }
            break;
        case State::XIP_CMD:
            // (catch M5-4 only)
            read_bits(io, 1);
            if (byte_count == 1) {
                byte_count = 0;
//                state = State::DUMMY;
                state = State::DATA;
            }
            break;
        case State::DUMMY:
            // (configurable wait time)
            read_bits(io, 1);
            if (byte_count == 1) {
                byte_count = 0;
                state = State::DATA;
            }
            break;
        default:
            break;
    }

    return 0;
}

bool SPIFlash::index_is_defined(size_t index) {
    for (auto range : defined_ranges) {
        if (range.contains(index)) {
            return true;
        }
    }

    return false;
}

uint8_t SPIFlash::send_bits(uint8_t count) {
    // SPI only for now
    assert(count == 1);

    uint8_t out = (send_byte & 0x80) >> 7;
    send_byte <<= 1;
    bit_count++;

    if (bit_count >= 8) {
        bit_count -= 8;
    }

    return out;
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

bool SPIFlash::Range::contains(size_t index) const {
    return index >= offset && index < (offset + length);
}

bool SPIFlash::Range::operator < (const Range &other) const {
    return offset < other.offset || length < other.length;
}
