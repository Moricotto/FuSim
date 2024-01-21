#ifndef SCATTERER_HPP
#define SCATTERER_HPP

#include "global.hpp"
#include "grid.hpp"

void scatter(const Particles& particles, UGrid<Charge>& rho, const UGrid<Bmag>& bmag);

#endif // SCATTERER_HPP