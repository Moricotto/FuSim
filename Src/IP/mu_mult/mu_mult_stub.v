// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2023 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2023.1 (win64) Build 3865809 Sun May  7 15:05:29 MDT 2023
// Date        : Sat Dec  2 22:11:55 2023
// Host        : aw-7480 running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub -rename_top mu_mult -prefix
//               mu_mult_ mu_mult_stub.v
// Design      : mu_mult
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7k325tffg900-2
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "mult_gen_v12_0_18,Vivado 2023.1" *)
module mu_mult(CLK, A, B, P)
/* synthesis syn_black_box black_box_pad_pin="A[18:0],B[21:0],P[40:0]" */
/* synthesis syn_force_seq_prim="CLK" */;
  input CLK /* synthesis syn_isclock = 1 */;
  input [18:0]A;
  input [21:0]B;
  output [40:0]P;
endmodule
