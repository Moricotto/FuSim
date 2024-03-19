`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/29/2024 12:03:42 PM
// Design Name: 
// Module Name: decoder
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

module decoder(
    input logic clk,
    input logic rst,
    input logic valid,
    //from UART
    input logic wen,
    input logic [13:0] addr_in,
    input logic [PSIZE-1:0] data_in,
    //to UART
    output logic valid_read,
    output logic [PSIZE-1:0] data_out,

    //from BRAMs
    input charge_t  charge_in,
    input phi_t phi_in,

    //to BRAMs
    output addr_t addr_out,
    output bmag_t bmag_out,
    output particle_t particle_out,
    output logic bmag_wen,
    output logic fifo_wen
    );

    logic [1:0] dest;
    logic wen_ff;
    logic [1:0] dest_ff [5:0];
    addr_t true_addr;
    logic [PSIZE-1:0] data_ff;

    logic valid_dest;
    logic valid_addr;
    logic [4:0] valid_wait;

    always @(posedge clk) begin
        if (rst) begin
            valid_read <= 1'b0;
            dest <= 2'b0;
            true_addr <= 14'b0;
            wen_ff <= 1'b0;
            dest_ff <= '{default: 2'b0};
            data_ff <= 0;
            bmag_out <= '0;
            particle_out <= '0;
            fifo_wen <= 1'b0;
            bmag_wen <= 1'b0;

            valid_dest <= 1'b0;
            valid_addr <= 1'b0;
            valid_wait <= '0;
        end else begin
            if (valid) begin
                dest <= addr_in[13:12];
                true_addr <= addr_in[11:0];
                data_ff <= data_in;
                valid_dest <= 1'b1;
                wen_ff <= wen;  
            end else begin
                valid_dest <= 1'b0;
                fifo_wen <= 1'b0;
                bmag_wen <= 1'b0;
            end

            if (valid_dest) begin
                addr_out <= true_addr;
                dest_ff[0] <= dest;
                case (dest)
                    2'b00: begin //to particle FIFO
                        fifo_wen <= wen_ff;
                        bmag_wen <= 1'b0;
                        particle_out <= data_ff;
                    end
                    2'b01: begin //to bmag FIFO
                        fifo_wen <= 1'b0;
                        bmag_wen <= wen_ff;
                        bmag_out <= data_ff[BWIDTH-1:0];
                    end
                endcase
                valid_addr <= 1'b0;
            end else begin
                valid_addr <= 1'b1;
            end

            //wait 4 cycles for phi, and 5 for charge
            if (valid_addr) begin
                dest_ff[1] <= dest_ff[0];
                valid_wait[0] <= 1'b1;
            end else begin
                valid_wait[0] <= 1'b0;
            end

            if (valid_wait[0]) begin
                dest_ff[2] <= dest_ff[1];
                valid_wait[1] <= 1'b1;
            end else begin
                valid_wait[1] <= 1'b0;
            end

            if (valid_wait[1]) begin
                dest_ff[3] <= dest_ff[2];
                valid_wait[2] <= 1'b1;
            end else begin
                valid_wait[2] <= 1'b0;
            end

            if (valid_wait[2]) begin
                dest_ff[4] <= dest_ff[3];
                valid_wait[3] <= 1'b1;
            end else begin
                valid_wait[3] <= 1'b0;
            end

            if (valid_wait[3]) begin
                if (dest_ff[4] == 2'b10) begin
                    valid_read <= 1'b1;
                    data_out <= phi_in;
                    dest_ff[5] <= dest_ff[4];
                    valid_wait[4] <= 1'b1;
                end
            end else begin
                valid_read <= 1'b0;
                valid_wait[4] <= 1'b0;
            end

            if (valid_wait[4]) begin
                if (dest_ff[5] == 2'b11) begin
                    valid_read <= 1'b1;
                    data_out <= charge_in;
                end
            end else begin
                valid_read <= 1'b0;
            end
        end
    end
endmodule
