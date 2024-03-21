#include "global.hpp"
#include "grid.hpp"
#include "scatterer.hpp"
#include "solver.hpp"
#include "pusher.hpp"
#include <random>
#include <cmath>
#include <algorithm>
#include <chrono>
// =======================================
// This is the software implementation of the exact same algorithm as the hardware implementation contained in this folder.
// The goal is for the global details as well as some of the implementation details to be the same.
// This will allow for a fair and rigourous comparison between the two implementations, while allowing me to use the software impplmementation to verify the hardware implementation.
// =======================================

int main(int argc, char* argv[]) {
    #ifdef DEBUG
    std::cout << "DEBUG MODE" << std::endl;
    #endif // DEBUG
    bool write_bmag = true;
    bool write_gyroradii = false;
    bool write_rho = true;
    bool write_phi = false;
    bool write_efield = true;
    bool gen_commands = false;
    bool run = true;
    for (int i = 1; i < argc; i++) {
        if (std::string(argv[i]) == "-no-bmag") {
            write_bmag = false;
        } else if (std::string(argv[i]) == "-gyroradii") {
            write_gyroradii = true;
        } else if (std::string(argv[i]) == "-no-rho") {
            write_rho = false;
        } else if (std::string(argv[i]) == "-phi") {
            write_phi = true;
        } else if (std::string(argv[i]) == "-no-efield") {
            write_efield = false;
        } else if (std::string(argv[i]) == "-gen-commands") {
            gen_commands = true;
        } else if (std::string(argv[i]) == "-no-run") {
            run = false;
        }
    }
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
    if (write_bmag) bmag.write("data/bmag.txt");
    //write gyroradii to file
    if (write_gyroradii) {
        for (unsigned int v = 0; v < NUM_VPERP; v++) {
            gyroradii[v].write("data/gyroradii" + std::to_string(v) + ".txt");
        }
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

    }

    if (gen_commands) {
        //write the set of commands that will recreate the current configuration in the FPGA to a file
        FILE* file = fopen("commands.txt", "w");
        for (Particle& particle: particles) {
            fprintf(file, "*p%05x%08x\n", particle.y.value, (particle.x.value << Vel::bits) + particle.vperp.value);
        }
        for (unsigned int i = 0; i < GRID_SIZE; i++) {
            fprintf(file, "*m%03x%04x\n", i, bmag[i].value);
        }
        fprintf(file, "*g%08x\n", NUM_TIMESTEPS);
        fclose(file);
    }
    //*/
    if (run) {
        UGrid<Charge> rho;
        SGrid<Phi> phi_in = SGrid<Phi>{}; //initial guess for phi
        SGrid<Phi> phi_out;
        bool first = true;
        auto start_time = std::chrono::high_resolution_clock::now();
        for (unsigned int t = 0; t < NUM_TIMESTEPS; t++) {
            rho.setAll(Charge{0.f});
            scatter(particles, rho, bmag);
            phi_out = solve(phi_in, gyroradii, rho, first ? NUM_ITERATIONS_F : NUM_ITERATIONS);
            //write phi to file
            push(particles, bmag, phi_out);
            if (t % DIAGNOSTIC_INTERVAL == 0) {
                if (write_rho) rho.write("data/rho" + std::to_string(t / DIAGNOSTIC_INTERVAL) + ".txt");
                if (write_phi) phi_out.write("data/phi" + std::to_string(t / DIAGNOSTIC_INTERVAL) + ".txt");
                if (write_efield) {
                    FILE * file = fopen(("data/efield" + std::to_string(t / DIAGNOSTIC_INTERVAL) + ".txt").c_str(), "w");
                    //calculate efield at every gridpoint
                    for (unsigned int y = 0; y < GRIDY; y++) {
                        for (unsigned int x = 0; x < GRIDX; x++) {
                            Pair<Phi> grad_phi = phi_out.grad(y, x);
                            fprintf(file, "%d,%d,", grad_phi.y.value, grad_phi.x.value);
                        }
                    }
                    fclose(file);
                }
            }
            phi_in = phi_out;
            first = false;
        }
        auto stop_time = std::chrono::high_resolution_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::microseconds>(stop_time - start_time);
        std::cout << "Time taken: " << duration.count() << " microseconds" << std::endl;
    }
    return 0;
}