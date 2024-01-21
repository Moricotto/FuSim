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
    
    /*lfsr #(.WIDTH(PWIDTH)) xpos_gen0 (
        .clk(clk),
        .rst(rst),
        .data(particle_in[0].x)
    );

    lfsr #(.WIDTH(PWIDTH), .INIT(16'h32e9)) ypos_gen0 (
        .clk(clk),
        .rst(rst),
        .data(particle_in[0].y)
    );

    lfsr #(.WIDTH(VPERPWIDTH), .INIT(16'h29c2)) vperp_gen0 (
        .clk(clk),
        .rst(rst),
        .data(particle_in[1].vperp)
    );

    lfsr #(.WIDTH(PWIDTH)) xpos_gen1 (
        .clk(clk),
        .rst(rst),
        .data(particle_in[1].x)
    );

    lfsr #(.WIDTH(PWIDTH), .INIT(16'h32e9)) ypos_gen1 (
        .clk(clk),
        .rst(rst),
        .data(particle_in[1].y)
    );

    lfsr #(.WIDTH(VPERPWIDTH), .INIT(16'h29c2)) vperp_gen1 (
        .clk(clk),
        .rst(rst),
        .data(particle_in[1].vperp)
    );*/

    step_t step;
    logic [3:0] [CWIDTH-1:0] charges [1:0];
    logic [GRID_ADDRWIDTH-1:0] charge_raddr [1:0];
    logic valid_charge_req;

    logic rst_scatter;
    logic rst_solve;
    logic rst_push;
    logic init_tlast;
    logic fifo_tlast;
    logic tlast_in;
    logic push_tlast;
    logic start_solve;
    logic valid_fifo_out;
    logic valid_push;
    logic valid_push_out;
    logic scatter_tlast;
    logic signed [3:0] [3:0] [3:0] [PHIWIDTH-1:0] phi_val [1:0];
    logic [3:0] [3:0] [GRID_ADDRWIDTH-1:0] phi_raddr [1:0];
    logic valid_phi_req;
    logic first;

    logic solve_done;
    logic ready;

    logic [15:0] count;

    assign led = count[15-:8];

    particle_t fifo_out [1:0];
    particle_t init_out [1:0];
    particle_t particle_in [1:0];
    particle_t particle_out [1:0];

    assign particle_in[0] = first ? init_out[0] : fifo_out[0];
    assign particle_in[1] = first ? init_out[1] : fifo_out[1];
    assign data_out = particle_out[0] ^ particle_out[1];
    assign tlast_in = first ? init_tlast : fifo_tlast;
    assign valid_push = first | valid_fifo_out;
    
    logic usr_clk;

    IBUFDS sys_clk_ibuf (
        .O(usr_clk),
        .I(sys_clk_p),
        .IB(sys_clk_n)
    );

    clk_core core (
        // Clock out ports
        .clk_out1(),     // output clk_out1
        .clk_out2(clk),     // output clk_out2
        // Clock in ports
        .clk_in1(usr_clk),    // input clk_in1_p
        //reset
        .reset(rst)
    );

    particle_fifo fifo0 (
        .wr_rst_busy(),      // output wire wr_rst_busy
        .rd_rst_busy(),      // output wire rd_rst_busy
        .s_aclk(clk),                // input wire s_aclk
        .s_aresetn(~rst),          // input wire s_aresetn
        .s_axis_tvalid(valid_push_out),  // input wire s_axis_tvalid
        .s_axis_tready(),  // output wire s_axis_tready
        .s_axis_tdata({14'b0, particle_out[0]}),    // input wire [63 : 0] s_axis_tdata
        .m_axis_tvalid(valid_fifo_out),  // output wire m_axis_tvalid
        .m_axis_tready(ready),  // input wire m_axis_tready
        .m_axis_tdata(fifo_out[0])    // output wire [63 : 0] m_axis_tdata
    );

    particle_fifo fifo1 (
        .wr_rst_busy(),      // output wire wr_rst_busy
        .rd_rst_busy(),      // output wire rd_rst_busy
        .s_aclk(clk),                // input wire s_aclk
        .s_aresetn(~rst),          // input wire s_aresetn
        .s_axis_tvalid(valid_push_out),  // input wire s_axis_tvalid
        .s_axis_tready(),  // output wire s_axis_tready
        .s_axis_tdata({14'b0, particle_out[1]}),    // input wire [63 : 0] s_axis_tdata
        .m_axis_tvalid(),  // output wire m_axis_tvalid
        .m_axis_tready(ready),  // input wire m_axis_tready
        .m_axis_tdata(fifo_out[1])    // output wire [63 : 0] m_axis_tdata
    );

    initialiser init0 (
        .clk(clk),
        .rst(rst),
        .tlast_out(init_tlast),
        .particle_out(init_out[0])
    );

    initialiser init1 (
        .clk(clk),
        .rst(rst),
        .tlast_out(),
        .particle_out(init_out[1])
    );

    controller controller (
        .clk(clk),
        .rst(rst),
        .valid_fifo(valid_fifo_out),
        .calib_complete(1'b1),
        .scatter_done(scatter_tlast),
        .solve_done(solve_done),
        .rst_scatter(rst_scatter),
        .rst_solve(rst_solve),
        .rst_push(rst_push),
        .ready_out(ready),
        .start_solve(start_solve),
        .fifo_tlast(fifo_tlast),
        .step(step),
        .first(first)
    );

    full_scatterer scatterer (
        .clk(clk),
        .rst(rst_scatter),
        .step(step),
        .valid_scatter(valid_push_out),
        .tlast_in(push_tlast),
        .particle_in(particle_out),
        .tlast_out(scatter_tlast),
        .valid_req(valid_charge_req),
        .grid_addr_in(charge_raddr),
        .charge_out(charges)
    );

    assign charge_raddr[1] = '0;
    full_solver solver (
        .clk(clk),
        .rst(rst_solve),
        .step(step),
        .start(start_solve),
        .charges(charges[0][0]),
        .charge_raddr(charge_raddr[0]),
        .done(solve_done),
        .valid_req_out(valid_charge_req),
        .valid_req(valid_phi_req),
        .phi_raddr_in(phi_raddr),
        .phi_val(phi_val)
    );


    full_pusher pusher (
        .clk(clk),
        .rst(rst_push),
        .valid(valid_push),
        .noop(first),
        .tlast_in(tlast_in),   
        .particle_in(particle_in),
        .phi_in(phi_val),
        .valid_req_out(valid_phi_req),
        .raddr(phi_raddr),
        .valid_out(valid_push_out),
        .tlast_out(push_tlast),
        .particle_out(particle_out)
   );


    always_ff @(posedge clk) begin
       if (rst) begin
            count <= '0;
        end else if (push_tlast) begin
            count <= count + 1;
        end                       
    end

endmodule