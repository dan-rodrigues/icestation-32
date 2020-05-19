// TODO: header

#ifndef File_hpp
#define File_hpp

#include <stdio.h>
#include <stdint.h>
#include <string>
#include <fstream>
#include <vector>

class File {

public:
    static void dump_array(char *array, size_t length, std::string file);

    template<typename T>
    static void dump_array(std::vector<T> vector, std::string path);
};

template<typename T>
void File::dump_array(std::vector<T> vector, std::string path) {
    dump_array(reinterpret_cast<char *>(&vector[0]), vector.size() * sizeof(T), path);
}

#endif /* File_hpp */
