// QSPIFlashSim.hpp
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

// This is a minimal SPI/DSPI and eventually QSPI flash model
// The list of supported commands is defined below in CMD

// Modelled after the W25Q128JV-DTR
// https://www.winbond.com/resource-files/w25q128jv_dtr%20revc%2003272018%20plus.pdf

#ifndef QSPIFlashSim_hpp
#define QSPIFlashSim_hpp

#include <stdint.h>
#include <vector>
#include <set>

class QSPIFlashSim {

public:
    /// Initializes the flash model with a given maximum size.
    QSPIFlashSim(size_t max_size = 0x1000000) : max_size(max_size) {};

    /// Loads the entire contents of source into the given offset in flash memory.
    /// By default, errors are logged on attempts to access flash memory outside of the loaded regions.
    void load(const std::vector<uint8_t> &source, size_t offset);

    /// Updates the state of the model with the given inputs.
    /// Returns the updated state of the IO pins after these updates.
    /// Optionally sets the state of the output enable for the corresponding output bits using new_output_en.
    uint8_t update(bool csn, bool clk, uint8_t io, uint8_t *new_output_en = NULL);

    /// Logs an error if the there is a conflict between the current output and input enables.
    /// Returns true if there was a conflict.
    bool check_conflicts(uint8_t input_en) const;

    /// If true, RELEASE_POWER_DOWN must be sent before using the flash
    bool powered_down = true;

    bool enable_info_logging = false;
    bool enable_error_logging = true;

private:
    struct Range {
        Range(size_t offset, size_t length) : offset(offset), length(length) {}
        size_t offset, length;

        bool operator < (const Range &other) const;
        bool contains(size_t index) const;
    };

    enum class CMD: uint8_t {
        READ_DATA = 0x03, FAST_READ_DUAL_IO = 0xbb, FAST_READ_QUAD_IO = 0xeb,
        WRITE_ENABLE_VOLATILE = 0x50,
        READ_STATUS_REG_2 = 0x35, WRITE_STATUS_REG_2 = 0x31,
        ENTER_QPI = 0x38, EXIT_QPI = 0xff,
        RELEASE_POWER_DOWN = 0xab, POWER_DOWN = 0xb9,
        UNDEFINED = 0x00
    };

    enum class CMDMode {
        SPI, QPI
    };

    enum class IOState {
        CMD, ADDRESS, XIP_CMD, DUMMY, DATA,
        REG_READ, REG_WRITE,
        IDLE
    };

    enum class IOMode {
        SINGLE, DUAL, QUAD
    };

    bool csn = true, clk = false;

    size_t max_size;
    std::vector<uint8_t> data;
    std::set<Range> defined_ranges;

    IOState state = IOState::CMD;
    IOMode io_mode = IOMode::SINGLE;
    CMDMode cmd_mode = CMDMode::SPI;
    uint8_t io;
    uint8_t bit_count_for_mode();

    CMD cmd = CMD::UNDEFINED;
    bool crm_enabled = false;

    CMD cmd_from_op(uint8_t cmd_op);
    uint8_t dummy_cycles_for_cmd();
    void handle_new_cmd();
    const std::string cmd_name(CMD cmd);

    uint8_t read_buffer = 0;
    uint8_t bit_count = 0;
    uint8_t byte_count = 0;
    uint32_t read_index = 0;
    uint8_t dummy_cycles = 0;
    bool clk_on_deactivate = false;
    bool activated_previously = false;

    uint8_t posedge_tick(uint8_t io);
    uint8_t negedge_tick(uint8_t io);
    void read_bits(uint8_t io);
    void read_bits(uint8_t io, uint8_t count);

    uint8_t qpi_extra_dummy_cycles = 0;

    bool status_volatile_write_enable = false;
    uint8_t /*status_1 = 0x00,*/ status_2 = 0x00/*, status_3 = 0x00*/;

    void write_status_reg();
    uint8_t status_for_cmd();
    bool quad_enabled();

    uint8_t output_en = 0;
    uint8_t send_buffer = 0;

    uint8_t send_bits();
    uint8_t send_bits(uint8_t count);

    bool index_is_defined(size_t index);

    IOState state_after_address();
    void transition_io_state(IOState new_state);

    void log_error(const std::string &message) const;
    void log_info(const std::string &message) const;

    std::string format_hex(uint8_t integer) const ;
    std::string format_hex(uint32_t integer, uint32_t chars) const ;
    template<typename T> std::string format_hex(T integer) const ;
};
#endif /* QSPIFlashSim_hpp */
