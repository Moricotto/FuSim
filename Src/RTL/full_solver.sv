`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/29/2023 11:33:44 PM
// Design Name: 
// Module Name: full_solver
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Combines two grid solvers together and connects them to the correct grid memories. 
// Also has logic that allows the pusher to fetch values phi 
// Dependencies: grid_solver, grid_mem
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

import defs::*;
//TODO: implement communication with pusher
module full_solver(
    input logic clk,
    input logic rst,
    //control signals
    input logic start,
    output logic done,

    //to/from scatterer
    input charge_t [3:0] charges [1:0],
    output logic valid_req_out,
    output addr_t [3:0] charge_raddr [1:0],
    
    //to/from pusher
    input addr_t [3:0] [2:0] [3:0] phi_raddr_in [1:0],
    input logic valid_req,
    output phi_t [3:0] [2:0] [3:0] phi_out [1:0]
    );
    
    logic in_progress;
    logic sel;
    logic final_sel;
    logic [3:0] num_it;
    addr_t grid_addr; //adress of grid point currently being solved for
    addr_t gyro_addr; //address into gyroradius brams
    pos_t [NUM_DELTA-1:0] gyroradius; //gyroradius for each delta function
    addr_t [NUM_DELTA-1:0] [7:0] [3:0] phi_raddr; //addresses for reading phi
    phi_t [NUM_DELTA-1:0] [7:0] [3:0] prev_phi [1:0]; //phi values read from grid memories
    logic valid_out; //valid signal from grid solver
    phi_t new_phi; //value of phi to be written to grid memory
    addr_t phi_waddr; //address to which the new value of phi is written
    

    assign charge_raddr[0][1] = '0;
    assign charge_raddr[0][2] = '0;
    assign charge_raddr[0][3] = '0;
    assign charge_raddr[1][0] = '0;
    assign charge_raddr[1][1] = '0;
    assign charge_raddr[1][2] = '0;
    assign charge_raddr[1][3] = '0;
    //module instantiation
    grid_solver solver0 (
        .clk(clk),
        .rst(rst),
        .valid(in_progress),
        .grid_addr(grid_addr),
        .gyro_addr(gyro_addr),
        .gyroradius(gyroradius),
        .valid_out(valid_out),
        .raddr_out(phi_raddr),
        .prev_in(prev_phi[~sel]),
        .waddr_out(phi_waddr),
        .phi_out(new_phi),
        .valid_req(valid_req_out),
        .charge_addr(charge_raddr[0][0]),
        .charge_in(charges[0][0])

    );

    //instantion of gyroradius brams
    generate;
        for (genvar v = 0; v < NUM_DELTA; v++) begin
            gyro_mem (
                .clka(clk),
                .ena(1'b1),
                .wea(1'b0),
                .addra(gyro_addr),
                .dina('0),
                .douta(gyroradius[v]),
                //reserved for future use by second solver
                .clkb(clk),
                .enb(1'b0),
                .web(1'b0),
                .addrb('0),
                .dinb('0),
                .doutb('0)
            );
        end
    endgenerate;
    //1 grid solver
    //each grid solver requires 2 groups of 4 * 3 grid memories, one to read to and on to write to
    //each grid memory requires 4 brams, for a total of 96 brams
    generate;
        for (genvar v = 0; v < NUM_DELTA; v++) begin
            for (genvar j = 0; j < 4; j++) begin
                for (genvar k = 0; k < 2; k++) begin
                    grid_mem #(.WIDTH(PHIWIDTH), .NO_RST(1)) phi_mem (
                        .clk(clk),
                        .rst(rst),
                        .swap_rout(1'b1),
                        .wea((sel == k && in_progress) ? valid_out : 4'b0),
                        .web(4'b0),
                        .addra(in_progress ? (sel == k ? {'0, '0, '0, phi_waddr} : phi_raddr[v][j]) : phi_raddr_in[0][j][v]),
                        .addrb(in_progress ? phi_raddr[v][j+4] : phi_raddr_in[1][j][v]),
                        .dina({'0, '0, '0, new_phi}),
                        .dinb('0),
                        .douta(prev_phi[k][v][j]),
                        .doutb(prev_phi[k][v][j+4]),
                        .swapped_addra(),
                        .swapped_addrb()
                    );
                end
                assign phi_out[0][j][v] = prev_phi[final_sel][v][j];
                assign phi_out[1][j][v] = prev_phi[final_sel][v][j+4];
            end
        end
    endgenerate

    always_ff @(posedge clk) begin
        if (rst) begin
            in_progress <= 1'b0;
            done <= 1'b0;
            num_it <= '0;
            sel <= 1'b0;
            final_sel <= 1'b0;
            grid_addr <= 12'h0;
        end else begin
            if (start) begin
                in_progress <= 1'b1;
            end else if (in_progress) begin
                if (grid_addr == 12'hFFF) begin
                    grid_addr <= 12'h0;
                    if (num_it == NUM_IT - 1) begin
                        in_progress <= 1'b0;
                        done <= 1'b1;
                        grid_addr <= 12'h0;
                        num_it <= '0;
                        final_sel <= sel;
                    end else begin
                        num_it  <= num_it + 1;
                        sel <= ~sel;
                    end
                end else begin
                    grid_addr <= grid_addr + 1;
                end
            end 
        end
    end
endmodule
