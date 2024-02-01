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
    input logic solve_done,
    input logic fifo_valid,
    input logic last_step,
    output logic fifo_ready,
    output logic pusher_valid,
    output logic start_solve,
    output logic first
    );

    typedef enum {
        UI,
        WAIT_VALID,
        SOLVE,
        PUSH_SCATTER,
        SCATTER
    } state_t;

    state_t state;
    
    always_ff @(posedge clk) begin
        if (rst) begin
            state <= UI;
        end else begin
            case (state)
                UI: begin
                    if (ui_done) begin
                        state <= WAIT_VALID;
                        fifo_ready <= 1'b1;
                        first <= 1'b1;
                    end
                end
                WAIT_VALID: begin
                    if (fifo_valid) begin
                        state <= PUSH_SCATTER;
                        pusher_valid <= 1'b1;
                    end
                end
                PUSH_SCATTER: begin
                    if (pusher_done) begin
                        if (last_step)
                            state <= UI;
                        else begin
                            state <= SCATTER;
                            first <= 1'b0;
                            pusher_valid <= 1'b0;
                            fifo_ready <= 1'b0;
                        end
                    end
                end
                SCATTER: begin
                    if (scatter_done) begin
                        state <= SOLVE;
                        start_solve <= 1'b1;
                    end
                end
                SOLVE: begin
                    if (solve_done) begin
                        state <= WAIT_VALID;
                        start_solve <= 1'b0;
                        fifo_ready <= 1'b1;
                    end
                end
            endcase
        end

endmodule