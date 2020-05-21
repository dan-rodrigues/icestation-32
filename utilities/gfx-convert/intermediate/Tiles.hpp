//
//  Tiles.hpp
//  ics32-utilities
//
//  Created by Dan Rodrigues on 19/5/20.
//  Copyright © 2020 drr. All rights reserved.
//

#ifndef Tiles_hpp
#define Tiles_hpp

#include <stdint.h>
#include <vector>

#include "lodepng.h"

class Tiles {

public:
    Tiles(std::vector<uint8_t> image, uint16_t width, uint16_t height);

    std::vector<uint32_t> ics_tiles();

    std::vector<uint8_t> image;
    uint16_t width;
    uint16_t height;
};

#endif /* Tiles_hpp */
