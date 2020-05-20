
#include <iostream>

#include <math.h>
#include <sstream>

#include "File.hpp"
#include "DataHeader.hpp"

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
//        File::dump_array((char *)table, 512, argv[1]);

        std::ofstream ostream;
        ostream.open(argv[1]);
        DataHeader::generate_header(std::vector<uint16_t>(table, table + 256), ostream);
    }


    return 0;
}
