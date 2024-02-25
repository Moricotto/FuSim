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
    parameter NUM_DELTA = 3; //number of delta functions used to discretise maxwellian in order to solve poisson equation
    parameter NUM_IT = 8;
    parameter SLOWDOWN = 4; //amount to shift by in order to reduce the amount each particle moves per iteration


    // Particle precision parameters
    parameter PWIDTH = 18;
    parameter PFRAC = PWIDTH - $clog2(NUM_ROWS);
    parameter PINT = $clog2(NUM_ROWS);
    typedef struct packed {
        logic [PWIDTH-1:PFRAC] whole;
        logic [PFRAC-1:0] fraction;
    } pos_t;

    parameter VPERPWIDTH = 14;
    parameter VPERPFRAC = 12;
    parameter VPERPINT = VPERPWIDTH - VPERPFRAC;
    typedef struct packed {
        logic [VPERPWIDTH-1:VPERPFRAC] whole;
        logic [VPERPFRAC-1:0] fraction;
    } vperp_t;
    
    parameter CWIDTH = 36;
    parameter CFRAC = 24;
    parameter CINT = CWIDTH - CFRAC;
    typedef struct packed {
        logic [CWIDTH-1:CFRAC] whole;
        logic [CFRAC-1:0] fraction;
    } charge_t;

    typedef struct packed {
        logic [GRID_ADDRWIDTH-1:PINT] y;
        logic [PINT-1:0] x;
    } addr_t; 

    typedef logic [PFRAC*2-1:0] coeff_t;

    typedef struct packed signed {
        logic [23:20] whole;
        logic [19:0] fraction;
    } const_t;
    // Grid precision parameters
    parameter PHIWIDTH = 35;
    parameter PHIFRAC = 27;
    parameter PHIINT = PHIWIDTH - PHIFRAC;
    typedef struct packed signed {
        logic [PHIWIDTH-1:PHIFRAC] whole;
        logic [PHIFRAC-1:0] fraction;
    } phi_t;

    parameter EWIDTH = PHIWIDTH;
    parameter EFRAC = PHIFRAC;
    parameter EINT = EWIDTH - EFRAC;
    typedef struct packed signed {
        logic [EWIDTH-1:EFRAC] whole;
        logic [EFRAC-1:0] fraction;
    } elect_t;

    parameter BWIDTH = 14;
    parameter BFRAC = 12;
    parameter BINT = BWIDTH - BFRAC;
    typedef struct packed {
        logic [BWIDTH-1:BFRAC] whole;
        logic [BFRAC-1:0] frac;
    } bmag_t;

    typedef struct packed signed {
        logic [BWIDTH:BFRAC] whole; //add one bit for sign
        logic [BFRAC-1:0] frac;
    } gradb_t;

    parameter MUWIDTH = VPERPINT*2+BFRAC+PFRAC;
    parameter MUFRAC = PFRAC;
    parameter MUINT = MUWIDTH - MUFRAC;
    typedef struct packed {
        logic [MUWIDTH-1:MUFRAC] whole;
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

    //distances from particle to gridpoints
    typedef struct packed {
        logic [PFRAC*2-1:PFRAC] y_frac;
        logic [PFRAC-1:0] x_frac;
    } dist_t;

    typedef struct {
        elect_t y, x;
    } evec_t;

    typedef struct {
        gradb_t y, x;
    } gradbvec_t;


    const logic [BWIDTH-1:0] BMIN = 14'h3627;

endpackage
