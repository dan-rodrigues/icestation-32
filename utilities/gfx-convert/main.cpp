// TODO: proper header

#include <stdint.h>

#include <iostream>
#include <iomanip>

#include "lodepng.h"
#include "lodepng_util.h"

// PNG functions, relocate accordingly
void save_png(std::string path, uint width, uint height, std::vector<uint32_t> palette, std::vector<uint8_t> image);


int main(int argc, const char * argv[]) {
    if (argc < 3) {
        std::cout << "usage: gfx-convert <filename> <output>" << std::endl;
        return 1;
    }

    auto const filename = argv[1];
    auto const output_filename = argv[2];

    // lodepng test:

    std::vector<uint8_t> buffer;
    auto error = lodepng::load_file(buffer, filename);
    if (error) {
        std::cout << "failed to load file: " << lodepng_error_text(error) << std::endl;
        return 1;
    }

    uint width, height;
    std::vector<uint8_t> decoded;
    lodepng::State state;

    state.decoder.color_convert = 0;

    error = lodepng::decode(decoded, width, height, state, buffer);
    if (error) {
        std::cout << "failed to decode png: " << lodepng_error_text(error) << std::endl;
        return 1;
    }

    if (state.info_png.color.colortype == LCT_PALETTE) {
        std::cout << "found paletted image" << std::endl;
        std::cout << "palette size: " << state.info_raw.palettesize << std::endl;
    } else {
        std::cout << "non-color-indexed PNG files not supported for now" << std::endl;
        return 1;
    }

    // TEST: try print raw palette indexes
    for (uint y = 0; y < height; y++) {
        for (uint x = 0; x < height; x++) {
            size_t index = y * height + x;
            uint value = lodepng::getPaletteValue(&decoded[0], index, state.info_raw.bitdepth);

            std::cout << "index: " << value << std::endl;
        }
    }

    // TEST: try print the RGB of the palette itself
    uint32_t *palette = reinterpret_cast<uint32_t *>(state.info_png.color.palette);
    size_t palette_size = state.info_png.color.palettesize;
    std::vector<uint32_t> argb_colors(palette, palette + palette_size);

    // TEST: try encoding and saving the PNG
    save_png(output_filename, width, height, argb_colors, decoded);

    return 0;
}

void save_png(std::string path, uint width, uint height, std::vector<uint32_t> palette, std::vector<uint8_t> image) {
    // TEST: try encoding and saving the PNG

    //create encoder and set settings and info (optional)
    lodepng::State saved_state;

    //generate palette
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
    saved_state.info_png.color.bitdepth = 4;
    saved_state.info_raw.colortype = LCT_PALETTE;
    saved_state.info_raw.bitdepth = 4;
    saved_state.encoder.auto_convert = 0; //we specify ourselves exactly what output PNG color mode we want

    //encode and save
    std::vector<uint8_t> save_buffer;
    uint error = lodepng::encode(save_buffer, image.empty() ? 0 : &image[0], width, height, saved_state);
    if (error) {
        std::cout << "encoder error " << error << ": "<< lodepng_error_text(error) << std::endl;
        // error..
        return;
    }

    lodepng::save_file(save_buffer, path);
}
