-- Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
-- Copyright 2022-2023 Advanced Micro Devices, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2023.1 (win64) Build 3865809 Sun May  7 15:05:29 MDT 2023
-- Date        : Sat Dec  2 22:11:55 2023
-- Host        : aw-7480 running 64-bit major release  (build 9200)
-- Command     : write_vhdl -force -mode synth_stub -rename_top mu_mult -prefix
--               mu_mult_ mu_mult_stub.vhdl
-- Design      : mu_mult
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7k325tffg900-2
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity mu_mult is
  Port ( 
    CLK : in STD_LOGIC;
    A : in STD_LOGIC_VECTOR ( 18 downto 0 );
    B : in STD_LOGIC_VECTOR ( 21 downto 0 );
    P : out STD_LOGIC_VECTOR ( 40 downto 0 )
  );

end mu_mult;

architecture stub of mu_mult is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "CLK,A[18:0],B[21:0],P[40:0]";
attribute x_core_info : string;
attribute x_core_info of stub : architecture is "mult_gen_v12_0_18,Vivado 2023.1";
begin
end;
