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
    std::ios_base::fmtflags f(std::cout.flags());

    const auto indentation = "    ";
    const auto characters = sizeof(T) * 2;

    // headers for size_t and stdint

    stream << "#include <stddef.h>" << "\n";
    stream << "#include <stdint.h>" << "\n\n";

    // data

    stream << "const " << header_type << " " << identifier << "[] = {" << "\n";

    for (auto it = begin(data); it != end(data); ++it) {
        auto separator = (it + 1 == end(data)) ? "" : ",";
        uint32_t data = *it;
        stream << indentation << "0x" << std::setfill('0') << std::setw(characters) << std::hex << data << separator << "\n";
    }

    stream << "};" << "\n\n";

    // length

    stream << "const size_t " << identifier << "_length = " << std::setfill('0') << std::dec << data.size() << ";\n";

    std::cout.flags(f);
}

#endif /* DataHeader_hpp */
