// SPIFlashSim.cpp
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#include "SPIFlashSim.hpp"

#include <cassert>
#include <iostream>
#include <sstream>
#include <iomanip>

void SPIFlashSim::load(const std::vector<uint8_t> &source, size_t offset) {
    size_t source_end_index = source.size() + offset;
    assert(source_end_index < max_size);
    data.resize(std::max(source_end_index, data.size()));

    defined_ranges.insert(Range(offset, source.size()));

    std::copy(source.begin(), source.end(), data.begin() + offset);
}

uint8_t SPIFlashSim::update(bool csn, bool clk, uint8_t new_io, uint8_t *new_output_en) {
    bool csn_prev = this->csn;
    this->csn = csn;

    bool still_deactivated = csn_prev && csn;
    if (still_deactivated) {
        return 0;
    }

    bool clk_prev = this->clk;
    this->clk = clk;

    bool should_deactivate = csn && !csn_prev;
    bool should_activate = !csn && csn_prev;
    if (should_deactivate) {
        output_en = 0;
        clk_on_deactivate = clk;

        if (bit_count != 0) {
            log("/CS deasserted before transferring a complete byte");
        }
    } else if (should_activate) {
        state = IOState::CMD;
        io_mode = IOMode::SPI;
        read_index = 0;
        buffer = 0;
        byte_count = 0;
        cmd = 0;
        bit_count = 0;
        output_en = 0;

        if (activated_previously && clk_on_deactivate != clk) {
            log("Activated clock state doesn't match previous deactivation state");
        }

        activated_previously = true;
    }

    bool clk_rose = clk && !clk_prev;
    bool clk_fell = !clk && clk_prev;
    if (!csn && clk_rose) {
        io = posedge_tick(new_io);
    } else if (!csn && clk_fell) {
        io = negedge_tick(new_io);
    }

    if (new_output_en) {
        *new_output_en = this->output_en;
    }

    return io;
}


bool SPIFlashSim::check_conflicts(uint8_t input_en) const {
    uint8_t conflict_mask = output_en & input_en;
    if (conflict_mask) {
        log("IO conflict (" + format_hex(conflict_mask, 1) + ")");
    }

    return conflict_mask;
}

// (this will be extended if DDR reads are added, where DATA state must work on posedge too)
uint8_t SPIFlashSim::negedge_tick(uint8_t io) {
    switch (state) {
        case IOState::DATA:
            if (bit_count == 0) {
                if (!index_is_defined(read_index)) {
                    log("read index undefined (index: " + format_hex(read_index, 6) + ")");
                    send_byte = 0x00;
                } else {
                    send_byte = data[read_index++];
                }
            }
            return send_bits();
        default:
            return 0;
    }
}

void SPIFlashSim::handle_new_cmd(uint8_t new_cmd) {
    switch (new_cmd) {
        case 0x03:
            io_mode = IOMode::SPI;
            break;
        case 0xbb:
            io_mode = IOMode::DSPI;
            break;
        default:
            log("unrecognized command (" + format_hex(new_cmd) + ")");
            io_mode = IOMode::SPI;
            state = IOState::CMD;
            break;
    }

    cmd = new_cmd;
}

uint8_t SPIFlashSim::posedge_tick(uint8_t io) {
    switch (state) {
        case IOState::CMD:
            read_bits(io, 1);

            if (byte_count == 1) {
                handle_new_cmd(buffer);
                transition_cmd_state(IOState::ADDRESS);
            }
            break;
        case IOState::ADDRESS:
            read_bits(io);

            if (bit_count == 0) {
                read_index <<= 8;
                read_index |= buffer;
            }

            if (byte_count == 3) {
                transition_cmd_state(state_after_address());
            }
            break;
        case IOState::XIP_CMD:
            // (catch M5-4 only)
            read_bits(io);
            if (byte_count == 1) {
                // depends on command and whether (eventually) we're in QPI mode
                transition_cmd_state(IOState::DATA);
            }
            break;
        case IOState::DUMMY:
            // (configurable wait time...)
            read_bits(io);
            if (byte_count == 1) {
                transition_cmd_state(IOState::DATA);
            }
            break;
        default:
            break;
    }

    return 0;
}

void SPIFlashSim::transition_cmd_state(SPIFlashSim::IOState new_state) {
    byte_count = 0;
    state = new_state;
}

SPIFlashSim::IOState SPIFlashSim::state_after_address() {
    switch (cmd) {
        case 0x03:
            return IOState::DATA;
        case 0xbb:
            return IOState::XIP_CMD;
        default:
            assert(false);
            return IOState::DATA;
    }
}

bool SPIFlashSim::index_is_defined(size_t index) {
    for (auto range : defined_ranges) {
        if (range.contains(index)) {
            return true;
        }
    }

    return false;
}

uint8_t SPIFlashSim::send_bits() {
    switch (io_mode) {
        case IOMode::SPI:
            return send_bits(1);
        case IOMode::DSPI:
            return send_bits(2);
        default:
            assert(false);
            return 0;
    }
}

uint8_t SPIFlashSim::send_bits(uint8_t count) {
    assert(count <= 4);

    uint8_t mask = (1 << count) - 1;
    uint8_t shift = 8 - count;

    // SPI transfer goes out on IO[1], not IO[0]
    uint8_t out_shift = (count == 1 ? 6 : shift);
    uint8_t out_mask = (count == 1 ? 1 << 1 : mask);

    uint8_t out = (send_byte & (mask << shift)) >> out_shift;
    send_byte <<= count;
    bit_count += count;

    if (bit_count >= 8) {
        assert(bit_count == 8);
        bit_count = 0;
    }

    output_en = out_mask;

    return out;
}

void SPIFlashSim::read_bits(uint8_t io) {
    switch (io_mode) {
        case IOMode::SPI:
            read_bits(io, 1);
            break;
        case IOMode::DSPI:
            read_bits(io, 2);
            break;
        default:
            assert(false);
    }
}

void SPIFlashSim::read_bits(uint8_t io, uint8_t count) {
    assert(count <= 4);

    buffer <<= count;
    buffer |= io & ((1 << count) - 1);
    bit_count += count;

    if (bit_count >= 8) {
        assert(bit_count == 8);
        bit_count = 0;
        byte_count++;
    }
}

bool SPIFlashSim::Range::contains(size_t index) const {
    return index >= offset && index < (offset + length);
}

bool SPIFlashSim::Range::operator < (const Range &other) const {
    return offset < other.offset || length < other.length;
}

void SPIFlashSim::log(const std::string &message) const {
    std::cerr << "SPI Flash: " << message << std::endl;
}

std::string SPIFlashSim::format_hex(uint8_t integer) const {
    return format_hex(integer, sizeof(uint8_t) * 2);
}

template<typename T> std::string SPIFlashSim::format_hex(T integer) const {
    return format_hex(integer, sizeof(T) * 2);
}

std::string SPIFlashSim::format_hex(uint32_t integer, uint32_t chars) const {
    std::stringstream stream;
    stream << std::hex << std::setfill('0') << std::setw(chars) << integer;
    return stream.str();
}
