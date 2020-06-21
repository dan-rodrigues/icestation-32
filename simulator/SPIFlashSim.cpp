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
#include <map>

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
            log_error("/CS deasserted before transferring a complete byte");
        }
    } else if (should_activate) {
        state = (crm_enabled ? IOState::ADDRESS : IOState::CMD);

        if (!crm_enabled) {
            cmd = CMD::UNDEFINED;
            io_mode = IOMode::SPI;
        }

        read_index = 0;
        buffer = 0;
        byte_count = 0;
        // this may need to be kept for CRM

        bit_count = 0;
        output_en = 0;

        if (activated_previously && clk_on_deactivate != clk) {
            log_error("Activated clock state doesn't match previous deactivation state");
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
        log_error("IO conflict (" + format_hex(conflict_mask, 1) + ")");
    }

    return conflict_mask;
}

// (this will be extended if DDR reads are added, where DATA state must work on posedge too)
uint8_t SPIFlashSim::negedge_tick(uint8_t io) {
    switch (state) {
        case IOState::DATA:
            if (bit_count == 0) {
                if (!index_is_defined(read_index)) {
                    log_error("Read index undefined (index: " + format_hex(read_index, 6) + ")");
                    send_byte = 0x00;
                } else {
                    log_info("...sent byte: " + format_hex(data[read_index - 1]));
                    send_byte = data[read_index++];
                }
            }
            return send_bits();
        case IOState::REG_READ:
            return send_bits();
        default:
            return 0;
    }
}

SPIFlashSim::CMD SPIFlashSim::cmd_from_op(uint8_t cmd_op) {
    static const std::set<CMD> supported_cmds = {
        CMD::READ_DATA, CMD::FAST_READ_DUAL, CMD::FAST_READ_QUAD,
        CMD::WRITE_ENABLE_VOLATILE,
        CMD::READ_STATUS_REG_2, CMD::WRITE_STATUS_REG_2
    };

    static const std::map<uint8_t, SPIFlashSim::CMD> cmd_op_map = []() {
        std::map<uint8_t, SPIFlashSim::CMD> map;
        for (auto cmd : supported_cmds) {
            uint8_t cmd_op = static_cast<uint8_t>(cmd);
            map.emplace(cmd_op, cmd);
        }

        return map;
    }();


    auto cmd = cmd_op_map.find(cmd_op);
    if (cmd != cmd_op_map.end()) {
        return cmd->second;
    } else {
        return CMD::UNDEFINED;
    }
}

void SPIFlashSim::handle_new_cmd(uint8_t new_cmd_op) {
    // (nicer formatting, proper op names)
    log_info("CMD received: " + format_hex(new_cmd_op));

    cmd = cmd_from_op(new_cmd_op);
    switch (cmd) {
        case CMD::READ_DATA:
            io_mode = IOMode::SPI;
            transition_io_state(IOState::ADDRESS);
            break;
        case CMD::FAST_READ_DUAL:
            io_mode = IOMode::DSPI;
            transition_io_state(IOState::ADDRESS);
            break;
        case CMD::FAST_READ_QUAD:
            io_mode = IOMode::QSPI;
            transition_io_state(IOState::ADDRESS);
            break;
        case CMD::WRITE_ENABLE_VOLATILE:
            log_info("Volatile write-enable bit set...");
            status_volatile_write_enable = true;
            break;
        case CMD::READ_STATUS_REG_2:
            io_mode = IOMode::SPI;
            transition_io_state(IOState::REG_READ);
            // TODO: actual representation of reg
            send_byte = 0xfd; // 0x58;
            log_info("SR2 byte to read: " + format_hex(send_byte));

            break;
        case CMD::WRITE_STATUS_REG_2:
            if (status_volatile_write_enable) {
                io_mode = IOMode::SPI;
                transition_io_state(IOState::REG_WRITE);
            } else {
                log_error("Ignoring attempt to write SR2 without write-enabling first");
            }
            break;
        default:
            log_error("Unrecognized command (" + format_hex(new_cmd_op) + ")");
            io_mode = IOMode::SPI;
            transition_io_state(IOState::CMD);
            break;
    }
}

// (QPI mode has configurable latency..)
uint8_t SPIFlashSim::dummy_cycles_for_cmd() {
    switch (cmd) {
        case CMD::READ_DATA:
            return 0;
        case CMD::FAST_READ_DUAL:
            return 0;
        case CMD::FAST_READ_QUAD:
            return 4;
        default:
            assert(false);
            return 0;
    }
}

uint8_t SPIFlashSim::posedge_tick(uint8_t io) {
    switch (state) {
        case IOState::CMD:
            // (QPI mode: 4 bits to be read at a time)
            read_bits(io, 1);

            if (byte_count == 1) {
                handle_new_cmd(buffer);
            }
            break;
        case IOState::ADDRESS:
            read_bits(io);

            if (bit_count == 0) {
                read_index <<= 8;
                read_index |= buffer;
            }

            if (byte_count == 3) {
                log_info("Address set to: " + format_hex(read_index));

                transition_io_state(state_after_address());
            }
            break;
        case IOState::XIP_CMD:
            read_bits(io);
            if (byte_count == 1) {
                const uint8_t crm_mask = 0x30;
                const uint8_t crm_byte = 0x20;
                bool new_crm_state = (buffer & crm_mask) == crm_byte;

                if (crm_enabled && !new_crm_state) {
                    log_info("CRM disabled");
                } else if (!crm_enabled && new_crm_state) {
                    log_info("CRM enabled for command: " + format_hex(static_cast<uint8_t>(cmd)));
                } else if (new_crm_state) {
                    log_info("...CRM still enabled...");
                }

                crm_enabled = new_crm_state;

                uint8_t cmd_dummy_cycles = dummy_cycles_for_cmd();
                transition_io_state(cmd_dummy_cycles ? IOState::DUMMY : IOState::DATA);
                dummy_cycles = cmd_dummy_cycles;
            }
            break;
        case IOState::DUMMY:
            dummy_cycles--;
            if (!dummy_cycles) {
                transition_io_state(IOState::DATA);
            }
            break;
        case IOState::REG_WRITE:
            read_bits(io);
            if (byte_count == 1) {
                write_status_reg();
            }
            break;
        default:
            break;
    }

    return 0;
}

void SPIFlashSim::write_status_reg() {
    status_volatile_write_enable = false;

    switch (cmd) {
        case CMD::WRITE_STATUS_REG_2:
            // (reject attempts to set the QE bit if already in QPI mode)
            // (optional info log upon enabling quad io)
            log_info("SR2 updated to: " + format_hex(buffer));

            status_2 = buffer;
            break;
        default:
            assert(false);
            break;
    }
}

void SPIFlashSim::transition_io_state(SPIFlashSim::IOState new_state) {
    byte_count = 0;
    state = new_state;
}

SPIFlashSim::IOState SPIFlashSim::state_after_address() {
    switch (cmd) {
        case CMD::READ_DATA:
            return IOState::DATA;
        case CMD::FAST_READ_DUAL:
            return IOState::XIP_CMD;
        case CMD::FAST_READ_QUAD: // !
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
        case IOMode::QSPI:
            return send_bits(4);
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
        case IOMode::QSPI:
            read_bits(io, 4);
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

void SPIFlashSim::log_info(const std::string &message) const {
    if (enable_info_logging) {
        std::cout << "SPIFlashSim: " << message << std::endl;
    }
}

void SPIFlashSim::log_error(const std::string &message) const {
    if (enable_error_logging) {
        std::cerr << "SPIFlashSim error: " << message << std::endl;
    }
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
