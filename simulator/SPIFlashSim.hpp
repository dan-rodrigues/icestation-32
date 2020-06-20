// SPIFlashSim.hpp
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#ifndef SPIFlash_hpp
#define SPIFlash_hpp

#include <stdint.h>
#include <vector>
#include <set>

class SPIFlashSim {

public:
    SPIFlashSim(size_t max_size = 0x1000000) : max_size(max_size) {};

    void load(const std::vector<uint8_t> &source, size_t offset);
    uint8_t update(bool csn, bool clk, uint8_t io, uint8_t *new_output_en = NULL);
    bool check_conflicts(uint8_t host_output_en) const;

private:
    struct Range {
        Range(size_t offset, size_t length) : offset(offset), length(length) {}
        size_t offset, length;

        bool operator < (const Range &other) const;
        bool contains(size_t index) const;
    };

    enum class IOState {
        CMD,
        ADDRESS,
        XIP_CMD,
        DUMMY,
        DATA
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
    uint8_t cmd = 0;
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

    uint8_t send_byte = 0;
    uint8_t send_bits();
    uint8_t send_bits(uint8_t count);
    uint8_t output_en;

    bool index_is_defined(size_t index);

    IOState state_after_address();
    void transition_cmd_state(IOState new_state);

    void log(const std::string &message) const ;

    std::string format_hex(uint8_t integer) const ;
    std::string format_hex(uint32_t integer, uint32_t chars) const ;
    template<typename T> std::string format_hex(T integer) const ;
};
#endif /* SPIFlash_hpp */
