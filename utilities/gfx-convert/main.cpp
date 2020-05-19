// TODO: proper header

#include <stdint.h>

#include <iostream>
#include <iomanip>

#include "lodepng.h"
#include "lodepng_util.h"

int main(int argc, const char * argv[]) {
    if (argc < 2) {
        std::cout << "usage: gfx-convert <filename>" << std::endl;
        return 1;
    }

    auto const filename = argv[1];

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
    uint8_t *palette = state.info_png.color.palette;

    // from the samples: ARGB32 hec?
    std::ios_base::fmtflags flags = std::cout.flags();
    std::cout << std::hex << std::setfill('0');
    for (uint i = 0; i < state.info_png.color.palettesize; i++) {
        unsigned char* p = &state.info_png.color.palette[i * 4];
        std::cout << "#" << std::setw(2) << (int)p[0] << std::setw(2) << (int)p[1] << std::setw(2) << (int)p[2] << std::setw(2) << (int)p[3] << " ";
//        std::cout << palette[i];
    }


    unsigned char* image = 0;
    unsigned char* png = 0;
    size_t pngsize;

    error = lodepng_load_file(&png, &pngsize, filename);
    if(!error) error = lodepng_decode32(&image, &width, &height, png, pngsize);
    if(error) printf("error %u: %s\n", error, lodepng_error_text(error));

    free(png);

    /*use image here*/

    free(image);

    return 0;
}
