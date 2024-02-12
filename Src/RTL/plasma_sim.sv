`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/22/2023 07:27:27 PM
// Design Name: 
// Module Name: plasma_sim_main
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

//`default_nettype none

//TODO: 
// 1. Instantiate and connect DRAM controller
// 2. Verify waveforms for full_pusher thouroughly
// 3. Write more equivalent software to perform rigorous comparisons - done
// 4. Add more interactive ui through UART connection, allowing for heatmaps and convergence graphs
// 5. Connect multiple FPGA together to prove scalability
// 6. Extend to 3d simulation
// 7. Weight jacobi iterations for faster convergence
// 8. Implement difference between two and four point interpolators to save BRAM and DSPs
// 9. reorganise pusher-solver communications to save BRAM
// 10. Generalise and parameterise to allow for greater scalabilty on larger FPGAs
// 11. Implement proper boundary checking and conditions (especially in phi solver)
// 12. Add DRAM and DRAM controller to allow for more particles
import defs::*;

module plasma_sim(
    input logic sys_clk_p,
    input logic sys_clk_n,
    input logic rst,
    output [PSIZE-1:0] data_out,
    output logic [7:0] led  
    );
    
    //resets
    logic rst_scatter;
    logic rst_pusher;
    logic rst_solver;
    //valid and ready signals
    logic valid_scatter;
    logic solver_go;
    logic pusher_ready;


    //addrs for requests
    addr_t [3:0] charge_req_addr [1:0];

    //data signals
    particle_t particle_in [1:0]; // from fifo
    particle_t pushed_particle [1:0]; // from pusher
    charge_t [3:0] requested_charge [1:0]; // to solver

    // Instantiate and connect scatterer
    full_scatterer scatterer (
        .clk(clk),
        .rst(rst_scatter),
        //from pusher
        .valid_scatter(valid_scatter),
        .particle_in(pushed_particle),
        //from solver
        .valid_req(solver_go),
        .grid_addr_in(charge_req_addr),
        //to solver
        .charge_out(requested_charge)
    );
        
endmodule