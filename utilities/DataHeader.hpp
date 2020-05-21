#ifndef DataHeader_hpp
#define DataHeader_hpp

#include <stdint.h>
#include <vector>
#include <string>

#include <sstream>
#include <iomanip>

class DataHeader {

public:
    template<typename T>
    static void generate_header(std::vector<T> data, std::string header_type, std::string identifier, std::ostream& stream);
};

template<typename T>
void DataHeader::generate_header(std::vector<T> data, std::string header_type, std::string identifier, std::ostream& stream) {
    const auto indentation = "    ";
    const auto characters = sizeof(T) * 2;

    stream << "const " << header_type << " " << identifier << "[] = {" << "\n";

    for (auto it = begin(data); it != end(data); ++it) {
        auto separator = (it + 1 == end(data)) ? "" : ",";
        stream << indentation << "0x" << std::setfill('0') << std::setw(characters) << std::hex << *it << separator << "\n";
    }

    stream << "};" << "\n";
}

#endif /* DataHeader_hpp */
