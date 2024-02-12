#generate the binary expansion of a number n < 1

num_bits = 27
def undershoot(n):
    # find the closest binary approximation to n that is less than n
    # and has at most num_bits bits
    if n >= 1:
        return 1
    if n <= 0:
        return 0
    current = 0
    bit = 0.5
    it = 0
    while it < num_bits:
        if current + bit <= n:
            current += bit
        bit /= 2
        it += 1
    return int(current * (2 ** num_bits))

def overshoot(n):
    # find the closest binary approximation to n that is greater than n
    # and has at most num_bits bits
    if n >= 1:
        return 1
    if n <= 0:
        return 0
    current = 1
    bit = 0.5
    it = 0
    while it < num_bits:
        if current - bit >= n:
            current -= bit
        bit /= 2
        it += 1
    return int(current * (2 ** num_bits))

def binexpand(n):
    under = undershoot(n)
    over = overshoot(n)
    # is undershooting always a better approximation than overshooting? 
    # of course not!
    if n - under < over - n:
        return under
    else:
        return over

print(binexpand(0.5443) / (2 ** num_bits))