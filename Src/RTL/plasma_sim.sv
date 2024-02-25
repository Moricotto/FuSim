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
// 9. reorganise pusher-solver communications to save BRAM - done
// 10. Generalise and parameterise to allow for greater scalabilty on larger FPGAs
// 11. Implement proper boundary checking and conditions (especially in phi solver) - done
// 12. Add DRAM and DRAM controller to allow for more particles

//More short term TODO:
// 1. Verify simulation against software implementation
// 2. Fix magnetic field brams, allowing for more sharing and UART hooks
// 3. Implement UART hooks and basic procedures like initiating particles, reading out interesting brams, etc.
// 4. Implement the UART communication itself
import defs::*;

module plasma_sim(
    input logic sys_clk_p,
    input logic sys_clk_n,
    input logic usr_rst,
    output [PSIZE-1:0] data_out,
    output logic [7:0] led  
    );

    logic clk;     
    clk_core clk_gen (
        .clk_in1_p(sys_clk_p),
        .clk_in1_n(sys_clk_n),
        .clk_out1(clk),
        .clk_out2()
    );

    logic [31:0] cnt;
    logic fifo_ready;
    logic start_solve;
    logic first;
    logic scatter_done;
    logic solver_done;
    logic pusher_done;
    logic rst_scatterer;
    logic rst_pusher;
    logic rst_solver;
    controller master (
        .clk(clk),
        .rst(usr_rst),
        .ui_done(1'b1),
        .scatter_done(scatter_done),
        .pusher_done(pusher_done),
        .solver_done(solver_done),
        .cnt(cnt),
        .fifo_ready(fifo_ready),
        .start_solve(start_solve),
        .first(first),
        .rst_scatterer(rst_scatterer),
        .rst_pusher(rst_pusher),
        .rst_solver(rst_solver)
    );

    assign led = cnt[15-:8];

    logic valid_particle;
    particle_t particle_in [1:0];
    particle_fifo fifo0 (
        .wr_rst_busy(),
        .rd_rst_busy(),
        .s_aclk(clk),
        .s_aresetn(usr_rst),
        .s_axis_tvalid(valid_scatter),
        .s_axis_tready(), //TODO: implement backpressure
        .s_axis_tdata(particle_to_scatter[0]),
        .m_axis_tvalid(valid_particle),
        .m_axis_tready(fifo_ready),
        .m_axis_tdata(particle_in[0])
    );
    particle_fifo fifo1 (
        .wr_rst_busy(),
        .rd_rst_busy(),
        .s_aclk(clk),
        .s_aresetn(usr_rst),
        .s_axis_tvalid(valid_scatter),
        .s_axis_tready(), //TODO: implement backpressure
        .s_axis_tdata(particle_to_scatter[1]),
        .m_axis_tvalid(),
        .m_axis_tready(fifo_ready),
        .m_axis_tdata(particle_in[1])
    );

    assign data_out = particle_in[0] ^ particle_in[1];
    
    logic valid_scatter;
    logic valid_scatterer_req;
    particle_t particle_to_scatter [1:0];
    addr_t [3:0] charge_raddr [1:0];
    charge_t [3:0] charge_out [1:0];
    full_scatterer scatterer (
        .clk(clk),
        .rst(rst_scatterer),
        .valid_scatter(valid_scatter),
        .particle_in(particle_to_scatter),
        .done(scatter_done),
        .valid_req(valid_scatterer_req),
        .grid_addr_in(charge_raddr),
        .charge_out(charge_out)
    );

    logic valid_solver_req;
    addr_t [3:0] [2:0] [3:0] phi_raddr [1:0];
    phi_t [3:0] [2:0] [3:0] phi_out [1:0];
    full_solver solver (
        .clk(clk),
        .rst(rst_solver),
        .start(start_solve),
        .done(solver_done),
        .charges(charge_out),
        .valid_req_out(valid_scatterer_req),
        .charge_raddr(charge_raddr),
        .phi_raddr_in(phi_raddr),
        .valid_req(valid_solver_req),
        .phi_out(phi_out)
    );

    full_pusher pusher (
        .clk(clk),
        .rst(rst_pusher),
        .valid(valid_particle),
        .noop(first),
        .particle_in(particle_in),
        .done(pusher_done),
        .phi_in(phi_out),
        .valid_req_out(valid_solver_req),
        .raddr(phi_raddr),
        .valid_out(valid_scatter),
        .particle_out(particle_to_scatter)
    );
endmodule