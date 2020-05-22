#include <stdint.h>

#include <iostream>
#include <iomanip>
#include <filesystem>
#include <fstream>

#include "lodepng.h"
#include "lodepng_util.h"

#include "Palette.hpp"
#include "Tiles.hpp"

#include "DataHeader.hpp"

// input: 16 color paletted PNGs
// output: ics-32 format C headers for tiles and palette

int main(int argc, const char * argv[]) {
    if (argc < 2) {
        std::cout << "Usage: gfx-convert <filename> <output>" << std::endl;
        return EXIT_SUCCESS;
    }

    const auto png_path = argv[1];

    // load and decode input PNG
    
    std::vector<uint8_t> png_data;
    auto error = lodepng::load_file(png_data, png_path);
    if (error) {
        std::cerr << "Failed to load file: " << lodepng_error_text(error) << std::endl;
        return EXIT_FAILURE;
    }

    uint width, height;
    std::vector<uint8_t> png_decoded;
    lodepng::State lode_state;

    // disabling color_convert preserves the original palette indexes, which is all want
    // the actual RGBA colors are dealt with separately as part of palette output

    lode_state.decoder.color_convert = 0;

    error = lodepng::decode(png_decoded, width, height, lode_state, png_data);
    if (error) {
        std::cerr << "Failed to decode png: " << lodepng_error_text(error) << std::endl;
        return EXIT_FAILURE;
    }

    if (lode_state.info_png.color.colortype == LCT_PALETTE) {
        std::cout << "Found paletted image" << std::endl;
        std::cout << "Palette size: " << lode_state.info_raw.palettesize << std::endl;
    } else {
        std::cerr << "non-color-indexed PNG files not supported for now" << std::endl;
        return EXIT_FAILURE;
    }

    // common directory to write output files to

    std::filesystem::path output_path(png_path);
    auto output_directory = output_path.parent_path();

    // --- ics tiles output ---

    // convert from packed index format to a separate byte for each pixel index
    // originally a 4bit indexed PNG will have 2 4bit indexes per byte

    std::vector<uint8_t> indexed_image;
    for (uint y = 0; y < height; y++) {
        for (uint x = 0; x < width; x++) {
            size_t pixel_index = y * width + x;
            uint palette_index = lodepng::getPaletteValue(&png_decoded[0], pixel_index, lode_state.info_raw.bitdepth);
            indexed_image.push_back(palette_index);
        }
    }

    auto tiles = Tiles(indexed_image, width, height);
    auto output_tiles_path = output_directory;
    output_tiles_path.append("tiles.h");

    std::ofstream output_tiles_stream(output_tiles_path, std::ios::out);
    DataHeader::generate_header(tiles.ics_tiles(), "uint32_t", "tiles", output_tiles_stream);
    output_tiles_stream.close();

    // --- ics palette output ---

    uint32_t *png_palette = reinterpret_cast<uint32_t *>(lode_state.info_png.color.palette);
    size_t palette_size = lode_state.info_png.color.palettesize;
    std::vector<uint32_t> rgba32_palette(png_palette, png_palette + palette_size);
    auto palette = Palette(rgba32_palette);

    auto output_palette_path = output_directory;
    output_palette_path.append("palette.h");
    std::ofstream output_palette_stream(output_palette_path, std::ios::out);
    DataHeader::generate_header(palette.ics_palette(), "uint16_t", "palette", output_palette_stream);
    output_palette_stream.close();

    return EXIT_SUCCESS;
}
