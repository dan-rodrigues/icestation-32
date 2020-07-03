#include <iostream>
#include <fstream>
#include <optional>
#include <getopt.h>
#include <stdint.h>
#include <filesystem>

#include "DataHeader.hpp"

int main(int argc, char **argv) {
    std::string type_name = "uint16_t";
    std::string identifier = "data";
    std::string output_file_prefix = "data";
    size_t max_length = SIZE_MAX;
    bool split_sources = false;

    int opt = 0;
    while ((opt = getopt_long(argc, argv, "t:i:o:m:s", NULL, NULL)) != -1) {
        switch (opt) {
            case 't':
                type_name = optarg;
                break;
            case 'i':
                identifier = optarg;
                break;
            case 'o':
                output_file_prefix = optarg;
                break;
            case 'm':
                max_length = strtol(optarg, NULL, 10);
                break;
            case 's':
                split_sources = true;
                break;
            case '?':
                return EXIT_FAILURE;
        }
    }

    if (argc != optind + 1) {
        std::cerr << "Usage: [options] <input-file>" << std::endl;
        return EXIT_SUCCESS;
    }

    std::string input_path = argv[optind];
    std::fstream stream(input_path);
    std::istreambuf_iterator<char> it(stream);
    std::istreambuf_iterator<char> end;
    std::vector<uint16_t> data;

    if (stream.fail()) {
        std::cerr << "Failed to open file: " << input_path << std::endl;
        return EXIT_FAILURE;
    }

    // 16bit only for now
    uint8_t low_byte = 0;
    for (size_t i = 0; it != end && i < max_length; i++) {
        if (i & 1) {
            data.push_back((*it++ << 8) | low_byte);
        } else {
            low_byte = (*it++ & 0xff);
        }
    }

    stream.close();

    if (data.empty()) {
        std::cerr << "File is empty" << std::endl;
        return EXIT_FAILURE;
    }

    auto h_file_path = output_file_prefix + ".h";
    std::ofstream h_stream(h_file_path, std::ios::out);
    if (h_stream.fail()) {
        std::cerr << "Failed to open .h for writing: " << h_file_path << std::endl;
        return EXIT_FAILURE;
    }

    if (split_sources) {
        DataHeader::write_h(data, type_name, identifier, h_stream);

        auto c_file_path = output_file_prefix + ".c";
        std::ofstream c_stream(c_file_path, std::ios::out);
        if (c_stream.fail()) {
            std::cerr << "Failed to open .c for writing: " << c_file_path << std::endl;
            return EXIT_FAILURE;
        }
        DataHeader::write_c(data, type_name, identifier, c_stream);
        c_stream.close();
    } else {
        DataHeader::write_combined_h(data, type_name, identifier, h_stream);
    }

    h_stream.close();
    
    return EXIT_SUCCESS;
}
