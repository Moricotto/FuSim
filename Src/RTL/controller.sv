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
    input logic ui_done,
    input logic scatter_done,
    input logic pusher_done,
    input logic solver_done,
    input logic [31:0] num_steps_in,
    output logic [31:0] cnt_out,
    output logic ui_valid,
    output logic fifo_ready,
    output logic start_solve,
    output logic first,
    output logic rst_scatterer,
    output logic rst_pusher,
    output logic rst_solver
    );

    typedef enum {
        UI,
        SOLVE,
        RST_SOLVE,
        PUSH_SCATTER,
        SCATTER
    } state_t;

    state_t state;
    logic [31:0] num_steps;
    logic [31:0] cnt;

    assign cnt_out = cnt;
    assign num_steps = num_steps_in;

    always_ff @(posedge clk) begin
        if (rst) begin
            //TODO: finish reset
            state <= UI;
            rst_scatterer <= 1'b1;
            rst_pusher <= 1'b1;
            rst_solver <= 1'b1;
            cnt <= '0;
            ui_valid <= 1'b1;
            fifo_ready <= 1'b0;
            first <= 1'b1;
            start_solve <= 1'b0;
        end else begin
            case (state)
                UI: begin
                    rst_scatterer <= 1'b0;
                    rst_pusher <= 1'b0;
                    rst_solver <= 1'b0;
                    if (ui_done) begin
                        state <= PUSH_SCATTER;
                        ui_valid <= 1'b0;
                        first <= 1'b1;
                        fifo_ready <= 1'b1;
                    end
                end
                PUSH_SCATTER: begin
                    rst_scatterer <= 1'b0;
                    if (pusher_done) begin
                        state <= SCATTER;
                        fifo_ready <= 1'b0;
                        first <= 1'b0;
                        cnt <= cnt + 1;
                        rst_pusher  <= 1'b1;
                    end
                end
                SCATTER: begin
                    if (cnt == num_steps) begin
                        state <= UI;
                        ui_valid <= 1'b1;
                    end
                    rst_pusher <= 1'b0;
                    if (scatter_done) begin
                        state <= RST_SOLVE;
                        rst_solver <= 1'b1;
                    end
                end
                RST_SOLVE: begin
                    state <= SOLVE;
                    rst_solver <= 1'b0;
                    start_solve <= 1'b1;
                end
                SOLVE: begin
                    start_solve <= 1'b0;
                    if (solver_done) begin
                        state <= PUSH_SCATTER;
                        rst_scatterer <= 1'b1;
                        fifo_ready <= 1'b1;
                    end
                end
            endcase
        end
    end
endmodule