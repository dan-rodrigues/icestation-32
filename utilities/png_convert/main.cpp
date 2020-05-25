#include <stdint.h>
#include <stdlib.h>

#include <optional>
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
#include "Image.hpp"

#include "DataHeader.hpp"

void save_transcoded_png(Image image);

int main(int argc, char **argv)  {
    InputFormat input_format = PNG;

    std::string palette_path;
    std::optional<uint8_t> palette_id = std::nullopt;

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
                } else {
                    std::cerr << "Error: unrecognized input format: " << input_format_arg << std::endl;
                    return EXIT_FAILURE;
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

    const auto image_path = argv[optind];

    // load input data
    
    std::vector<uint8_t> input_data;
    auto error = lodepng::load_file(input_data, image_path);
    if (error) {
        std::cerr << "Failed to load file: " << lodepng_error_text(error) << std::endl;
        return EXIT_FAILURE;
    }

    // was a custom palette provided?

    std::vector<uint8_t> palette_data;
    if (!palette_path.empty()) {
        std::fstream palette_stream(palette_path);
        if (palette_stream.fail()) {
            std::cerr << "Error: failed to open palette file" << std::endl;
            return EXIT_FAILURE;
        }

        // was only a single palette within the entire set requested?
        if (palette_id.has_value()) {
            // read only the 16 colors of interest
            const auto rgb24_palette_size = 16 * 3;
            palette_data.resize(rgb24_palette_size);
            auto palette_file_base = palette_id.value() * rgb24_palette_size;
            palette_stream.seekg(palette_file_base);
            palette_stream.read(reinterpret_cast<char *>(&palette_data[0]), rgb24_palette_size);
        } else {
            // read the entire palette
            palette_data = std::vector<uint8_t>(std::istreambuf_iterator<char>(palette_stream), {});
        }

        palette_stream.close();
    } else if (palette_id.has_value()) {
        std::cout << "Custom palette ID specified but no palette was provided" << std::endl;
    }

    Image image;
    try {
        image = Image(input_data, palette_data, input_format);
    } catch (std::invalid_argument e) {
        std::cerr << "Failed to convert tiles and palette to image: " << e.what() << std::endl;
        return EXIT_FAILURE;
    }

    // tiles header creation

    std::filesystem::path output_path(image_path);
    auto output_directory = output_path.parent_path();

    auto output_tiles_path = output_directory;
    output_tiles_path.append("tiles.h");
    std::ofstream output_tiles_stream(output_tiles_path, std::ios::out);
    DataHeader::generate_header(image.tiles.ics_tiles(), "uint32_t", "tiles", output_tiles_stream);
    output_tiles_stream.close();

    // palette header creation

    auto output_palette_path = output_directory;
    output_palette_path.append("palette.h");
    std::ofstream output_palette_stream(output_palette_path, std::ios::out);
    DataHeader::generate_header(image.palette.ics_palette(), "uint16_t", "palette", output_palette_stream);
    output_palette_stream.close();

    // output test PNG to quickly verify results

    save_transcoded_png(image);

    return EXIT_SUCCESS;
}

void save_transcoded_png(Image image) {
    auto packed_4bpp_tiles = image.tiles.packed_4bpp_tiles();

    lodepng::State save_state;

    save_state.info_png.color.colortype = LCT_PALETTE;
    save_state.info_png.color.bitdepth = image.bpp;
    save_state.info_raw.colortype = LCT_PALETTE;
    save_state.info_raw.bitdepth = image.bpp;

    save_state.encoder.auto_convert = 0;

    for (auto i = 0; i < 16; i++) {
        uint32_t color = image.palette.rgba32_palette[i];
        uint8_t r = color & 0xff;
        uint8_t g = color >> 8 & 0xff;
        uint8_t b =  color >> 16 & 0xff;
        uint8_t a = color >> 24 & 0xff;

        lodepng_palette_add(&save_state.info_png.color, r, g, b, a);
        lodepng_palette_add(&save_state.info_raw, r, g, b, a);
    }

    std::vector<uint8_t> buffer;
    auto error = lodepng::encode(buffer, &packed_4bpp_tiles[0], image.tiles.width, image.tiles.height, save_state);
    if (error) {
      std::cerr << "encoder error " << error << ": "<< lodepng_error_text(error) << std::endl;
      return;
    }

    lodepng::save_file(buffer, "test.png");
}
