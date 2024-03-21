import matplotlib.pyplot as plt
import numpy as np
import matplotlib.animation as animation

N = 64
M = 64
FRAMES = 500

charge = np.empty((FRAMES, N, M), dtype=np.int64)
efield = np.empty((FRAMES, N, M, 2), dtype=np.int64)
for i in range(FRAMES):
    cframe = np.fromfile('C://Users//Jonah//Documents//Projects//Fusim//Software//data//rho' + str(i) + ".txt", dtype=np.int64, sep=",")
    cframe.resize(N, M)
    charge[i] = cframe
    eframe = np.fromfile('C://Users//Jonah//Documents//Projects//Fusim//Software//data//efield' + str(i) + ".txt", dtype=np.int64, sep=",")
    eframe.resize(N, M, 2)
    efield[i] = eframe

charge = charge / np.max(charge)
efield = efield / np.max(efield)

fig, ax = plt.subplots(1, 2)
Y, X = np.arange(0, 64, 1), np.arange(0, 64, 1)
colormap = plt.cm.Wistia
ims = []
for i in range(FRAMES):
    im0 = ax[0].imshow(charge[i], cmap='plasma', animated=True)
    if (i == 0):
        im0 = ax[0].imshow(charge[i], cmap='plasma',)
    ax[0].set_yticks(np.arange(0, N, 8))
    ax[0].set_xticks(np.arange(0, M, 8))
    ax[0].set_title("Densité de charge")
    ax[0].set_ylabel("y")
    ax[0].set_xlabel("x")
    colors = np.sqrt(efield[i, ::3, ::3, 0]**2 + efield[i, ::3, ::3, 1]**2)
    colors.resize(22*22)
    im1 = ax[1].quiver(Y[::3], X[::3], efield[i, ::3, ::3, 0], efield[i, ::3, ::3, 1], scale=0.25, scale_units='xy', color=colormap(colors), animated=True)
    if (i == 0):
        im1 = ax[1].quiver(Y[::3], X[::3], efield[i, ::3, ::3, 0], efield[i, ::3, ::3, 1], scale=0.25, scale_units='xy', color=colormap(colors),)
    ax[1].set_yticks(np.arange(0, N, 8))
    ax[1].set_xticks(np.arange(0, M, 8))
    ax[1].set_title("Champ électrique")
    ax[1].set_ylabel("y")
    ax[1].set_xlabel("x")
    ims.append([im0, im1])

ani = animation.ArtistAnimation(fig, ims, interval=1, blit=True, repeat_delay=1000)
plt.show()