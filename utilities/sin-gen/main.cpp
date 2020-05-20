
#include <iostream>

#include <math.h>

#include "File.hpp"

int main(int argc, const char * argv[]) {
    if (argc < 2) {
        std::cout << "usage: <output-file>" << std::endl;
        return 1;
    }

    const auto count = 256;
    const bool generate_full_table = false;

    if (generate_full_table) {
        int16_t table[256];
        for (int i = 0; i < count; i++) {
            auto theta = M_PI * 2 / count * i;
            // leave one integer bit hence the /2
            table[i] = sin(theta) * 0x8000 / 2;
        }
        File::dump_array((char *)table, 512, argv[1]);
    } else {
        int16_t table[256];
        for (int i = 0; i < count; i++) {
            auto theta = M_PI * 2 / count * i;
            // leave one integer bit hence the /2
            table[i] = sin(theta / 4) * 0x8000 / 2;
        }
        File::dump_array((char *)table, 512, argv[1]);
    }


    return 0;
}
