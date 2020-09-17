#ifndef Map_hpp
#define Map_hpp

#include <stdint.h>
#include <vector>

class Map {

public:
    Map(std::vector<uint8_t> snes_vram) : vram(snes_vram) {};

    std::vector<uint16_t> ics_map();

private:
    std::vector<uint8_t> vram;
};

#endif /* Map_hpp */
