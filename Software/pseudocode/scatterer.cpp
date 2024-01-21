scatter(particles, rho, bmag) {
    rho = 0;
    for (particle: particles) {
        gyroradius = particle.vperp / bmag.gather(particle.y, particle.x);
        for (int i = 0; i < 4; i++) {
            gyropoint = {
                (i == 0 || i == 1) ? particle.y : (i == 2 ? particle.y - gyroradius : particle.y + gyroradius),
                (i == 2 || i == 3) ? particle.x : (i == 0 ? particle.x - gyroradius : particle.x + gyroradius)};
            rho.scatter_charge(gyropoint.y, gyropoint.x);
        }
    }
}