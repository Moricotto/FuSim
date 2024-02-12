# Makefile for softfusim

# Compiler
CXX := g++

# Compiler flags
CXXFLAGS := -std=c++20 -Wall -Wextra -march=native -O3 -DDEBUG
LDFLAGS := 

# Source files
SRCS := $(wildcard *.cpp)

# Object files
OBJS := $(SRCS:.cpp=.o)

# Executable name
TARGET := softfusim.exe

# Default target
all: $(TARGET)

# Rule to build the executable
$(TARGET): $(OBJS)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -o $@ $^

# Rule to compile source files
log.o: log.cpp log.hpp
	$(CXX) $(CXXFLAGS) -c log.cpp -o $@

filewriter.o: filewriter.cpp global.hpp fixed.hpp grid.hpp
	$(CXX) $(CXXFLAGS) -c filewriter.cpp -o $@

scatterer.o: scatterer.cpp global.hpp fixed.hpp grid.hpp
	$(CXX) $(CXXFLAGS) -c scatterer.cpp -o $@

solver.o: solver.cpp global.hpp fixed.hpp grid.hpp
	$(CXX) $(CXXFLAGS) -c solver.cpp -o $@

pusher.o: pusher.cpp global.hpp fixed.hpp grid.hpp
	$(CXX) $(CXXFLAGS) -c pusher.cpp -o $@

softfusim.o: softfusim.cpp global.hpp fixed.hpp grid.hpp scatterer.hpp solver.hpp pusher.hpp filewriter.hpp
	$(CXX) $(CXXFLAGS) -c softfusim.cpp -o $@

# Clean target
clean:
	rm -f $(OBJS) $(TARGET)
