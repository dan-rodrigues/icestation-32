#include <stdint.h>
#include <stdlib.h>

#include <optional>
#include <iostream>
#include <algorithm>
#include <iomanip>
#include <fstream>
#include <getopt.h>

#include "lodepng.h"
#include "lodepng_util.h"

#include "Palette.hpp"
#include "Tiles.hpp"
#include "Image.hpp"
#include "Map.hpp"

#include "DataHeader.hpp"

static void save_transcoded_png(Image image, const std::string &name);
static bool save_palette(const Palette &palette, const std::string &path);

static bool load_palette(const std::string &path,
                         std::optional<uint8_t> palette_id,
                         std::vector<uint8_t> &palette_data);

static bool convert_image(const std::vector<uint8_t> &input_data,
                          const std::vector<uint8_t> &palette_data,
                          InputFormat input_format,
                          const std::string &name,
                          const std::string &output_prefix);

static bool convert_map(const std::vector<uint8_t> &input_data,
                        const std::string &output_path);

int main(int argc, char **argv)  {
    InputFormat input_format = PNG;

    std::string palette_path;
    std::optional<uint8_t> palette_id = std::nullopt;
    std::string output_prefix = "";
    std::string palette_output_path;

    // Map conversion args:

    std::string map_output_path = "";
    uint16_t snes_vram_offset = 0;

    if (argc < 2) {
        std::cout << "Usage: [options] <input-file>" << std::endl;
        return EXIT_SUCCESS;
    }

    int opt;
    char *endptr;

    const option options[] = {
        {.name = "snes-vram", .has_arg = required_argument, .flag = NULL, .val = 'v'},
        {.name = "snes-vram-offset", .has_arg = required_argument, .flag = NULL, .val = 'y'},
        {.name = "map-output", .has_arg = required_argument, .flag = NULL, .val = 'm'},
        {.name = "palette-output", .has_arg = required_argument, .flag = NULL, .val = 'x'}
    };

    while ((opt = getopt_long(argc, argv, "m:f:p:i:o:", &options[0], NULL)) != -1) {
        switch (opt) {
            case 'f': {
                std::string input_format_arg = optarg;
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
                palette_path = optarg;
                break;
            case 'i':
                palette_id = strtol(optarg, &endptr, 10);
                break;
            case 'o':
                output_prefix = optarg;
                break;
            case 'm':
                map_output_path = optarg;
                break;
            case 'y':
                snes_vram_offset = strtol(optarg, &endptr, 16);
                break;
            case 'x':
                palette_output_path = optarg;
                break;
            case '?':
                return EXIT_FAILURE;
        }
    }

    std::string image_path;
    if (argc == (optind + 1)) {
        image_path = argv[optind];
    } else if (argc == optind) {
        std::cout << "No image file path given, checking for palette file path.." << "\n";
    } else {
        std::cout << "Expected at least one input file" << "\n";
        return EXIT_FAILURE;
    }

    // Load graphics (or map) data

    std::vector<uint8_t> input_data;
    if (!image_path.empty()) {
        std::ifstream input_stream(image_path, std::ios::binary);
        input_stream.seekg(snes_vram_offset);
        if (input_stream.fail()) {
            std::cerr << "Failed to open input file: " << image_path << std::endl;
            return EXIT_FAILURE;
        }
        input_data = std::vector<uint8_t>(std::istreambuf_iterator<char>(input_stream), {});
        input_stream.close();
    }

    // Map conversion:

    if (!map_output_path.empty()) {
        bool success = convert_map(input_data, map_output_path);
        return success ? EXIT_SUCCESS : EXIT_FAILURE;
    }

    // Was a custom palette provided?

    std::vector<uint8_t> palette_data;
    if (!palette_path.empty()) {
        if (!load_palette(palette_path, palette_id, palette_data)) {
            return EXIT_FAILURE;
        }
    } else if (palette_id.has_value()) {
        std::cout << "Custom palette ID specified but no palette was provided" << std::endl;
        return EXIT_FAILURE;
    }

    bool has_image = !image_path.empty() && !input_data.empty();
    if (has_image) {
        if (!convert_image(input_data, palette_data, input_format, image_path, output_prefix)) {
            return EXIT_FAILURE;
        }
    }

    // Palette conversion (standalone):

    bool convert_standalone_palette = map_output_path.empty() && !palette_path.empty() && !palette_output_path.empty();
    if (convert_standalone_palette) {
        std::cout << "..converting standalone palette: " << palette_output_path << "\n";

        Palette palette = Palette(palette_data);
        save_palette(palette, palette_output_path);
    }

    return EXIT_SUCCESS;
}

static bool convert_image(const std::vector<uint8_t> &input_data,
                          const std::vector<uint8_t> &palette_data,
                          InputFormat input_format,
                          const std::string &name,
                          const std::string &output_prefix)
{
    Image image;
    try {
        image = Image(input_data, palette_data, input_format);
    } catch (std::invalid_argument e) {
        std::cerr << "Failed to convert tiles and palette to image: " << e.what() << std::endl;
        return false;
    }

    // Tiles output

    auto tiles = image.tiles.ics_tiles();
    auto tiles_name = output_prefix + "tiles";
    std::ofstream output_tiles_binary_stream(tiles_name + ".bin", std::ios::out);
    for (size_t i = 0; i < tiles.size(); i++) {
        output_tiles_binary_stream.write((char *)(&tiles[i]), sizeof(uint32_t));
    }
    output_tiles_binary_stream.close();

    // Palette output

    auto palette_name = output_prefix + "palette";
    if (!save_palette(image.palette, palette_name + ".bin")) {
        return false;
    }

    // Test PNG to quickly verify results

    save_transcoded_png(image, output_prefix);

    return true;
}

void save_transcoded_png(Image image, const std::string &name) {
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

static bool save_palette(const Palette &palette, const std::string &path) {
    auto palette_data = palette.ics_palette();
    std::ofstream stream(path, std::ios::out);
    if (stream.fail()) {
        std::cerr << "Failed to open palette file for writing: " << path << std::endl;
        return false;
    }

    stream.write((char *)(&palette_data[0]), sizeof(uint16_t) * palette_data.size());
    stream.close();

    return true;
}

static bool convert_map(const std::vector<uint8_t> &input_data, const std::string &output_path) {
    Map map(input_data);

    std::ofstream stream(output_path, std::ios::out);
    if (stream.fail()) {
        std::cerr << "Failed to open map file for writing: " << output_path << std::endl;
        return false;
    }

    auto ics_map = map.ics_map();
    stream.write((char *)&ics_map[0], ics_map.size() * sizeof(uint16_t));
    stream.close();

    std::cout << "Successfully converted map file with output: " << output_path << "\n";
    return true;
}

static bool load_palette(const std::string &path, std::optional<uint8_t> palette_id, std::vector<uint8_t> &palette_data) {
    std::fstream stream(path);
    if (stream.fail()) {
        std::cerr << "Error: failed to open palette file" << std::endl;
        return false;
    }

    // Was only a single palette within the entire set requested?
    if (palette_id.has_value()) {
        // Read only the 16 colors of that one palette
        const auto rgb24_palette_size = 16 * 3;
        palette_data.resize(rgb24_palette_size);
        auto palette_file_base = palette_id.value() * rgb24_palette_size;
        stream.seekg(palette_file_base);
        stream.read((char *)&palette_data[0], rgb24_palette_size);
    } else {
        // Read entire palette
        palette_data = std::vector<uint8_t>(std::istreambuf_iterator<char>(stream), {});
    }

    stream.close();

    return true;
}
