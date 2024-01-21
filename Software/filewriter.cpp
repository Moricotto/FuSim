#include "filewriter.hpp"

template <typename T>
void writeToFileU(const UGrid<T>& grid, std::string filename) {
    std::ofstream file;
    file.open(filename, std::ofstream::out | std::ofstream::trunc);
    file << "unsigned" << " " << T::integer << " " << T::fraction << std::endl;
    for (int i = 0; i < GRID_SIZE; i++) {
        file << grid[i].value << ",";
    }
    file.close();
}

template <typename T>
void writeToFileS(const SGrid<T>& grid, std::string filename) {
    std::ofstream file;
    file.open(filename);
    file << "signed" << " " << T::integer << " " << T::fraction << std::endl;
    for (int i = 0; i < GRID_SIZE; i++) {
        file << grid[i].value << ",";
    }
    file.close();
}