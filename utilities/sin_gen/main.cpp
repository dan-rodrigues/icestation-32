#include <iostream>
#include <sstream>
#include <fstream>
#include <math.h>

#include "DataHeader.hpp"

int main(int argc, const char * argv[]) {
    if (argc < 2) {
        std::cout << "Usage: <output-file>" << std::endl;
        return EXIT_FAILURE;
    }

    const auto output_path = argv[1];

    const auto count = 256;
    const auto sin_max = 0x4000;

    int16_t table[256];

    for (int i = 0; i < count; i++) {
        auto theta = M_PI * 2 / count * i;
        table[i] = sin(theta / 4) * sin_max;
    }

    std::ofstream stream;
    stream.open(output_path);

    DataHeader::generate_header(std::vector<int16_t>(table, table + count), "int16_t", "sin_table", stream);

    stream.close();

    return EXIT_SUCCESS;
}
