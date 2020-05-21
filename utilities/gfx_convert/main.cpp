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

// PNG functions, relocate accordingly
void save_png(std::string path, uint width, uint height, std::vector<uint32_t> palette, std::vector<uint8_t> image);


int main(int argc, const char * argv[]) {
    if (argc < 3) {
        std::cout << "Usage: gfx-convert <filename> <output>" << std::endl;
        return EXIT_SUCCESS;
    }

    const auto filename = argv[1];
    const auto output_filename = argv[2];

    // lodepng test:
    
    std::vector<uint8_t> buffer;
    auto error = lodepng::load_file(buffer, filename);
    if (error) {
        std::cerr << "Failed to load file: " << lodepng_error_text(error) << std::endl;
        return EXIT_FAILURE;
    }

    uint width, height;
    std::vector<uint8_t> decoded;
    lodepng::State state;

    state.decoder.color_convert = 0;

    error = lodepng::decode(decoded, width, height, state, buffer);
    if (error) {
        std::cerr << "Failed to decode png: " << lodepng_error_text(error) << std::endl;
        return EXIT_FAILURE;
    }

    if (state.info_png.color.colortype == LCT_PALETTE) {
        std::cout << "found paletted image" << std::endl;
        std::cout << "palette size: " << state.info_raw.palettesize << std::endl;
    } else {
        std::cerr << "non-color-indexed PNG files not supported for now" << std::endl;
        return EXIT_FAILURE;
    }

    // output palette

    auto palette = Palette(state);

    save_png(output_filename, width, height, palette.colors, decoded);

    std::filesystem::path output_path(output_filename);
    auto output_directory = output_path.parent_path();

    // ics tiles binary

    // preprocess tiles to sane index format first, without lodepng
    std::vector<uint8_t> indexed_image;

    for (uint y = 0; y < height; y++) {
        for (uint x = 0; x < width; x++) {
            size_t pixel_index = y * width + x;
            uint palette_index = lodepng::getPaletteValue(&decoded[0], pixel_index, state.info_raw.bitdepth);
            indexed_image.push_back(palette_index);
        }
    }

    auto tiles = Tiles(indexed_image, width, height);
    auto output_tiles_path = output_directory;
    output_tiles_path.append("tiles.h");

    std::ofstream output_tiles_stream(output_tiles_path, std::ios::out);
    DataHeader::generate_header(tiles.ics_tiles(), "uint32_t", "tiles", output_tiles_stream);

    // ics palette binary

    auto output_palette_path = output_directory;
    output_palette_path.append("palette.h");
    std::ofstream output_palette_stream(output_palette_path, std::ios::out);
    DataHeader::generate_header(palette.ics_palette(), "uint16_t", "palette", output_palette_stream);

    return EXIT_SUCCESS;
}

void save_png(std::string path, uint width, uint height, std::vector<uint32_t> palette, std::vector<uint8_t> image) {
    // TEST: try encoding and saving the PNG

    lodepng::State saved_state;

    for (auto it = begin(palette); it != end(palette); ++it) {
        uint32_t color = *it;
        uint8_t a = color >> 24 & 0xff;
        uint8_t b = color >> 16 & 0xff;
        uint8_t g = color >> 8 & 0xff;
        uint8_t r = color & 0xff;

        // determine if one  of these can be removed, review why these are there in the first place
        lodepng_palette_add(&saved_state.info_png.color, r, g, b, a);
        lodepng_palette_add(&saved_state.info_raw, r, g, b, a);
    }

    //both the raw image and the encoded image must get colorType 3 (palette)
    saved_state.info_png.color.colortype = LCT_PALETTE; //if you comment this line, and create the above palette in info_raw instead, then you get the same image in a RGBA PNG.

    // GIMP put this back up to 8bpp, mind the colors in index table
    saved_state.info_png.color.bitdepth = 4;
    saved_state.info_raw.colortype = LCT_PALETTE;
    saved_state.info_raw.bitdepth = 4;
    saved_state.encoder.auto_convert = 4; //we specify ourselves exactly what output PNG color mode we want

    std::vector<uint8_t> save_buffer;
    uint error = lodepng::encode(save_buffer, image.empty() ? 0 : &image[0], width, height, saved_state);
    if (error) {
        std::cerr << "encoder error " << error << ": "<< lodepng_error_text(error) << std::endl;
        return;
    }

    lodepng::save_file(save_buffer, path);
}
