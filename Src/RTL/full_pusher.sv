`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/02/2023 11:34:40 PM
// Design Name: 
// Module Name: full_pusher
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


module full_pusher (
    input logic clk,    
    input logic rst,
    //to/from top level module
    input logic valid,
    input logic noop, 
    input particle_t particle_in [1:0],
    output logic done,
    //to/from solver
    input phi_t [3:0] [2:0] [3:0] phi_in [1:0],
    output logic valid_req_out,
    output addr_t [3:0] [2:0] [3:0] raddr [1:0],
    //to/from scatterer
    output logic valid_out,
    output particle_t particle_out [1:0]

    //to/from UART
    input logic ui_valid,
    input logic wen,
    input addr_t addr_in,
    input bmag_t bmag_in
    );

    //set up bmag grid brams so that they can be read by the pusher
    //each pusher needs to read from 3 groups of 4 brams
    //each bram has two ports, so both pushers can read from the same bram at the same time
    bmag_t [3:0] [2:0] [3:0] bmag_out [1:0];
    generate
        for (genvar i = 0; i < 3; i++) begin
            for (genvar j = 0; j < 4; j++) begin
                grid_mem #(.WIDTH(BWIDTH)) bmag_grid (
                    .clk(clk),
                    .rst(rst),
                    .swap_rout(1'b1),
                    .wea(ui_valid ? 4'b1 : 4'b0),
                    .web(4'b0),
                    .addra(raddr[0][i][j]),
                    .addrb(raddr[1][i][j]),
                    .dina('0),
                    .dinb('0),
                    .douta(bmag_out[0][i][j]),
                    .doutb(bmag_out[1][i][j]),
                    .swapped_addra(),
                    .swapped_addrb()
                );
            end
        end
    endgenerate


    pusher pusher0 (
        .clk(clk),
        .rst(rst),
        .valid(valid),
        .noop(noop),
        .done(done),
        .particle_in(particle_in[0]),
        .valid_out(valid_out),
        .particle_out(particle_out[0]),
        .phi_in(phi_in[0]),
        .bmag_in(bmag_out[0]),
        .valid_req(valid_req_out),
        .raddr(raddr[0])
    );

    
    pusher pusher1 (
        .clk(clk),
        .rst(rst),
        .valid(valid),
        .noop(noop),
        .done(),
        .particle_in(particle_in[1]),
        .particle_out(particle_out[1]),
        .phi_in(phi_in[1]),
        .bmag_in(bmag_out[1]),
        .valid_req(),
        .raddr(raddr[1])
    );


endmodule
