#include <stdint.h>
#include <stdlib.h>

#include <iostream>
#include <algorithm>
#include <iomanip>
#include <filesystem>
#include <fstream>
#include <getopt.h>

#include "lodepng.h"
#include "lodepng_util.h"

#include "Palette.hpp"
#include "Tiles.hpp"

#include "DataHeader.hpp"

void save_transcoded_png(Tiles tiles, Palette palette, uint16_t width, uint16_t height, uint8_t bpp);

// input: 16 color paletted PNGs
// output: ics-32 format C headers for tiles and palette

// TODO: optionally input a SNES format file
enum InputFormat { PNG, SNES };

int main(int argc, char **argv)  {
    InputFormat input_format = PNG;

    std::string palette_path;
    uint8_t palette_id = 0;

    if (argc < 2) {
        std::cout << "Usage: (TODO: being modified)" << std::endl;
        return EXIT_SUCCESS;
    }

    int opt;
    char *endptr;

    while ((opt = getopt_long(argc, argv, "f:p:pi:", NULL, NULL)) != -1) {
        switch (opt) {
            case 'f': {
                auto input_format_arg = std::string(optarg);
                std::transform(input_format_arg.begin(), input_format_arg.end(), input_format_arg.begin(), ::tolower);

                if (input_format_arg == "png") {
                    input_format = PNG;
                } else if (input_format_arg == "snes") {
                    input_format = SNES;
                }

            }  break;
            case 'p':
                palette_path = std::string(optarg);
                break;
            case 'i':
                palette_id = strtol(optarg, &endptr, 10);
                break;
        }
    }

    // FIXME: accept whatever input format
    const auto image_path = argv[optind];

    // load and decode input PNG
    
    std::vector<uint8_t> input_data;
    auto error = lodepng::load_file(input_data, image_path);
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

    if (input_format == PNG) {
        error = lodepng::decode(png_decoded, width, height, lode_state, input_data);
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
    } else if (input_format == SNES) {
        width = 128;
        height = (uint)input_data.size() / 32 / 16 * 8;
    }

    // common directory to write output files to

    std::filesystem::path output_path(image_path);
    auto output_directory = output_path.parent_path();

    // --- ics tiles output ---

    // convert from packed index format to a separate byte for each pixel index
    // originally a 4bit indexed PNG will have 2 4bit indexes per byte

    auto load_tiles = [=] () {
        std::vector<uint8_t> indexed_image;

        switch (input_format) {
            case PNG:
                for (uint y = 0; y < height; y++) {
                    for (uint x = 0; x < width; x++) {
                        size_t pixel_index = y * width + (x ^ 0x01);
                        uint palette_index = lodepng::getPaletteValue(&png_decoded[0], pixel_index, lode_state.info_raw.bitdepth);
                        indexed_image.push_back(palette_index);
                    }
                }
                return std::unique_ptr<Tiles>(new Tiles(indexed_image, width, height));
            case SNES:
                return std::unique_ptr<Tiles>(new Tiles(input_data));
        }

        std::cerr << "Error: input format was not handled: " << input_format << std::endl;
        return std::unique_ptr<Tiles>();
    };

    auto tiles = load_tiles();
    if (!tiles) {
        std::cerr << "Error: tile conversion returned no data" << std::endl;
        return EXIT_FAILURE;
    }

    auto output_tiles_path = output_directory;
    output_tiles_path.append("tiles.h");

    std::ofstream output_tiles_stream(output_tiles_path, std::ios::out);
    DataHeader::generate_header(tiles->ics_tiles(), "uint32_t", "tiles", output_tiles_stream);
    output_tiles_stream.close();

    // --- ics palette output ---

    Palette *palette;

    switch (input_format) {
        case PNG: {
            uint32_t *png_palette = reinterpret_cast<uint32_t *>(lode_state.info_png.color.palette);
            size_t palette_size = lode_state.info_png.color.palettesize;
            std::vector<uint32_t> rgba32_palette(png_palette, png_palette + palette_size);
            palette = new Palette(rgba32_palette);
        } break;
        case SNES: {
            // TODO: need to either import a palette somehow or generate one automatically for reference
            std::vector<uint32_t> rgba32_palette;

            // was a palette provided?
            if (!palette_path.empty()) {
                std::ifstream palette_stream(palette_path);
                if (palette_stream.fail()) {
                    std::cerr << "Error: failed to open palette file" << std::endl;
                    return EXIT_FAILURE;
                }

                auto palette = std::vector<uint8_t>(std::istreambuf_iterator<char>(palette_stream), {});
                palette_stream.close();

                auto palette_size = palette.size();
                if (palette_size % 3) {
                    std::cerr << "Warning: expected palette to byte 3 bytes per color" << std::endl;
                    palette_size -= palette_size % 3;
                }

                // (eventually 256 color support needed)
                const auto palette_size_4bpp = 16;
                const auto palette_base = palette_id * palette_size_4bpp;

                for (auto i = 0; i < palette_size_4bpp; i++) {
                    size_t index = (palette_base + i) * 3;
                    uint8_t r = palette[index];
                    uint8_t g = palette[index + 1];
                    uint8_t b = palette[index + 2];
                    uint32_t color = 0xff << 24 | r | g << 8 | b << 16;

                    rgba32_palette.push_back(color);
                }
            } else {
                // ...if not, generate a simple monochrome one
                for (auto i = 0; i < 16 * 16; i++) {
                    uint8_t component = i << 4;
                    uint32_t color = component | component << 8 | component << 16;
                    color |= 0xff << 24;
                    rgba32_palette.push_back(color);
                }
            }

            palette = new Palette(rgba32_palette);
        } break;
    }


    auto output_palette_path = output_directory;
    output_palette_path.append("palette.h");
    std::ofstream output_palette_stream(output_palette_path, std::ios::out);
    DataHeader::generate_header(palette->ics_palette(), "uint16_t", "palette", output_palette_stream);
    output_palette_stream.close();

    save_transcoded_png(*tiles, *palette, width, height, 4);

    delete palette;

    return EXIT_SUCCESS;
}

void save_transcoded_png(Tiles tiles, Palette palette, uint16_t width, uint16_t height, uint8_t bpp) {
    // 4bpp tiles only for now
    auto packed_4bpp_tiles = tiles.packed_4bpp_tiles();

    lodepng::State save_state;

    save_state.info_png.color.colortype = LCT_PALETTE;
    save_state.info_png.color.bitdepth = bpp;
    save_state.info_raw.colortype = LCT_PALETTE;
    save_state.info_raw.bitdepth = bpp;

    save_state.encoder.auto_convert = 0;

    for(int i = 0; i < 16; i++) {
        uint32_t color = palette.rgba32_palette[i];
        uint8_t r = color & 0xff;
        uint8_t g = color >> 8 & 0xff;
        uint8_t b =  color >> 16 & 0xff;
        uint8_t a = color >> 24 & 0xff;

        lodepng_palette_add(&save_state.info_png.color, r, g, b, a);
        lodepng_palette_add(&save_state.info_raw, r, g, b, a);
    }

    std::vector<unsigned char> buffer;
    auto error = lodepng::encode(buffer, &packed_4bpp_tiles[0], width, height, save_state);
    if (error) {
      std::cerr << "encoder error " << error << ": "<< lodepng_error_text(error) << std::endl;
      return;
    }

    lodepng::save_file(buffer, "test.png");
}
