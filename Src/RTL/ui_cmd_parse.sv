//-----------------------------------------------------------------------------
//  
//  Module   : ui_cmd_parse.v
//  Parent   : ui_ui.v
//  Children : None
//
//  Description: 
//     This module parses the incoming character stream looking for commands.
//     Characters are ignored when the char_fifo indicates that it is full.
//     
//     This module also generates the standard register interfaces to the 
//     other modules (the registers, counters and the Mode-S processor).
//
//  Parameters:
//
//  Local Parameters:
//     RESP_TYPE_*: Values for the different response types
//
//  Notes       : 
//
//  Multicycle and False Paths
//     None
//

`timescale 1ns/1ps


module ui_cmd_parse (
  input             clk,         // Clock input
  input             rst,         // Active HIGH reset - synchronous to clk

  input      [7:0]  rx_data,        // Character to be parsed
  input             rx_data_rdy,    // Ready signal for rx_data

  // From Character FIFO
  input             char_fifo_full, // The char_fifo is full

  // To/From Response generator
  output reg        send_char_val,  // A character is ready to be sent
  output reg [7:0]  send_char,      // Character to be sent

  output reg        send_resp_val,  // A response is requested
  output reg [1:0]  send_resp_type, // Type of response - see localparams

  input             send_resp_done, // The response generation is complete


  //   - particle FIFO
  output reg             ui_particle_wr,     // Write strobe
  output reg [PSIZE-1:0] ui_particle_data,   // Write data

  //   - magnetic field write
  output reg                        ui_mag_wr,     // Write strobe
  output reg [ADDRWIDTH-1:0]        ui_mag_addr,   // Address
  output reg [BWIDTH-1:0]           ui_mag_data,   // DATA

  //   - charge read
  output reg                        ui_chrg_rd,    // Read strobe
  output reg [ADDRWIDTH-1:0]        ui_chrg_addr,  // Address

  //   - electric field read
  output reg                        ui_phi_rd,    // Read strobe
  output reg [ADDRWIDTH-1:0]        ui_phi_addr,  // Address

  //   - go 
  output reg                        ui_go_wr,     // Write strobe (go)
  output reg [31:0]                 ui_go_data    // Write data (#iterations)



);


//***************************************************************************
// Parameter definitions
//***************************************************************************

  parameter 
     MAX_ARG_CH   = 13;    // Number of characters in largest set of args

  localparam [1:0]
    RESP_OK   = 2'b00,
    RESP_ERR  = 2'b01,
    RESP_DATA0 = 2'b10,  // 6 char
    RESP_DATA1 = 2'b11;  // 9 char

  // States for the main state machine
  localparam
    IDLE      = 3'b000,
    CMD_WAIT  = 3'b001,
    GET_ARG   = 3'b010,
    SEND_RESP = 3'b100,
    RESET     = 3'b111;

  localparam
    CMD_P     = 7'h50,
    CMD_M     = 7'h4D,
    CMD_C     = 7'h43,
    CMD_E     = 7'h45,
    CMD_G     = 7'h47;

//***************************************************************************
// Functions declarations
//***************************************************************************


//***************************************************************************
// Reg declarations
//***************************************************************************

  reg [2:0]         state;    // State variable
  reg               old_rx_data_rdy; // Old value of rx_data_rdy

  reg [6:0]         cur_cmd;  // Current cmd - least 7 significant bits of char
  reg [4*MAX_ARG_CH-5:0]        arg_sav;  // All but last char of args 
  reg [$clog2(MAX_ARG_CH)-1:0]  arg_cnt;  // Count the #chars in an argument


//***************************************************************************
// Wire declarations
//***************************************************************************

  // Accept a new character when one is available, and we can push it into
  // the response FIFO. A new character is available on the FIRST clock that
  // rx_data_rdy is asserted - it remains asserted for 1/16th of a bit period.
  wire new_char = rx_data_rdy && !old_rx_data_rdy && !char_fifo_full; 

  
//***************************************************************************
// Tasks and Functions
//***************************************************************************

  // This function takes the lower 7 bits of a character and converts them
  // to a hex digit. It returns 5 bits - the upper bit is set if the character
  // is not a valid hex digit (i.e. is not 0-9,a-f, A-F), and the remaining
  // 4 bits are the digit
  function [4:0] to_val;
    input [6:0] char;
  begin
    if ((char >= 7'h30) && (char <= 7'h39)) // 0-9
    begin
      to_val[4]   = 1'b0;
      to_val[3:0] = char[3:0];
    end
    else if (((char >= 7'h41) && (char <= 7'h46)) || // A-F
             ((char >= 7'h61) && (char <= 7'h66)) )  // a-f
    begin
      to_val[4]   = 1'b0;
      to_val[3:0] = char[3:0] + 4'h9; // gives 10 - 15
    end
    else 
    begin
      to_val      = 5'b1_0000;
    end
  end
  endfunction

  function [6:0] to_upper;
    input [6:0] char;
  begin
    if ((char >= 7'h61) && (char <= 7'h7a)) // a-z
    begin
      to_upper = char - 7'h20;
    end
    else 
    begin
      to_upper = char;
    end
  end
  endfunction

//***************************************************************************
// Code
//***************************************************************************

  // capture the rx_data_rdy for edge detection
  always @(posedge clk)
  begin
    if (rst)
    begin
      old_rx_data_rdy <= 1'b0;
    end
    else
    begin
      old_rx_data_rdy <= rx_data_rdy;
    end
  end

  // Echo the incoming character to the output, if there is room in the FIFO
  always @(posedge clk)
  begin
    if (rst)
    begin
      send_char_val <= 1'b0;
      send_char     <= 8'h00;
    end
    else if (new_char)
    begin
      //send_char_val <= 1'b1; -- this should disable the echo
      send_char     <= rx_data;
    end // if !rst and new_char
    else
    begin
      send_char_val <= 1'b0;
    end
  end // always

  // For each character that is potentially part of an argument, we need to 
  // check that it is in the HEX range, and then figure out what the value is.
  // This is done using the function to_val
  wire [4:0]  char_to_digit = to_val(rx_data[6:0]);

  wire        char_is_digit = !char_to_digit[4];

  wire [6:0]  char_to_upper = to_upper(rx_data[6:0]);

  // Assuming it is a value, the new digit is the least significant digit of
  // those that have already come in - thus we need to concatenate the new 4
  // bits to the right of the existing data
  wire [4*MAX_ARG_CH-1:0] arg_val       = {arg_sav,char_to_digit[3:0]};

  always @(posedge clk)
  begin
    if (rst)
    begin
      state             <= IDLE;
      cur_cmd           <= 7'h00;
      arg_sav           <= '0;
      arg_cnt           <= '0;
      //send_char_val     <= 1'b0;
      //send_char         <= 8'h00;
      send_resp_val     <= 1'b0;
      send_resp_type    <= RESP_ERR;
      //old_rx_data_rdy   <= 1'b0;
      
      ui_particle_wr    <= 1'b0;
      ui_particle_data  <= '0;

      ui_mag_wr         <= 1'b0;
      ui_mag_addr       <= '0;
      ui_mag_data       <= '0;

      ui_chrg_rd        <= 1'b0;
      ui_chrg_addr      <= '0;

      ui_phi_rd         <= 1'b0;
      ui_phi_addr       <= '0;

      ui_go_wr          <= 1'b0;
      ui_go_data        <= '0;
    end
    else
    begin
      // Defaults - overridden in the appropriate state
      ui_particle_wr    <= 1'b0;     // Write strobe
      ui_mag_wr         <= 1'b0;     // Write strobe
      ui_chrg_rd        <= 1'b0;    // Read strobe
      ui_phi_rd         <= 1'b0;    // Read strobe
      ui_go_wr          <= 1'b0;     // Write strobe (go)
      send_resp_val     <= 1'b0;     // Initiate a response
      
      case (state)

        IDLE: begin // Wait for the '*'
          if (new_char && (rx_data[6:0] == 7'h2A))
          begin
            state <= CMD_WAIT;
          end // if found *
        end // state IDLE

        CMD_WAIT: begin // Validate the incoming command
          if (new_char)
          begin
            cur_cmd <= char_to_upper[6:0];
            case (char_to_upper[6:0])
  
              CMD_P: begin // P - Particle push
                // Get 13 characters of arguments
                state   <= GET_ARG;
                arg_cnt <= 12;
              end  // P
  
              CMD_M: begin // M - magnetic field write
                // Get 7 characters of arguments - 3 address, 4 data
                state   <= GET_ARG;
                arg_cnt <= 6;
              end  // R

              CMD_C: begin // C - charge read
                // Get 3 characters of arguments - 3 address
                state   <= GET_ARG;
                arg_cnt <= 2;
              end  // C
              
              CMD_E: begin // E - electric field read
                // Get 3 characters of arguments - 3 address
                state   <= GET_ARG;
                arg_cnt <= 2;
              end  // E

              CMD_G: begin // G - Go
                // Get 8 characters of number of iterations
                state   <= GET_ARG;
                arg_cnt <= 7;
              end  // G
  
              default: begin
                send_resp_val  <= 1'b1;
                send_resp_type <= RESP_ERR;
                state          <= SEND_RESP;
              end // default
            endcase // current character case
          end // if new character has arrived
        end // state CMD_WAIT
        
        GET_ARG: begin
          // Get the correct number of characters of argument. Check that
          // all characters are legel HEX values.
          // Once the last character is successfully received, take action
          // based on what the current command is
          if (new_char)
          begin
            if (!char_is_digit)
            begin
              // Send an error response
              send_resp_val  <= 1'b1;
              send_resp_type <= RESP_ERR;
              state          <= SEND_RESP;
            end
            else // character IS a digit
            begin
              if (arg_cnt != 0) // This is NOT the last char of arg
              begin
                // append the current digit to the saved ones
                arg_sav <= arg_val[4*MAX_ARG_CH-5:0];  
                // Wait for the next character
                arg_cnt <= arg_cnt - 1'b1;
              end // Not last char of arg
              else // This IS the last character of the argument - process
              begin
                case (cur_cmd) 
                  CMD_P: begin
                    // Initiate a particle push 
                    // arg_val[51:0]  is the write data
                    ui_particle_data  <= arg_val[PSIZE-1:0];
                    ui_particle_wr     <= 1'b1;
                    // Send OK right away
                    send_resp_val  <= 1'b1;
                    send_resp_type <= RESP_OK;
                    state          <= SEND_RESP;
                  end // CMD_P


                  CMD_M: begin
                    //write to magnetic field memory
                    //arg_val[27:16] is the address
                    //arg_val[13:0] is the data
                    ui_mag_addr <= arg_val[27-:ADDRWIDTH];
                    ui_mag_data <= arg_val[BWIDTH-1:0];
                    ui_mag_wr   <= 1'b1;
                    // Send OK right away
                    send_resp_val  <= 1'b1;
                    send_resp_type <= RESP_OK;
                    state          <= SEND_RESP;
                  end // CMD_M

                  CMD_C: begin
                    //read charge memory
                    //arg_val[11:0] is the address
                    ui_chrg_addr <= arg_val[ADDRWIDTH-1:0];
                    ui_chrg_rd   <= 1'b1;
                    // Send OK right away
                    send_resp_val  <= 1'b1;
                    send_resp_type <= RESP_DATA0;
                    state          <= SEND_RESP;
                  end // CMD_C

                  CMD_E: begin
                    //read electric field memory
                    //arg_val[11:0] is the address
                    ui_phi_addr <= arg_val[ADDRWIDTH-1:0];
                    ui_phi_rd   <= 1'b1;
                    // Send OK right away
                    send_resp_val  <= 1'b1;
                    send_resp_type <= RESP_DATA1;
                    state          <= SEND_RESP;
                  end // CMD_E

                  CMD_G: begin
                    //write to go register
                    //arg_val[31:0] is the data
                    ui_go_data <= arg_val[31:0];
                    ui_go_wr   <= 1'b1;
                    // Send OK right away
                    send_resp_val  <= 1'b1;
                    send_resp_type <= RESP_OK;
                    state          <= SEND_RESP;
                  end // CMD_G



                endcase // cur_cmd
              end // received last char of arg
            end // if the char is a valid HEX digit
          end // if new_char
        end // state GET_ARG

        SEND_RESP: begin
          // The response request has already been sent - all we need to
          // do is keep the request asserted until the response is complete.
          // Once it is complete, we return to IDLE
          if (send_resp_done)
          begin
            send_resp_val <= 1'b0;
            state         <= IDLE;
          end
        end // state SEND_RESP

        default: begin
          state <= IDLE;
        end // state default

      endcase
    end // if !rst
  end // always

endmodule
