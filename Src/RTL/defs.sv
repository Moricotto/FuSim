`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/24/2023 11:44:09 AM
// Design Name: 
// Module Name: 
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

package defs;
    //Grid parameters
    parameter NUM_ROWS = 64;
    parameter NUM_COLS = 64;
    parameter NUM_CELLS = NUM_ROWS * NUM_COLS;
    parameter GRID_ADDRWIDTH = $clog2(NUM_CELLS);

    // Particle precision parameters
    parameter PWIDTH = 18;
    parameter PFRAC = PWIDTH - $clog2(NUM_ROWS);
    parameter PINT = PWIDTH - PFRAC;
    parameter VPARWIDTH = 12;
    parameter VPARFRAC = 7;
    parameter VPERPWIDTH = 14;
    parameter VPERPFRAC = 12;
    parameter WWIDTH = 12;
    parameter WFRAC = 7;
    parameter CWIDTH = 36;
    parameter CFRAC = 24;
    parameter CINT = CWIDTH - CFRAC;
    // Grid precision parameters
    parameter PHIWIDTH = 35;
    parameter PHIFRAC = 30;
    parameter EWIDTH = PHIWIDTH;
    parameter EFRAC = PHIFRAC;
    parameter BWIDTH = 14;
    parameter BFRAC = 12;
    parameter MUWIDTH = 22;
    parameter MUFRAC = 18;
    const logic [BWIDTH-1:0] BMIN = 14'h3627;
    const logic signed [24:0] DIAG_CONST = 25'shf9a9;
    const logic [24:0] INV_OMEGA = 25'b0101010101010101010101010;
    const logic [24:0] OMEGA = 25'b1010101010101010101010101;
    //number of delta functions used to discretise maxwellian in order to solve poisson equation
    parameter NUM_DELTA = 3;
    const logic [NUM_DELTA-1:0] [23:0] VWEIGHTS = {24'b010000000000000000000000, 24'b100000000000000000000000, 24'b010000000000000000000000};
    //number of grid solvers instantiated
    parameter NUM_SOLVERS = 1;
    //number of iterations performed to solve for phi
    parameter NUM_IT = 2;
    // Particle struct
    typedef struct packed {
        logic [PWIDTH-1:0] y, x;
        //logic [VPARWIDTH-1:0] vpar;
        logic [VPERPWIDTH-1:0] vperp;
        //logic [WWIDTH-1:0] weight;
    } particle_t;

    parameter PSIZE = $bits(particle_t);
    parameter NUM_PARTICLES = 16384;
    
    typedef struct packed {
        logic [PWIDTH-1:0] y, x;
    } pos_t;

    //gridpoint address and charge struct
    typedef struct packed {
        logic [GRID_ADDRWIDTH-3:0] addr;
        logic [CWIDTH-1:0] charge;
    } scatter_t;

    //distances from particle to gridpoints
    typedef struct packed {
        logic [PFRAC-1:0] y_frac;
        logic [PFRAC-1:0] x_frac;
    } dist_t;

    typedef enum logic [1:0] {
        SCATTER,
        SOLVE
    } step_t;

    typedef struct packed {
        logic signed [EWIDTH-1:0] y;
        logic signed [EWIDTH-1:0] x;
    } efield_t;

endpackage
