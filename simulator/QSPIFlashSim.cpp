// QSPIFlashSim.cpp
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#include "QSPIFlashSim.hpp"

#include <cassert>
#include <iostream>
#include <sstream>
#include <iomanip>
#include <map>

void QSPIFlashSim::load(const std::vector<uint8_t> &source, size_t offset) {
    size_t source_end_index = source.size() + offset;
    assert(source_end_index < max_size);
    data.resize(std::max(source_end_index, data.size()));

    defined_ranges.insert(Range(offset, source.size()));

    std::copy(source.begin(), source.end(), data.begin() + offset);
}

uint8_t QSPIFlashSim::update(bool csn, bool clk, uint8_t new_io, uint8_t *new_output_en) {
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
            io_mode = (cmd_mode == CMDMode::QPI ? IOMode::QUAD : IOMode::SINGLE);
        }

        read_index = 0;
        read_buffer = 0;
        byte_count = 0;
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
        posedge_tick(new_io);
    } else if (!csn && clk_fell) {
        negedge_tick(new_io);
    }

    if (new_output_en) {
        *new_output_en = this->output_en;
    }

    return io;
}


bool QSPIFlashSim::check_conflicts(uint8_t input_en) const {
    uint8_t conflict_mask = output_en & input_en;
    if (conflict_mask) {
        log_error("IO conflict (" + format_hex(conflict_mask, 1) + ")");
    }

    return conflict_mask;
}

// (this will be extended if DDR reads are added, where DATA state must work on posedge too)
void QSPIFlashSim::negedge_tick(uint8_t io) {
    switch (state) {
        case IOState::DATA:
            if (bit_count == 0) {
                if (!index_is_defined(read_index)) {
                    send_buffer = 0x00;
                    log_error("Read index undefined (index: " + format_hex(read_index, 6) + ")");
                } else {
                    uint8_t byte_to_send = data[read_index++];
                    send_buffer = byte_to_send;
                    log_info("...sending byte: " + format_hex(byte_to_send));
                }
            }
            send_bits();
            break;
        case IOState::REG_READ:
            if (bit_count == 0) {
                send_buffer = status_for_cmd();
                log_info("...sending register byte: " + format_hex(send_buffer));
            }
            send_bits();
            break;
        default:
            break;
    }
}

