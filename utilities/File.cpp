// TODO: header

#include "File.hpp"

void File::dump_array(char *array, size_t length, std::string path) {
    std::ofstream stream(path, std::ios::out | std::ios::binary);
    stream.write(array, length);
    stream.close();
}
