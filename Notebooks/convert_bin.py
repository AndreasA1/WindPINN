# convert binary output files from MannTurb into other file type
import os
import numpy as np
import matplotlib.pyplot as plt


# read data from files, returns 3 np arrays of size Nx by Ny by Nz
def read_bin():
    # read data from files
    abs_path = os.path.dirname(__file__)
    rel_path = "../MannTurb/test_u.bin"
    file_path = os.path.join(abs_path, rel_path)

    f = open(os.path.join(abs_path, "../MannTurb/test_u.bin"), "r")
    in_u = np.fromfile(f, dtype=np.int32)
    f = open(os.path.join(abs_path, "../MannTurb/test_v.bin"), "r")
    in_v = np.fromfile(f, dtype=np.int32)
    f = open(os.path.join(abs_path, "../MannTurb/test_w.bin"), "r")
    in_w = np.fromfile(f, dtype=np.int32)

    # print(np.shape(in_u))
    # print(np.shape(in_v))
    # print(np.shape(in_w))

    # convert files to velocity slices
    # points in each direction
    Nx = 4096
    Ny = 32
    Nz = 32
    slice_pts = Ny*Nz

    data_u = np.zeros((Nx, Ny, Nz))
    data_v = np.zeros((Nx, Ny, Nz))
    data_w = np.zeros((Nx, Ny, Nz))

    for i in range(int(np.size(in_u)/(slice_pts))):
        data_u[i,:,:] = np.reshape(in_u[i*slice_pts:(i+1)*slice_pts], (Ny, Nz))
        data_v[i,:,:] = np.reshape(in_v[i*slice_pts:(i+1)*slice_pts], (Ny, Nz))
        data_w[i,:,:] = np.reshape(in_w[i*slice_pts:(i+1)*slice_pts], (Ny, Nz))

    return data_u, data_v, data_w


# plot
def plot_v_fields(data_u, data_v, data_w, x_pos):
    Ny = 32
    Nz = 32

    # plot for visualization
    y = np.linspace(-1, 1, Ny)
    z = np.linspace(-1, 1, Nz)
    Y, Z = np.meshgrid(y, z)

    index = x_pos
    fig, (ax1, ax2, ax3) = plt.subplots(1,3)

    # fig1, = plt.subplot(1, 3, 1)
    ax1.contourf(Y, Z, data_u[index, :, :])
    # fig1.colorbar(cp1)  # Add a colorbar to a plot
    ax1.set_title('u')

    # fig2, = plt.subplot(1, 3, 2)
    ax2.contourf(Y, Z, data_v[index, :, :])
    # fig2.colorbar(cp2)  # Add a colorbar to a plot
    ax2.set_title('v')

    # fig3, = plt.subplot(1, 3, 3)
    ax3.contourf(Y, Z, data_w[index, :, :])
    # fig3.colorbar(cp3)  # Add a colorbar to a plot
    ax3.set_title('w')

    plt.show()