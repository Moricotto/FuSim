push(particles, bmag, phi) {
    for (particle : particles) {
        gyroradius = particle.vperp / bmag.gather(particle.y, particle.x);
        for (int i = 0; i < 4; i++) {
            gyropoint = {
                (i == 0 || i == 1) ? particle.y : (i == 2 ? particle.y - gyroradius : particle.y + gyroradius),
                (i == 2 || i == 3) ? particle.x : (i == 0 ? particle.x - gyroradius : particle.x + gyroradius)};
            for (int j = 0; j < 4; j++) {
                base_addr = {gyropoint.y.int() + (j == 0 || j == 1 ? -1 : 0), 
                             gyropoint.x.int() + (j == 0 || j == 2 ? -1 : 0)};
                for (int k = 0; k < 4; k++) {
                    addr = {base_addr.y + (k == 0 || k == 1 ? 0 : 1), 
                            base_addr.x + (k == 0 || k == 2 ? 0 : 1)};
                    phi_starburst[i][j][k] = phi(addr.y, addr.x);
                    bmag_starburst[i][j][k] = bmag(addr.y, addr.x);
                }
            }
        }
        efield = grad(phi_starburst).gather(particle.y, particle.x);
        grad_b = grad(bmag_starburst).gather(particle.y, particle.x);
        bmag = bmag_starburst.gather(particle.y, particle.x);
        exb_disp = {efield.x / bmag, -efield.y / bmag};
        mu = particle.vperp * particle.vperp / 2;
        gradb_disp = {mu * grad_b.x, mu * -grad_b.y};
        particle.y += exb_disp.y + gradb_disp.y;
        particle.x += exb_disp.x + gradb_disp.x;
    }
}