#include "log.hpp"

void error(const char* format, ...) {
    #ifdef DEBUG
    va_list args;
    va_start(args, format);
    fprintf(stderr, "Error: ");
    vfprintf(stderr, format, args);
    fprintf(stderr, "\n");
    va_end(args);
    std::exit(1);
    #endif
}

void warning(const char* format, ...) {
    #ifdef DEBUG
    va_list args;
    va_start(args, format);
    fprintf(stderr, "Warning: ");
    vfprintf(stderr, format, args);
    fprintf(stderr, "\n");
    va_end(args);
    #endif
}
