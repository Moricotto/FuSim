//-----------------------------------------------------------------------------
//  
//  Module   : ui_resp_parse.v
//  Parent   : ui_ui.v
//  Children : none
//
//  Description: 
//     This module is responsible for pushing data into the character FIFO to
//     send to the user over the serial link.
//     There are two interfaces from the command parser to this module. The
//     first is the one that echoes received characters back to the user
//     (giving full duplex communication) - every character received while the
//     character FIFO is not full is simply pushed into the FIFO.
//     The second is the generation of the response string when a command (or
//     error) is entered. There are 4 types of responses
//       - The error response (normally "-ERR\n")
//       - The OK response (normally "-OK\n")
//       - Two data response the '-' followed by the appropriate number of
//         hex digits, then the \n
//
//  Parameters:
//
//  Local Parameters:
//     RESP_TYPE_*: Values for the different response types
//                  Must correspond to those defined in cmd_parse
//
//  Notes       : 
//     For PC usage, we must send a "Carriage return" (ascii 0xD). The
//     terminal program should append a line feed.
//
//  Multicycle and False Paths
//     None
//

`timescale 1ns/1ps


module ui_resp_gen (
  input             clk,         // Clock input
  input             rst,     // Active HIGH reset - synchronous to clk

  // From Character FIFO
  input             char_fifo_full, // The char_fifo is full

  // To/From the Command Parser
  input             send_char_val,  // A character is ready to be sent
  input      [7:0]  send_char,      // Character to be sent

  input             send_resp_val,  // A response is requested
  input      [1:0]  send_resp_type, // Type of response - see localparams

  // From the register sources
  input                     phi_rdy,          // Ready from PHI
  input      [PHIWIDTH-1:0] phi_rdata,        // Read data from PHI
  input                     chrg_rdy,         // Ready from magnetic field
  input      [CWIDTH-1:0]   chrg_rdata,        // Read data from magnetic field

  output reg        send_resp_done, // The response generation is complete

  // To character FIFO
  output reg [7:0]  char_fifo_din,  // Character to push into the FIFO
                                    // char_fifo_din is NOT from a flop
  output            char_fifo_wr_en // Write enable (push) for the FIFO
);


//***************************************************************************
// Parameter definitions
//***************************************************************************

  function [31:0] max;
    input [31:0] a;
    input [31:0] b;
  begin
    max = (a > b) ? a : b;
  end
  endfunction

  function [7:0] to_digit;
    input [3:0] val;
  begin
    if (val < 4'd10)
      to_digit = 8'h30 + val; // 8'h30 is the character '0'
    else
      to_digit = 8'h57 + val; // 8'h57 + 10 is 8'h61 - the character 'a' 
  end
  endfunction

//***************************************************************************
// Parameter definitions
//***************************************************************************

  localparam [1:0]
    RESP_OK    = 2'b00,
    RESP_ERR   = 2'b01,
    RESP_DATA0 = 2'b10,
    RESP_DATA1 = 2'b11;

  localparam
    STR_OK_LEN    = 4'd4,  // -OK\n
    STR_ERR_LEN   = 4'd5,  // -ERR\n
    STR_DATA0_LEN = 4'd11,  // -HHHHHHHHH\n
    STR_DATA1_LEN = 4'd11; // -HHHHHHHHH\n

  localparam STR_LEN = max(max(max(STR_OK_LEN, STR_ERR_LEN), STR_DATA0_LEN), STR_DATA1_LEN);

  localparam CNT_WID = $clog2(STR_LEN);   // Must hold 0 to STR_LEN-1

  localparam LEN_WID = $clog2(STR_LEN+1); // Must hold the value STR_LEN

  localparam
    IDLE    = 2'b00,
    WAITING = 2'b01,
    SENDING = 2'b10;

//***************************************************************************
// Reg declarations
//***************************************************************************

  reg [1:0]         state;    // State variable
  reg [CNT_WID-1:0] char_cnt; // Current character being sent
  
  reg [4*(STR_LEN-2)-1:0]        send_resp_data;    // Mutliplexed read data

//***************************************************************************
// Wire declarations
//***************************************************************************

  wire [LEN_WID-1:0]   str_to_send_len; // The length of the string to be sent

//***************************************************************************
// Tasks and Functions
//***************************************************************************


//***************************************************************************
// Code
//***************************************************************************

  assign str_to_send_len = (send_resp_type == RESP_OK)   ? STR_OK_LEN  :
                          (send_resp_type == RESP_ERR)   ? STR_ERR_LEN : 
                          (send_resp_type == RESP_DATA0) ? STR_DATA0_LEN: 
                                                           STR_DATA1_LEN;
  // Capture the data to read
  always @(posedge clk)
  begin
    if (rst)
    begin
      send_resp_data  <= '0;
    end
    else
    begin
      casex ({phi_rdy, chrg_rdy}) // synthesis parallel_case
        2'b1?: send_resp_data <= phi_rdata;
        2'b?1: send_resp_data <= chrg_rdata;
      endcase
    end
  end

  // Echo the incoming character to the output, if there is room in the FIFO
  always @(posedge clk)
  begin
    if (rst)
    begin
      state           <= IDLE;
      char_cnt        <= 0;
      send_resp_done  <= 1'b0;
      //send_resp_data  <= '0;
    end
    else 
    case (state)
      IDLE: begin
        send_resp_done <= 1'b0;
        // Make sure not to re-trigger while we are waiting for the 
        // send_resp_done to affect the send_resp_val. In other words,
        // never respond to a send_resp_val if send_resp_done is being sent
        if (send_resp_val && !send_resp_done)  // A new response is requested
        begin
          char_cnt <= 0;
          if ((send_resp_type == RESP_DATA0) || (send_resp_type == RESP_DATA1))
          begin 
            // If we are supposed to send data, then wait
            // for the data to arrive from the source
            state    <= WAITING;
          end
          else
          begin
            state    <= SENDING;
          end
        end
      end // IDLE
    
      WAITING: begin // Waiting for response from register source
        if (phi_rdy || chrg_rdy)
        begin
          state <= SENDING;
        end
      end // WAITING

      SENDING: begin
        if (!char_fifo_full)
        begin
          // We will send a character this clock
          if (char_cnt == (str_to_send_len - 1'b1)) 
          begin
            // This will be the last one
            state          <= IDLE; // Return to IDLE
            send_resp_done <= 1'b1; // Signal cmd_parse that we are done
          end
          else
          begin
            char_cnt <= char_cnt + 1'b1;
          end
        end // if !char_fifo_full
      end // SENDING

      default: begin
        state <= IDLE;
      end
    endcase

  end // always

  assign char_fifo_wr_en = 
            ((state == IDLE) && send_char_val) ||
            ((state == SENDING) && !char_fifo_full);

  // Generate the DATA to the FIFO
  // If idle, the only thing we can be sending is the send_char
  // If in the SENDING state, it depends on the send_resp_type, and where
  // we are in the sequence
  always @(*)
  begin
    if (state == IDLE)
    begin
      char_fifo_din = send_char;
    end
    else
    begin
      if (send_resp_type == RESP_OK) 
      begin
        case (char_cnt) // synthesis full_case
          0 : char_fifo_din = "-"; // Dash
          1 : char_fifo_din = "O";
          2 : char_fifo_din = "K";
          3 : char_fifo_din = 8'h0d; // Newline
        endcase
      end
      else if (send_resp_type == RESP_ERR)
      begin
        case (char_cnt) // synthesis full_case
          0 : char_fifo_din = "-"; // Dash
          1 : char_fifo_din = "E";
          2 : char_fifo_din = "R";
          3 : char_fifo_din = "R";
          4 : char_fifo_din = 8'h0d; // Newline
        endcase
      end
      else // It is RESP_DATA
      begin
        if (char_cnt == 0) begin 
           char_fifo_din = "-"; // Dash
	end
	else if (char_cnt == str_to_send_len-1) begin
           char_fifo_din = 8'h0d; // Newline
        end else begin
          char_fifo_din = to_digit(send_resp_data[(str_to_send_len-(char_cnt-1))*4-:4]);
        end
      end // if RESP_DATA
    end // if send_char
  end // always


endmodule
