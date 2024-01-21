#include "solver.hpp"

const std::array<Unsigned<0, 24>, NUM_VPERP> weights = {Unsigned<0, 24>{0.25}, Unsigned<0, 24>{0.5}, Unsigned<0, 24>{0.25}};
const Signed<4, 20> ki = Signed<4, 20>{4.f};
const Signed<4, 20> ke = Signed<4, 20>{4.f};
const Signed<4, 20> diag_const = Signed<4, 20>((float)ki * (3.f/4) + (float)ke);
const Signed<4, 20> inv_diag_const =  Signed<4, 20>{1.f / (float)diag_const};
const Unsigned<Pos::integer + 1, Pos::fraction> gridy = Unsigned<Pos::integer + 1, Pos::fraction>{(float)GRIDY};
const Unsigned<Pos::integer + 1, Pos::fraction> gridx = Unsigned<Pos::integer + 1, Pos::fraction>{(float)GRIDX};

SGrid<Phi> solve(const SGrid<Phi>& phi_in, const std::array<UGrid<Pos>, NUM_VPERP> gyroradii, const UGrid<Charge>& rho, const unsigned int num_iterations) { 
    std::array<SGrid<Phi>, 2> buffers = {phi_in, SGrid<Phi>{}};
    buffers[1].setAll(Phi{0.f});

    for (unsigned int it = 0; it < num_iterations; it++) {
        SGrid<Phi>& phi = buffers[it % 2];
        float residual = 0;
        for (unsigned int y = 0; y < GRIDY; y++) {
            for (unsigned int x = 0; x < GRIDX; x++) {
                std::array<Signed<Phi::integer, Phi::fraction + Pos::fraction * 2>, NUM_VPERP> total_phi = {0.f};
                for (unsigned int v = 0; v < NUM_VPERP; v++) {
                    Pos gyroradius = gyroradii[v](y, x);
                    Pos double_gyroradius = gyroradius << 1;
                    PosPair position = PosPair{Pos{(float)y}, Pos{(float)x}};
                    //interpolate phi to the calculated interpolation points and accumulate the result
                    for (int i = 0; i < 4; i++) {
                        total_phi[v] += phi.gather((i == 0 || i == 1) ? position.y.wrapping_minus(gyroradius) : position.y.wrapping_add(gyroradius), 
                                                   (i == 0 || i == 2) ? position.x.wrapping_minus(gyroradius) : position.x.wrapping_add(gyroradius)) >> 3;
                        total_phi[v] += phi.gather((i == 0 || i == 1) ? position.y : (i == 2 ? position.y.wrapping_minus(double_gyroradius) : position.y.wrapping_add(double_gyroradius)), 
                                                    (i == 2 || i == 3) ? position.x : (i == 0 ? position.x.wrapping_minus(double_gyroradius) : position.x.wrapping_add(double_gyroradius))) >> 4;
                    }
                }
                //calculate weighted phi
                Signed<Charge::integer, Phi::fraction> true_phi = Signed<Charge::integer, Phi::fraction>{0.f};
                for (unsigned int v = 0; v < NUM_VPERP; v++) {
                    true_phi += static_cast<Signed<Charge::integer, Phi::fraction>>(total_phi[v] * weights[v] * -ki);
                }
                //true_phi = Signed<Phi::integer + 2, Phi::fraction>{true_phi.value << 28};
                //every iteration, calculate residual and print it
                //we can cast everything to float here as this does not need to match the hardware implementation
                float matrix_prod = static_cast<float>(true_phi) + static_cast<float>(diag_const) * static_cast<float>(phi(y, x));
                residual += static_cast<float>(rho(y, x)) - matrix_prod;
                //calculate the difference between rho and A(phi)
                Signed<Charge::integer + 1, Phi::fraction> diff = static_cast<Signed<Charge::integer, Phi::fraction>>(rho(y, x)) - true_phi;
                Signed<(Charge::integer + 1) + 4, Phi::fraction + 20> new_phi =  diff * inv_diag_const; 
                //if (y % 8 == 0 && x % 8 == 0) std::cout << "rho = " << (float)rho(y, x) << ", phi = "  << (float)phi(y, x) << ", A(phi) = " << matrix_prod << " new_phi = "  <<(float)static_cast<Phi>(new_phi) << std::endl;
                //std::cout << "it = " << it << ": diff = " << float(Phi{new_phi} - phi(y, x)) << std::endl;
                buffers[(it + 1) % 2](y, x) = static_cast<Phi>(new_phi);
            }
        }
        //std::cout << residual  * residual << std::endl;
    }
    //std::cout << "==========" << std::endl;

    return buffers[NUM_ITERATIONS % 2];
}   