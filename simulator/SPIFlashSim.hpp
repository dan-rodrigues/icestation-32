// SPIFlashSim.hpp
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

// This is a minimal SPI/DSPI and eventually QSPI flash model

// Only read commands 0x03 and 0xbb are supported for now
// Eventually the status read/write and QSPI reads along with QPI mode will be added
// "XIP" or "CRM" config bits are currently ignored, to be added later

// Modelled after the W25Q128JV-DTR
// https://www.winbond.com/resource-files/w25q128jv_dtr%20revc%2003272018%20plus.pdf

#ifndef SPIFlashSim_hpp
#define SPIFlashSim_hpp

#include <stdint.h>
#include <vector>
#include <set>

class SPIFlashSim {

public:
    /// Initializes the flash model with a given maximum size.
    SPIFlashSim(size_t max_size = 0x1000000) : max_size(max_size) {};

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

private:
    struct Range {
        Range(size_t offset, size_t length) : offset(offset), length(length) {}
        size_t offset, length;

        bool operator < (const Range &other) const;
        bool contains(size_t index) const;
    };

    enum class CMD: uint8_t {
        UNDEFINED = 0x00,
        READ_DATA = 0x03, FAST_READ_DUAL = 0xbb,
        WRITE_ENABLE_VOLATILE = 0x50,
        READ_STATUS_REG_2 = 0x35,
        WRITE_STATUS_REG_2 = 0x31
        // ...
    };

    enum class IOState {
        CMD,
        ADDRESS,
        XIP_CMD,
        DUMMY,
        DATA,
        REG_READ,
        REG_WRITE
        // OFF ...
    };

    enum class IOMode {
        SPI,
        DSPI
        // QSPI ...
    };

    bool csn = true, clk = false;

    size_t max_size;
    std::vector<uint8_t> data;
    std::set<Range> defined_ranges;

    IOState state = IOState::CMD;
    IOMode io_mode = IOMode::SPI;
    uint8_t io;

    CMD cmd = CMD::UNDEFINED;
    CMD cmd_from_op(uint8_t cmd_op);

    uint8_t buffer = 0;
    uint8_t bit_count = 0;
    uint8_t byte_count = 0;
    uint32_t read_index = 0;
    bool clk_on_deactivate = false;
    bool activated_previously = false;

    uint8_t posedge_tick(uint8_t io);
    uint8_t negedge_tick(uint8_t io);
    void read_bits(uint8_t io);
    void read_bits(uint8_t io, uint8_t count);
    void handle_new_cmd(uint8_t new_cmd);

    bool status_volatile_write_enable = false;
    uint8_t status_1, status_2, status_3;
    void write_status_reg();

    uint8_t output_en = 0;
    uint8_t send_byte = 0;
    uint8_t send_bits();
    uint8_t send_bits(uint8_t count);

    bool index_is_defined(size_t index);

    IOState state_after_address();
    void transition_io_state(IOState new_state);

    void log(const std::string &message) const ;

    std::string format_hex(uint8_t integer) const ;
    std::string format_hex(uint32_t integer, uint32_t chars) const ;
    template<typename T> std::string format_hex(T integer) const ;
};
#endif /* SPIFlashSim_hpp */
