//-----------------------------------------------------------------------------
//  
//  Project  : SSRM RF Processor
//  Module   : ss_meta_harden.v
//  Parent   : Various
//  Children : None
//
//  Description: 
//    This is a basic meta-stability hardener; it double synchronizes an
//    asynchronous signal onto a new clock domain.
//
//  Parameters:
//    WIDTH: Number of bits to meta-harden. Each bit is considered indepenent
//
//  Notes       : 
//
//  Multicycle and False Paths, Timing Exceptions
//    A tighter timing constraint should be placed between the signal_meta
//    and signal_dst flip-flops to allow for meta-stability settling time
//

`timescale 1ns/1ps


module ui_meta_harden #(
  parameter WIDTH = 1
) (
  input                   clk_dst,      // Destination clock
  input                   rst_dst,      // Reset - synchronous to clk_dst
  input      [WIDTH-1:0]  signal_src,   // Asynchronous signal to sync
  output reg [WIDTH-1:0]  signal_dst    // Synchronized signal
);


//***************************************************************************
// Register declarations
//***************************************************************************

  (* MAXDELAY = "2ns" *)
  reg [WIDTH-1:0] signal_meta;     // After sampling the async signal, this has
                                   // a high probability of being metastable.
                                   // The second sampling (signal_dst) has
                                   // a much lower probability of being
                                   // metastable

//***************************************************************************
// Code
//***************************************************************************

  always @(posedge clk_dst)
  begin
    if (rst_dst)
    begin
      signal_meta <= {WIDTH{1'b0}};
      signal_dst  <= {WIDTH{1'b0}};
    end
    else // if !rst_dst
    begin
      signal_meta <= signal_src;
      signal_dst  <= signal_meta;
    end // if rst
  end // always

endmodule

