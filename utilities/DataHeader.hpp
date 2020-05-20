
#ifndef DataHeader_hpp
#define DataHeader_hpp

#include <stdint.h>
#include <vector>
#include <string>

class DataHeader {

public:
    // generalise for 8bit/16bit etc.
    static void generate_header(std::vector<uint16_t> data, std::ostream& stream);
};

#endif /* DataHeader_hpp */
