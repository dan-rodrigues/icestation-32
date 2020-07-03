#include <iostream>
#include <sstream>
#include <fstream>
#include <getopt.h>
#include <math.h>
#include <limits>

#include "DataHeader.hpp"

int main(int argc, char **argv) {
    bool split_sources = false;
    bool full_period = true;
    std::string output_file_prefix = "sin";
    uint16_t count = 256;
    int16_t sin_max = 0x4000;

    int opt = 0;
    while ((opt = getopt_long(argc, argv, "m:c:sq", NULL, NULL)) != -1) {
        switch (opt) {
            case 'm': {
                int64_t sin_max_64 = strtol(optarg, NULL, 16);
                if (sin_max_64 > std::numeric_limits<int16_t>::max()) {
                    std::cerr << "-m arg must be a signed 16bit integer" << std::endl;
                    return EXIT_FAILURE;
                }
                if (sin_max_64 <= 0) {
                    std::cerr << "-m arg must be a non-zero positive integer" << std::endl;
                    return EXIT_FAILURE;
                }

                sin_max = (int16_t)sin_max_64;
            } break;
            case 'q':
                full_period = false;
                break;
            case 's':
                split_sources = true;
                break;
            case '?':
                return EXIT_FAILURE;
        }
    }

    std::vector<int16_t> table;
    table.resize(count);

    for (int i = 0; i < count; i++) {
        auto theta = M_PI * 2 / count * i;
        table[i] = sin(theta / (full_period ? 1 : 4)) * sin_max;
    }

    const std::string identifier = output_file_prefix;
    const std::string type_name = "int16_t";

    auto h_file_path = output_file_prefix + ".h";
    std::ofstream h_stream(h_file_path);

    if (split_sources) {
        DataHeader::write_h(table, type_name, identifier, h_stream);

        auto c_file_path = output_file_prefix + ".c";
        std::ofstream c_stream(c_file_path, std::ios::out);
        if (c_stream.fail()) {
            std::cerr << "Failed to open .c for writing: " << c_file_path << std::endl;
            return EXIT_FAILURE;
        }
        DataHeader::write_c(table, type_name, identifier, c_stream);
        c_stream.close();
    } else {
        DataHeader::write_combined_h(table, type_name, identifier, h_stream);
    }
    h_stream.close();

    return EXIT_SUCCESS;
}
