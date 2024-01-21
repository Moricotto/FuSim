#ifndef FILEWRITER_HPP
#define FILEWRITER_HPP

#include "grid.hpp"
#include <fstream>
#include <string>

template <typename T>
void writeToFileU(const UGrid<T>& grid, std::string filename);

template <typename T>
void writeToFileS(const SGrid<T>& grid, std::string filename);

#endif // FILEWRITER_HPP