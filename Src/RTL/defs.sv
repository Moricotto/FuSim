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
    typedef struct packed {
        logic [PINT-1:0] whole;
        logic [PFRAC-1:0] fraction;
    } pos_t;

    parameter VPERPWIDTH = 14;
    parameter VPERPFRAC = 12;
    parameter VPERPINT = VPERPWIDTH - VPERPFRAC;
    typedef struct packed {
        logic [VPERPINT-1:0] whole;
        logic [VPERPFRAC-1:0] fraction;
    } vperp_t;
    
    parameter CWIDTH = 36;
    parameter CFRAC = 24;
    parameter CINT = CWIDTH - CFRAC;
    typedef struct packed {
        logic [CINT-1:0] whole;
        logic [CFRAC-1:0] fraction;
    } charge_t;

    typedef logic [GRID_ADDRWIDTH-1:0] addr_t;
    typedef logic [PFRAC*2-1:0] coeff_t;

    // Grid precision parameters
    parameter PHIWIDTH = 35;
    parameter PHIFRAC = 30;
    parameter PHIINT = PHIWIDTH - PHIFRAC;
    typedef struct packed {
        logic signed [PHIINT-1:0] whole;
        logic signed [PHIFRAC-1:0] fraction;
    } phi_t;

    parameter EWIDTH = PHIWIDTH;
    parameter EFRAC = PHIFRAC;
    parameter EINT = EWIDTH - EFRAC;
    typedef struct packed {
        logic signed [EINT-1:0] whole;
        logic signed [EFRAC-1:0] fraction;
    } elect_t;

    parameter BWIDTH = 14;
    parameter BFRAC = 12;
    parameter BINT = BWIDTH - BFRAC;
    typedef struct packed {
        logic [BINT-1:0] whole;
        logic [BFRAC-1:0] frac;
    } bmag_t;

    parameter MUWIDTH = 22;
    parameter MUFRAC = 18;
    parameter MUINT = MUWIDTH - MUFRAC;
    typedef struct packed {
        logic [MUINT-1:0] whole;
        logic [MUFRAC-1:0] frac;
    } mu_t;

    //Composite structures
    typedef struct packed {
        pos_t y, x;
    } posvec_t;

    typedef struct packed {
        posvec_t pos;
        vperp_t vperp;
    } particle_t;

    parameter PSIZE = $bits(particle_t);
    parameter NUM_PARTICLES = 16384;

    //gridpoint address and charge struct
    typedef struct packed {
        logic [GRID_ADDRWIDTH-3:0] addr;
        charge_t charge;
    } scatter_t;

    //distances from particle to gridpoints
    typedef struct packed {
        logic [PFRAC-1:0] y_frac;
        logic [PFRAC-1:0] x_frac;
    } dist_t;

    typedef struct packed {
        elect_t y, x;
    } evec_t;


    const logic [BWIDTH-1:0] BMIN = 14'h3627;

endpackage
