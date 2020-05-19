// TODO: proper header

#include <stdint.h>

#include <iostream>

#include "lodepng.h"

int main(int argc, const char * argv[]) {
    if (argc < 2) {
        std::cout << "usage: gfx-convert <filename>" << std::endl;
        return 1;
    }

    auto const filename = argv[1];
    
    // lodepng test:

    unsigned error;
    unsigned char* image = 0;
    unsigned width, height;
    unsigned char* png = 0;
    size_t pngsize;

    error = lodepng_load_file(&png, &pngsize, filename);
    if(!error) error = lodepng_decode32(&image, &width, &height, png, pngsize);
    if(error) printf("error %u: %s\n", error, lodepng_error_text(error));

    free(png);

    /*use image here*/

    free(image);

    return 0;
}
