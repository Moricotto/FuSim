`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/02/2023 11:34:40 PM
// Design Name: 
// Module Name: controller
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
import defs::*;

module controller (
    input logic clk,
    input logic rst,
    input logic valid_fifo,
    input logic calib_complete,
    input logic scatter_done,
    input logic solve_done,
    output logic rst_scatter,
    output logic rst_solve,
    output logic rst_push, 
    output logic start_solve,
    output logic ready_out,
    output logic fifo_tlast,
    output step_t step,
    output logic first
    );

    typedef enum {
        CALIB,
        PUSH_SCATTER,
        RST_SOLVE,
        SOLVER,
        RST_PUSH_SCATTER
    } state_t;

    state_t state;
    logic ready;
    logic [$clog2(NUM_PARTICLES)-1:0] particle_count;

    assign ready_out = ready;

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= CALIB;
            step <= SCATTER;
            rst_scatter <= 1'b1;
            rst_solve <= 1'b1;
            rst_push <= 1'b1;
            first <= 1'b1;
            fifo_tlast <= 1'b0;
            ready <= 1'b0;
            particle_count <= '0;
        end else begin
            case (state) 
                CALIB: begin
                    rst_scatter <= 1'b1;
                    rst_solve <= 1'b1;
                    rst_push <= 1'b1;
                    start_solve <= 1'b0;
                    first <= 1'b1;
                    if (calib_complete) begin
                        rst_scatter <= 1'b0;
                        rst_solve <= 1'b0;
                        rst_push <= 1'b0;
                        ready <= 1'b1;
                        state <= PUSH_SCATTER;
                        step <= SCATTER;
                    end
                end
                PUSH_SCATTER: begin
                    if (valid_fifo & ready) begin
                        particle_count <= particle_count + 1;
                    end
                    if (particle_count == NUM_PARTICLES - 2) begin
                        fifo_tlast <= 1'b1;
                    end else if (particle_count == NUM_PARTICLES - 1) begin
                        fifo_tlast <= 1'b0;
                        ready <= 1'b0;
                    end
                    if (scatter_done) begin
                        first <= 1'b0;
                        rst_solve <= 1'b1;
                        particle_count <= '0;
                        state <= RST_SOLVE;
                    end
                end
                RST_SOLVE: begin
                    rst_solve <= 1'b0;
                    start_solve <= 1'b1;
                    step <= SOLVE;
                    state <= SOLVER;
                end
                SOLVER: begin
                    start_solve <= 1'b0;
                    if (solve_done) begin
                        rst_scatter <= 1'b1;
                        rst_push <= 1'b1;
                        state <= RST_PUSH_SCATTER;
                    end
                end
                RST_PUSH_SCATTER: begin
                    rst_scatter <= 1'b0;
                    rst_push <= 1'b0;
                    ready <= 1'b1;
                    step <= SCATTER;
                    state <= PUSH_SCATTER;
                end
            endcase
        end
    end
endmodule