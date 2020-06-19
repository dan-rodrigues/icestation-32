#ifndef SPIFlash_hpp
#define SPIFlash_hpp

#include <stdint.h>
#include <vector>
#include <set>

class SPIFlash {

    struct Range {
        Range(size_t offset, size_t length) : offset(offset), length(length) {}
        size_t offset, length;

        bool operator < (const Range &other) const;
        bool contains(size_t index) const;
    };

    enum class State { // IOState
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

public:
    void load(const std::vector<uint8_t> &source, size_t offset);
    uint8_t update(bool csn, bool clk, uint8_t io);
private:
    bool csn = true, clk = false;

    std::vector<uint8_t> data;
    std::set<Range> defined_ranges;

    State state = State::CMD;
    IOMode io_mode = IOMode::SPI;
    uint8_t io;
    uint8_t cmd = 0;
    uint8_t buffer = 0;
    uint8_t bit_count = 0;
    uint8_t byte_count = 0;
    uint32_t read_index = 0;

    uint8_t posedge_tick(uint8_t io);
    uint8_t negedge_tick(uint8_t io);
    void read_bits(uint8_t io);
    void read_bits(uint8_t io, uint8_t count);
    void handle_new_cmd(uint8_t new_cmd);

    uint8_t send_byte = 0;
    uint8_t send_bits();
    uint8_t send_bits(uint8_t count);

    bool index_is_defined(size_t index);
};
#endif /* SPIFlash_hpp */
