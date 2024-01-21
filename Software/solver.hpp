#ifndef SOLVER_HPP
#define SOLVER_HPP

#include "grid.hpp"
#include "global.hpp"

SGrid<Phi> solve(const SGrid<Phi>& phi_in, const std::array<UGrid<Pos>, NUM_VPERP> gyroradii, const UGrid<Charge>& rho, const unsigned int num_iterations);

#endif // SOLVER_HPP