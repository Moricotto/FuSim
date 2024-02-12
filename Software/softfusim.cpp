#include "global.hpp"
#include "grid.hpp"
#include "scatterer.hpp"
#include "solver.hpp"
#include "pusher.hpp"
#include <fstream>
#include <random>
#include <cmath>
#include <algorithm>
#include <chrono>
//#include "filewriter.hpp"
// =======================================
// This is the software implementation of the exact same algorithm as the hardware implementation contained in this folder.
// The goal is for the global details as well as some of the implementation details to be the same.
// This will allow for a fair and rigourous comparison between the two implementations, while allowing me to use the software impplmementation to verify the hardware implementation.
// =======================================

template <typename T>
void writeToFileU(const UGrid<T>& grid, std::string filename) {
    std::ofstream file;
    file.open(filename, std::ofstream::out | std::ofstream::trunc);
    file << "unsigned" << std::endl << T::integer << std::endl << T::fraction << std::endl;
    for (unsigned int i = 0; i < GRID_SIZE; i++) {
        file << grid[i].value;
        if (i != GRID_SIZE - 1) file << ",";
    }
    file.close();
}

template <typename T>
void writeToFileS(const SGrid<T>& grid, std::string filename) {
    std::ofstream file;
    file.open(filename, std::ofstream::out | std::ofstream::trunc);
    file << "signed" << std::endl << T::integer << std::endl << T::fraction << std::endl;
    for (unsigned int i = 0; i < GRID_SIZE; i++) {
        file << grid[i].value;
        if (i != GRID_SIZE - 1) file << ",";
    }
    file.close();
}

int main() {
    #ifdef DEBUG
    std::cout << "DEBUG MODE" << std::endl;
    #endif // DEBUG
    //initialize the grid of magnetic field values and gyroradii
    UGrid<Bmag> bmag{Bmag{1.f}};
    bmag.setAll(Bmag{1.f});
    const std::array<Vel, NUM_VPERP> vperp = {Vel{1.5f}, Vel{2.0f}, Vel{2.5f}};
    std::array<UGrid<Pos>, NUM_VPERP> gyroradii;
    for (unsigned int y = 0; y < GRIDY; y++) {
        for (unsigned int x = 0; x < GRIDX; x++) {
            float intensity = ((float)abs((long)x - 32))/32.f + 1.f;
            bmag(y, x) = Bmag{intensity};            //bmag(y, x) = Bmag{(float) x / 64 * 2 + 1}; //Bmag{((x - 32) * (x - 32) + (y - 32) * (y - 32) + 1024)/1024.f};
            for (unsigned int v = 0; v < NUM_VPERP; v++) {
                gyroradii[v](y, x) = Pos{vperp[v].div<Pos::fraction, Bmag::integer, Bmag::fraction>(bmag(y, x))};
            }
        }
    }
    //delete all files  in data/
    system("rm data/*");
    //write bmag to file
    writeToFileU(bmag, "data/bmag.txt");
    //write gyroradii to file
    for (unsigned int v = 0; v < NUM_VPERP; v++) {
        writeToFileU(gyroradii[v], "data/gyroradii" + std::to_string(v) + ".txt");
    }
    Particles particles;
    /*
    //initialise the particle positions and velocities
    //here we employ a quit start in which the particles are placed on a grid
    //and the velocities are sampled from a Gaussian
    std::array<float, 2> offset = {GRIDX / SQRT_NUM_PARTICLES, GRIDY / SQRT_NUM_PARTICLES};
    for (int i = 0; i < (int)SQRT_NUM_PARTICLES; i++) {
        for (int j = 0; j < (int)SQRT_NUM_PARTICLES; j++) {
            particles[i * (int)SQRT_NUM_PARTICLES + j].y = Pos{std::clamp((float)j + 0.5 * offset[0], 0.0, 63.9999)};
            particles[i * (int)SQRT_NUM_PARTICLES + j].x = Pos{std::clamp((float)j + 0.5 * offset[1], 0.0, 63.9999)};
            particles[i * (int)SQRT_NUM_PARTICLES + j].vperp = Vel{2.0f};
        }
    }*/
    ///*
    std::default_random_engine generator;
    std::normal_distribution<double> distribution1_x(32.0, 6.0);
    std::normal_distribution<double> distribution1_y(16.0, 6.0);
    std::normal_distribution<double> distribution2_x(32.0, 6.0);
    std::normal_distribution<double> distribution2_y(48.0, 6.0);
    std::normal_distribution<double> vel_distribution(2.0, 0.5);
    for (unsigned int i = 0; i < NUM_PARTICLES; i++) {
        bool sel = rand() % 2;
        //place particle in random position according to sum of gaussian distributions
        double y = std::clamp(sel ? distribution1_y(generator) : distribution2_y(generator), 0.0, 63.99999);
        double x = std::clamp(sel ? distribution1_x(generator) : distribution2_x(generator), 0.0, 63.99999);
        particles[i].y = Pos{y};
        particles[i].x = Pos{x};
        //sample velocity from gaussian distribution
        double v = std::clamp(vel_distribution(generator), 0.0, 4.0);
        particles[i].vperp = Vel{v};

    }//*/
    //calculate charge density
    //particles[0] = Particle{Pos{32.f}, Pos{32.f}, Vel{0.f}};
    UGrid<Charge> rho;
    SGrid<Phi> phi_in = SGrid<Phi>{}; //initial guess for phi
    SGrid<Phi> phi_out;
    bool first = true;
    auto start_time = std::chrono::high_resolution_clock::now();
    for (unsigned int t = 0; t < NUM_TIMESTEPS; t++) {
        rho.setAll(Charge{0.f});
        scatter(particles, rho, bmag);
        //write rho to file
        phi_out = solve(phi_in, gyroradii, rho, first ? NUM_ITERATIONS_F : NUM_ITERATIONS);
        //write phi to file
        push(particles, bmag, phi_out);
        if (t % DIAGNOSTIC_INTERVAL == 0) {
            writeToFileU(rho, "data/rho" + std::to_string(t / DIAGNOSTIC_INTERVAL) + ".txt");
            writeToFileS(phi_out, "data/phi" + std::to_string(t / DIAGNOSTIC_INTERVAL) + ".txt");
        }
        phi_in = phi_out;
        first = false;
    }
    auto stop_time = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::microseconds>(stop_time - start_time);
    std::cout << "Time taken: " << duration.count() << " microseconds" << std::endl;
    return 0;
}