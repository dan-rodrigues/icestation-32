
#include "DataHeader.hpp"

#include <sstream>
#include <iomanip>

void DataHeader::generate_header(std::vector<uint16_t> data, std::ostream& stream) {
    const auto name = "sin_table";
    const auto type = "int16_t";
    const auto indentation = "    ";
    const auto characters = 4;

    stream << "const " << type << " " << name << "[] = {" << "\n";

    std::string separator;
    for (auto it = begin(data); it != end(data); ++it) {
        auto separator = (it + 1 == end(data)) ? "" : ",";
        stream << indentation << "0x" << std::setfill('0') << std::setw(characters) << std::hex << *it << separator << "\n";
    }

    stream << "}" << "\n";
}
