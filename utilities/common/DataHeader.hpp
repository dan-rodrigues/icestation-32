#ifndef DataHeader_hpp
#define DataHeader_hpp

#include <stdint.h>
#include <vector>
#include <string>
#include <type_traits>

#include <sstream>
#include <iomanip>

class DataHeader {

public:
    template<typename T>
    static void write_combined_h(
        const std::vector<T> &data,
        const std::string &header_type,
        const std::string &identifier,
        std::ostream &stream
    );

    template<typename T>
    static void write_h(
        const std::vector<T> &data,
        const std::string &header_type,
        const std::string &identifier,
        std::ostream &stream
    );

    template<typename T>
    static void write_c(
        const std::vector<T> &data,
        const std::string &header_type,
        const std::string &identifier,
        std::ostream &stream
    );

private:
    template<typename T>
    static void write_body(
        const std::vector<T> &data,
        const std::string &header_type,
        const std::string &identifier,
        bool split,
        std::ostream &stream
    );
};

template<typename T>
void DataHeader::write_h(
    const std::vector<T> &data,
    const std::string &header_type,
    const std::string &identifier,
    std::ostream &stream)
{
    stream << "#include <stddef.h>" << "\n";
    stream << "#include <stdint.h>" << "\n\n";

    stream << "extern const " << header_type << " " << identifier << "[];" << "\n";
    stream << "extern const size_t " << identifier << "_length;" << "\n";
}

template<typename T>
void DataHeader::write_c(
    const std::vector<T> &data,
    const std::string &header_type,
    const std::string &identifier,
    std::ostream &stream)
{
    write_body(data, header_type, identifier, true, stream);
}

template<typename T>
void DataHeader::write_combined_h(
    const std::vector<T> &data,
    const std::string &header_type,
    const std::string &identifier,
    std::ostream &stream)
{
    write_body(data, header_type, identifier, false, stream);
}

template<typename T>
void DataHeader::write_body(
    const std::vector<T> &data,
    const std::string &header_type,
    const std::string &identifier,
    bool split,
    std::ostream &stream)
{
    std::ios_base::fmtflags f(std::cout.flags());

    const auto indentation = "    ";
    const auto characters = sizeof(T) * 2;

    // headers for size_t and stdint

    if (split) {
        stream << "#include \"" << identifier << ".h\"" << "\n\n";
    } else {
        stream << "#include <stddef.h>" << "\n";
        stream << "#include <stdint.h>" << "\n\n";
    }

    // data

    stream << "const " << header_type << " " << identifier << "[] = {" << "\n";

    for (auto it = begin(data); it != end(data); ++it) {
        auto separator = (it + 1 == end(data)) ? "" : ",";
        if (std::is_signed<T>::value) {
            stream << indentation << *it << separator << "\n";
        } else {
            uint32_t data = *it;
            stream << indentation << "0x" << std::setfill('0') << std::setw(characters) << std::hex << data << separator << "\n";
        }
    }

    stream << "};" << "\n\n";

    // length

    stream << "const size_t " << identifier << "_length = " << std::setfill('0') << std::dec << data.size() << ";\n";

    std::cout.flags(f);
}

#endif /* DataHeader_hpp */
