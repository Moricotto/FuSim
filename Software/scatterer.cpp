#include "scatterer.hpp"

const Unsigned<Pos::integer + 1, Pos::fraction> gridx = Unsigned<Pos::integer + 1, Pos::fraction>{(float)GRIDX};
const Unsigned<Pos::integer + 1, Pos::fraction> gridy = Unsigned<Pos::integer + 1, Pos::fraction>{(float)GRIDY};

void scatter(const Particles& particles, UGrid<Charge>& rho, const UGrid<Bmag>& bmag) {
    rho.setAll(Charge{0.f});
    for (Particle particle: particles) {
        //get bmag from adjacent grid points
        Bmag bmag_interp = static_cast<Unsigned<Bmag::integer, Bmag::fraction>>(bmag.gather(particle.y, particle.x));
        //calculate gyroradius
        Pos gyroradius = Pos{particle.vperp.div<12, Bmag::integer, Bmag::fraction>(bmag_interp)}; 
        //perform accumulation of charge to four grid points around each gyropoint
        for (int i = 0; i < 4; i++) {
            PosPair gyropoint = {
                (i == 0 || i == 1) ? particle.y : (i == 2 ? particle.y.wrapping_minus(gyroradius) : particle.y.wrapping_add(gyroradius)),
                (i == 2 || i == 3) ? particle.x : (i == 0 ? particle.x.wrapping_minus(gyroradius) : particle.x.wrapping_add(gyroradius))
            };
            rho.scatter_charge(gyropoint.y, gyropoint.x);
        }
    }
}


