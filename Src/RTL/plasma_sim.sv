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
// 2. Verify waveforms thouroughly
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
// 2. Fix magnetic field brams, allowing for more sharing and UART hooks - done
// 3. Implement UART hooks and basic procedures like initiating particles, reading out interesting brams, etc. - done
// 4. Implement the UART communication itself - done
import defs::*;

module plasma_sim(
    input logic sys_clk_p,
    input logic sys_clk_n,
    input logic usr_rst,
    input logic rxd_i,
    output logic txd_o,
    output [PSIZE-1:0] data_out,
    output logic [7:0] led
    );

    logic clk;
    logic locked;     
    clk_core clk_gen (
        .reset(usr_rst),
        .locked(locked),
        .clk_in1_p(sys_clk_p),
        .clk_in1_n(sys_clk_n),
        .clk_out1(),
        .clk_out2(clk)
    );
    logic rst;
    assign rst = usr_rst | ~locked;
    logic [31:0] cnt;
    logic [31:0] num_steps;
    logic [31:0] num_particles;
    logic fifo_ready;
    logic start_solve;
    logic first;
    logic ui_done;
    logic ui_valid;
    logic scatter_done;
    logic solver_done;
    logic pusher_done;
    logic rst_scatterer;
    logic rst_pusher;
    logic rst_solver;
    controller master (
        .clk(clk),
        .rst(rst),
        .ui_done(ui_done),
        .scatter_done(scatter_done),
        .pusher_done(pusher_done),
        .solver_done(solver_done),
        .num_steps_in(num_steps),
        .cnt_out(cnt),
        .ui_valid(ui_valid),
        .fifo_ready(fifo_ready),
        .start_solve(start_solve),
        .first(first),
        .rst_scatterer(rst_scatterer),
        .rst_pusher(rst_pusher),
        .rst_solver(rst_solver)
    );

    logic fifo_wen;
    particle_t ui_particle;
    logic bmag_wen;
    addr_t ui_bmag_addr;
    bmag_t ui_bmag;
    logic charge_rd;
    addr_t ui_charge_addr;
    logic charge_rdy;
    charge_t [3:0] charge_out [1:0];
    logic phi_rd;
    addr_t ui_phi_addr;
    logic phi_rdy;
    phi_t [3:0] [2:0] [3:0] phi_out [1:0];
    logic [31:0] ui_go_wdata;
    ui_ui uart_ctl (
        .clk(clk),
        .rst(rst),

        .rxd_i(rxd_i),
        .txd_o(txd_o),
        .saved_rx_data(),

        .ui_particle_wr(fifo_wen),
        .ui_particle_wdata(ui_particle),

        .ui_mag_wr(bmag_wen),
        .ui_mag_addr(ui_bmag_addr),
        .ui_mag_wdata(ui_bmag),

        .ui_chrg_rd(charge_rd),
        .ui_chrg_addr(ui_charge_addr),
        .ui_chrg_rdy(charge_rdy), //charge_rdy
        .ui_chrg_rdata(charge_out[0][0]), //charge_out[0][0]

        .ui_phi_rd(phi_rd),
        .ui_phi_addr(ui_phi_addr),
        .ui_phi_rdy(phi_rdy), //phi_rdy
        .ui_phi_rdata(phi_out[0][0][0][0]), //phi_out[0][0][0][0]

        .ui_go_wr(ui_done),
        .ui_go_wdata(ui_go_wdata)
    );

    always_ff @(posedge clk) begin
        if (ui_done) begin
            num_steps <= ui_go_wdata;
        end
    end

    assign led = cnt[16-:8];

    logic valid_particle;
    logic valid_scatter;
    particle_t particle_in [1:0];    
    particle_t particle_to_scatter [1:0];
    particle_t uart_particle;
    //logic fifo_wen;
    logic cur_fifo;
    always @(posedge clk) begin
        if (rst) begin
            cur_fifo <= 1'b0;
            num_particles <= '0;
        end else if (fifo_wen) begin
            cur_fifo <= ~cur_fifo;
            num_particles <= num_particles + 1;
        end
    end

    particle_fifo fifo0 (
        .wr_rst_busy(),
        .rd_rst_busy(),
        .s_aclk(clk),
        .s_aresetn(~rst),
        .s_axis_tvalid(ui_valid ? fifo_wen & cur_fifo : valid_scatter),
        .s_axis_tready(), //TODO: implement backpressure
        .s_axis_tdata(ui_valid ? {14'b0, ui_particle} : {14'b0, particle_to_scatter[0]}),
        .m_axis_tvalid(valid_particle),
        .m_axis_tready(fifo_ready),
        .m_axis_tdata(particle_in[0])
    );
    particle_fifo fifo1 (
        .wr_rst_busy(),
        .rd_rst_busy(),
        .s_aclk(clk),
        .s_aresetn(~rst),
        .s_axis_tvalid(ui_valid ? fifo_wen & ~cur_fifo : valid_scatter),
        .s_axis_tready(), //TODO: implement backpressure
        .s_axis_tdata(ui_valid ? {14'b0, ui_particle} : {14'b0, particle_to_scatter[1]}),
        .m_axis_tvalid(),
        .m_axis_tready(fifo_ready),
        .m_axis_tdata(particle_in[1])
    );

    assign data_out = particle_in[0] ^ particle_in[1];

    logic valid_scatterer_req;
    addr_t [3:0] charge_raddr [1:0];
    addr_t [3:0] ui_full_charge_addr [1:0];
    assign ui_full_charge_addr = {{ui_charge_addr, '0, '0, '0}, '0};
    full_scatterer scatterer (
        .clk(clk),
        .rst(rst_scatterer),
        .valid_scatter(valid_scatter),
        .num_particles(num_particles),
        .particle_in(particle_to_scatter),
        .done(scatter_done),
        .valid_req(ui_valid ? charge_rd : valid_scatterer_req),
        .grid_addr_in(ui_valid ? ui_full_charge_addr : charge_raddr),
        .charge_rdy(charge_rdy),
        .charge_out(charge_out),
        .ui_valid(ui_valid),
        .wen(bmag_wen),
        .addr_in(ui_bmag_addr),
        .bmag_in(ui_bmag)
    );

    logic valid_solver_req;
    addr_t [3:0] [2:0] [3:0] phi_raddr [1:0];
    addr_t [3:0] [2:0] [3:0] ui_full_phi_addr [1:0];
    assign ui_full_phi_addr = '{default:ui_phi_addr};
    full_solver solver (
        .clk(clk),
        .rst(rst_solver),
        .start(start_solve),
        .done(solver_done),
        .charges(charge_out),
        .valid_req_out(valid_scatterer_req),
        .charge_raddr(charge_raddr),
        .phi_raddr_in(ui_valid ? ui_full_phi_addr : phi_raddr),
        .valid_req(ui_valid ? phi_rd : valid_solver_req),
        .phi_rdy(phi_rdy),
        .phi_out(phi_out),

        //to/from UART, to set gyroradius BRAMs
        .ui_valid(ui_valid),
        .wen(bmag_wen),
        .addr_in(ui_bmag_addr),
        .bmag_in(ui_bmag)
    );

    full_pusher pusher (
        .clk(clk),
        .rst(rst_pusher),
        .valid(valid_particle & fifo_ready),
        .num_particles(num_particles),
        .noop(first),
        .particle_in(particle_in),
        .done(pusher_done),
        .phi_in(phi_out),
        .valid_req_out(valid_solver_req),
        .raddr(phi_raddr),
        .valid_out(valid_scatter),
        .particle_out(particle_to_scatter),
        .ui_valid(ui_valid),
        .wen(bmag_wen),
        .addr_in(ui_bmag_addr),
        .bmag_in(ui_bmag)
    );
endmodule