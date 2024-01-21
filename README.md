# FuSim

## Overview

FuSim is the first system that performs a full simulation the behaviour of a plasma in the presence of a strong magnetic field using an FPGA-based hardware implementation. It also contains a software implementation that mimics the hardware. The use of the FPGA technology allows for a more power-efficient and cheaper simulation than conventional solutions that use servers or supercomputers.  

## Details of the Simulator
The simulator performs a 2d gyrokinetic PIC simulation of charged ions using the adiabiatic electron approximation. It uses simple linear interpolation to the 4 nearest gridpoints for the scatter and gather operations, a Jacobi solver to find the electric potential (as per Lin & Lee, 1995, with three values of the perpendicular velocity), and a simple explicit Euler method to advance the simulation in time. It uses a 2d grid of 64x64 points.

## Hardware Implementation

The hardware implementation of FuSim is based on an FPGA (Field-Programmable Gate Array). The FPGA is programmed to implement the full PIC simulation, including setup, simulation, and analysis. The FPGA is connected to a host computer via a USB-UART interface, which allows the user to control the simulation, monitor its progress, and analyze the results. The FPGA can simulate up to 4096 gridpoints and 16384 particles. The FPGA is programmed using the Verilog HDL, and simulated and synthesized using the Xilinx Vivado Design Suite.

## Software Implementation

The software implementation of FuSim complements the hardware implementation by providing a user-friendly and intuitive way to validate the results of the FPGA. It reimplements the behaviour of the FPGA down to the precision of the fixed-point numbers used in the FPGA. It also provides a way to visualize the results of the simulation, be it in hardware of software. The software implementation is written in C++ and uses the SFML framework for the GUI.

## Results

The FPGA implementation of the simulator allows for a 400x increase in power efficiency and 80x the performance per dollar, allowing for faster turnaround times for simulations and greater availability of simulation-capable hardware.
