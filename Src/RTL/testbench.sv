`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/24/2023 10:49:42 AM
// Design Name: 
// Module Name: testbench
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



module testbench();
    import defs::*;
    
    logic clk;
    logic rst;
    logic calib_complete;
    logic valid;
    logic tlast;
    particle_t particle_in [1:0];
    logic [7:0] led;

    plasma_sim dut (
        .sys_clk_p(clk),
        .sys_clk_n(~clk),   
        .rst(rst),
        .led(led),
        .data_out()
    );

   
    //clock logic 
    initial begin
        clk = 1;
        forever #5 clk = ~clk;
    end 
    
    initial begin
        rst = 1'b0;
        calib_complete = 1'b0;
        valid = 1'b0;
        tlast = 1'b0;
        particle_in[0] = {18'h0fe3d, 18'h036ad, 14'h0c1f};
        particle_in[1] = {18'h0d24a, 18'h023a6, 14'h0a2e};
        @(posedge clk) rst = 1;
        @(posedge clk);
        @(posedge clk) rst = 0;
        @(posedge clk);
        @(posedge clk);
        calib_complete = 1'b1;
        @(posedge clk);
        valid = 1'b1;
        forever begin
            tlast = 1'b0;
            for (int i = 0; i < 500; i++) begin
                @(posedge clk);
            end
            tlast = 1'b1;
            @(posedge clk);
        end
    end

endmodule
