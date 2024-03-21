#ifndef GLOBAL_H
#define GLOBAL_H

#include <iostream>
#include <cstdint>
#include <string>
#include <vector>
#include <map>
#include <vector>
#include <cmath>
#include <array>
#include <stdio.h>
#include "fixed.hpp"

constexpr unsigned int GRIDX = 64;
constexpr unsigned int GRIDY = 64;
constexpr unsigned int GRID_SIZE = GRIDX * GRIDY;
constexpr unsigned int NUM_PARTICLES = 16384;
constexpr double SQRT_NUM_PARTICLES = 128;
constexpr unsigned int NUM_VPERP = 3;
constexpr unsigned int NUM_ITERATIONS_F = 17;
constexpr unsigned int NUM_ITERATIONS = 8;
constexpr unsigned int NUM_TIMESTEPS = 4096;
constexpr unsigned int NUM_DIAGNOSTICS = NUM_TIMESTEPS / 4;
constexpr unsigned int DIAGNOSTIC_INTERVAL = NUM_DIAGNOSTICS == 0 ? NUM_TIMESTEPS + 1 : NUM_TIMESTEPS / NUM_DIAGNOSTICS;
constexpr unsigned int SLOWDOWN = 4;
//types
typedef Unsigned<6, 12> Pos;
typedef Unsigned<2, 12> Vel;
typedef Unsigned<2, 12> Bmag;
typedef Unsigned<12, 24> Charge;
typedef Signed<7, 27> Phi;
typedef Signed<7, 27> Efield;
typedef Signed<Bmag::integer, Bmag::fraction> GradB;

struct Particle {
    Pos y;
    Pos x;
    Vel vperp;
};

template <typename T>
struct Pair {
    T y;
    T x;

    template <typename U>
    operator Pair<U>() const {
        return Pair<U>{static_cast<U>(y), static_cast<U>(x)};
    }
};

typedef Pair<Pos> PosPair;


typedef std::array<Particle, NUM_PARTICLES> Particles;


#endif // GLOBAL_H
