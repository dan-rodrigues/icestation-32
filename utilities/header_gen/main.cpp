#include <iostream>
#include <fstream>
#include <optional>
#include <getopt.h>
#include <stdint.h>

#include "DataHeader.hpp"

int main(int argc, char **argv) {
    std::string type_name = "uint16_t";
    std::string identifier = "data";
    std::string output_path = "data.h";
    size_t max_length = SIZE_MAX;

    int opt;
    char *endptr;

    while ((opt = getopt_long(argc, argv, "t:i:o:m:", NULL, NULL)) != -1) {
        switch (opt) {
            case 't':
                type_name = optarg;
                break;
            case 'i':
                identifier = optarg;
                break;
            case 'o':
                output_path = optarg;
                break;
            case 'm':
                max_length = strtol(optarg, &endptr, 10);
                break;
            case '?':
                return EXIT_FAILURE;
        }
    }

    std::string input_path;
    if (argc == optind + 1) {
        input_path = argv[optind];
    } else {
        std::cerr << "Usage: (TODO) <input file>" << std::endl;
        return EXIT_FAILURE;
    }

    std::fstream stream(input_path);
    std::istreambuf_iterator<char> it(stream);
    std::istreambuf_iterator<char> end;
    std::vector<uint16_t> data;

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

    std::ofstream output_stream(output_path, std::ios::out);
    DataHeader::generate_header(data, type_name, identifier, output_stream);
    output_stream.close();
    
    return EXIT_SUCCESS;
}
