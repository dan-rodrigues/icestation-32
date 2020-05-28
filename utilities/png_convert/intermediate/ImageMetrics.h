#ifndef ImageMetrics_h
#define ImageMetrics_h

// xcode does not indent namespace apparently

namespace ImageMetrics {

namespace ICS {
const auto TILE_SIZE = 32;
const auto TILE_STRIDE = 16;
const auto TILE_BYTE_STRIDE = TILE_STRIDE * TILE_SIZE;
const auto TILE_ROW_STRIDE = TILE_STRIDE * 8;
}

namespace SNES {
const auto TILE_SIZE = 32;
const auto TILE_STRIDE = 16;
const auto TILE_ROW_STRIDE = TILE_STRIDE * 8;
}

}

#endif /* ImageMetrics_h */
