#ifndef LOG_HPP
#define LOG_HPP

#include <stdio.h>
#include <stdarg.h>
#include <cstdlib>

void error(const char* format, ...);
void warning(const char* format, ...);

//#define DEBUG

#endif // LOG_HPP