QSPIFlashSim::CMD QSPIFlashSim::cmd_from_op(uint8_t cmd_op) {
    static const std::set<CMD> supported_cmds = {
        CMD::READ_DATA, CMD::FAST_READ_DUAL_IO, CMD::FAST_READ_QUAD_IO,
        CMD::WRITE_ENABLE_VOLATILE,
        CMD::READ_STATUS_REG_2, CMD::WRITE_STATUS_REG_2,
        CMD::RELEASE_POWER_DOWN, CMD::POWER_DOWN,
        CMD::ENTER_QPI, CMD::EXIT_QPI
    };

    static const std::map<uint8_t, QSPIFlashSim::CMD> cmd_op_map = []() {
        std::map<uint8_t, QSPIFlashSim::CMD> map;
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

void QSPIFlashSim::handle_new_cmd() {
    uint8_t new_cmd_op = read_buffer;

    cmd = cmd_from_op(new_cmd_op);
    log_info("CMD received: " + format_hex(new_cmd_op) + ": " + cmd_name(cmd));

    if (powered_down && cmd != CMD::RELEASE_POWER_DOWN) {
        log_error("Ignoring CMD as flash is in powered-down state");
        return;
    }

    switch (cmd) {
        case CMD::READ_DATA:
            io_mode = IOMode::SINGLE;
            transition_io_state(IOState::ADDRESS);
            break;
        case CMD::FAST_READ_DUAL_IO:
            io_mode = IOMode::DUAL;
            transition_io_state(IOState::ADDRESS);
            break;
        case CMD::FAST_READ_QUAD_IO:
            if (quad_enabled()) {
                io_mode = IOMode::QUAD;
                transition_io_state(IOState::ADDRESS);
            } else {
                log_error("Ignoring Quad CMD: QE bit must be set first");
                transition_io_state(IOState::IDLE);
            }
            break;
        case CMD::WRITE_ENABLE_VOLATILE:
            log_info("...volatile write-enable bit set...");
            status_volatile_write_enable = true;
            transition_io_state(IOState::IDLE);
            break;
        case CMD::READ_STATUS_REG_2:
            io_mode = IOMode::SINGLE;
            transition_io_state(IOState::REG_READ);
            break;
        case CMD::WRITE_STATUS_REG_2:
            if (status_volatile_write_enable) {
                io_mode = IOMode::SINGLE;
                transition_io_state(IOState::REG_WRITE);
            } else {
                log_error("Ignoring attempt to write SR2 without write-enabling first");
            }
            break;
        case CMD::ENTER_QPI:
            if (cmd_mode != CMDMode::QPI) {
                log_info("Transitioning to QPI mode");
            } else {
                log_info("Attempted to re-enter QPI mode");
            }
            cmd_mode = CMDMode::QPI;
            transition_io_state(IOState::IDLE);
            break;
        case CMD::EXIT_QPI:
            if (cmd_mode != CMDMode::QPI) {
                log_info("Transitioning to SPI mode");
            } else {
                log_info("Attempted to re-enter SPI mode");
            }
            cmd_mode = CMDMode::SPI;
            transition_io_state(IOState::IDLE);
            break;
        case CMD::RELEASE_POWER_DOWN:
            if (powered_down) {
                log_info("Transitioning to powered-up state");
            }
            powered_down = false;
            transition_io_state(IOState::IDLE);
            break;
        case CMD::POWER_DOWN:
            if (!powered_down) {
                log_info("Transitioning to powered-down state");
            }
            powered_down = true;
            transition_io_state(IOState::IDLE);
            break;
        default:
            log_error("Unrecognized command (" + format_hex(new_cmd_op) + ")");
            io_mode = IOMode::SINGLE;
            transition_io_state(IOState::IDLE);
            break;
    }
}

const std::string QSPIFlashSim::cmd_name(CMD cmd) {
    static const std::map<CMD, const std::string> map = {
        {CMD::UNDEFINED, "Undefined (this shouldn't be seen in normal use)"},
        {CMD::READ_DATA, "Read Data"},
        {CMD::FAST_READ_DUAL_IO, "Fast Read Dual I/O"},
        {CMD::FAST_READ_QUAD_IO, "Fast Read Quad I/O"},
        {CMD::WRITE_ENABLE_VOLATILE, "Write Enable (volatile)"},
        {CMD::READ_STATUS_REG_2, "Read Status Register 2"},
        {CMD::WRITE_STATUS_REG_2, "Write Status Register 2"},
        {CMD::RELEASE_POWER_DOWN, "Release Power-Down"},
        {CMD::POWER_DOWN, "Power-Down"},
        {CMD::ENTER_QPI, "Enter QPI"},
        {CMD::EXIT_QPI, "Exit QPI"}
    };
    
    auto name = map.find(cmd);
    if (name != map.end()) {
        return name->second;
    } else {
        assert(false);
        return "Unrecognized CMD";
    }
}

bool QSPIFlashSim::quad_enabled() {
    return status_2 & 0x02;
}

// (QPI mode has configurable latency..)
uint8_t QSPIFlashSim::dummy_cycles_for_cmd() {
    switch (cmd) {
        case CMD::READ_DATA:
            return 0;
        case CMD::FAST_READ_DUAL_IO:
            return 0;
        case CMD::FAST_READ_QUAD_IO:
            return (cmd_mode == CMDMode::QPI ? qpi_extra_dummy_cycles : 4);
        default:
            assert(false);
            return 0;
    }
}

void QSPIFlashSim::posedge_tick(uint8_t io) {
    switch (state) {
        case IOState::CMD:
            read_bits(io, cmd_mode == CMDMode::QPI ? 4 : 1);
            if (byte_count == 1) {
                handle_new_cmd();
            }
            break;
        case IOState::ADDRESS:
            read_bits(io);

            if (bit_count == 0) {
                read_index <<= 8;
                read_index |= read_buffer;
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
                bool new_crm_state = (read_buffer & crm_mask) == crm_byte;

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
                transition_io_state(IOState::IDLE);
            }
            break;
        case IOState::IDLE:
            if (cmd == CMD::POWER_DOWN && powered_down) {
                log_error("Ignoring previous power-down CMD as /CS wasn't deasserted after");
                powered_down = false;
            }
            break;
        default:
            break;
    }
}

uint8_t QSPIFlashSim::status_for_cmd() {
    switch (cmd) {
        case CMD::READ_STATUS_REG_2:
            return status_2;
        default:
            assert(false);
            return 0;
    }
}

void QSPIFlashSim::write_status_reg() {
    status_volatile_write_enable = false;

    switch (cmd) {
        case CMD::WRITE_STATUS_REG_2:
            // (reject attempts to set the QE bit if already in QPI mode)
            // (optional info log upon enabling quad io)
            log_info("SR2 updated to: " + format_hex(read_buffer));

            status_2 = read_buffer;
            break;
        default:
            assert(false);
            break;
    }
}

void QSPIFlashSim::transition_io_state(QSPIFlashSim::IOState new_state) {
    byte_count = 0;
    state = new_state;
}

QSPIFlashSim::IOState QSPIFlashSim::state_after_address() {
    switch (cmd) {
        case CMD::READ_DATA:
            return IOState::DATA;
        case CMD::FAST_READ_DUAL_IO: case CMD::FAST_READ_QUAD_IO:
            return IOState::XIP_CMD;
        default:
            assert(false);
            return IOState::DATA;
    }
}

bool QSPIFlashSim::index_is_defined(size_t index) {
    for (auto range : defined_ranges) {
        if (range.contains(index)) {
            return true;
        }
    }

    return false;
}

uint8_t QSPIFlashSim::bit_count_for_mode() {
    switch (io_mode) {
        case IOMode::SINGLE:
            return 1;
        case IOMode::DUAL:
            return 2;
        case IOMode::QUAD:
            return 4;
        default:
            assert(false);
            return 0;
    }
}

uint8_t QSPIFlashSim::send_bits() {
    return send_bits(bit_count_for_mode());
}

uint8_t QSPIFlashSim::send_bits(uint8_t count) {
    assert(count <= 4);

    uint8_t mask = (1 << count) - 1;
    uint8_t shift = 8 - count;

    // SPI transfer goes out on IO[1], not IO[0]
    uint8_t out_shift = (count == 1 ? 6 : shift);
    uint8_t out_mask = (count == 1 ? 1 << 1 : mask);

    uint8_t out = (send_buffer & (mask << shift)) >> out_shift;
    send_buffer <<= count;
    bit_count += count;

    if (bit_count >= 8) {
        assert(bit_count == 8);
        bit_count = 0;
    }

    output_en = out_mask;
    io = out;

    return out;
}

void QSPIFlashSim::read_bits(uint8_t io) {
    read_bits(io, bit_count_for_mode());
}

void QSPIFlashSim::read_bits(uint8_t io, uint8_t count) {
    assert(count <= 4);

    read_buffer <<= count;
    read_buffer |= io & ((1 << count) - 1);
    bit_count += count;

    if (bit_count >= 8) {
        assert(bit_count == 8);
        bit_count = 0;
        byte_count++;
    }
}

bool QSPIFlashSim::Range::contains(size_t index) const {
    return index >= offset && index < (offset + length);
}

bool QSPIFlashSim::Range::operator < (const Range &other) const {
    return offset < other.offset || length < other.length;
}

void QSPIFlashSim::log_info(const std::string &message) const {
    if (enable_info_logging) {
        std::cout << "QSPIFlashSim: " << message << std::endl;
    }
}

void QSPIFlashSim::log_error(const std::string &message) const {
    if (enable_error_logging) {
        std::cerr << "QSPIFlashSim error: " << message << std::endl;
    }
}

std::string QSPIFlashSim::format_hex(uint8_t integer) const {
    return format_hex(integer, sizeof(uint8_t) * 2);
}

template<typename T> std::string QSPIFlashSim::format_hex(T integer) const {
    return format_hex(integer, sizeof(T) * 2);
}

std::string QSPIFlashSim::format_hex(uint32_t integer, uint32_t chars) const {
    std::stringstream stream;
    stream << std::hex << std::setfill('0') << std::setw(chars) << integer;
    return stream.str();
}
