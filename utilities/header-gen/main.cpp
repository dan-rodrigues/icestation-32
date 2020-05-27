#include <iostream>
#include <fstream>
#include <getopt.h>
#include <stdint.h>

#include "DataHeader.hpp"

int main(int argc, char **argv) {
    std::string type_name = "uint16_t";
    std::string identifier = "data";
    std::string output_path = "data.h";

    int opt;

    while ((opt = getopt_long(argc, argv, "t:i:o:", NULL, NULL)) != -1) {
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
    // load 16bits, 32bits..
    std::istreambuf_iterator<char> it(stream);
    std::istreambuf_iterator<char> end;
    std::vector<uint16_t> data;

    auto byte_counter = 0;
    uint16_t word = 0;

    // 16bit only for now
    for (std::istreambuf_iterator<char> it(stream); it != end; ++it) {
        if (byte_counter == 0) {
            word = (*it & 0xff);
            byte_counter++;
        } else {
            word |= *it << 8;
            byte_counter = 0;
            data.push_back(word);
        }
    }

    stream.close();

    std::ofstream output_stream(output_path, std::ios::out);
    DataHeader::generate_header(data, type_name, identifier, output_stream);
    output_stream.close();
    
    return EXIT_SUCCESS;
}
