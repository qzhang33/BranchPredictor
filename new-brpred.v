//=========================================================================
// Branch Predictor 
//=========================================================================

`ifndef BranchPredictor
`define BranchPredictor

`include "vc/regs.v"
`include "vc/arithmetic.v"
`include "vc/muxes.v"
`include "vc/misc.v"

//========================================================================
// Branch Predictor Control Unit
//========================================================================

module brpred_BranchPredictorCtrl
(
  input  logic       clk,
  input  logic       reset,
  input  logic       w_en,
  input  logic [1:0] state,
  input  logic       br_resolution,
  output logic [1:0] state_next,
  output logic       br_prediction
);

  //-----------------------------------------------------------------------
  // State definitions
  //-----------------------------------------------------------------------

  localparam STATE_STRONG_NT = 2'b00;
  localparam STATE_WEAK_NT   = 2'b01;
  localparam STATE_WEAK_T    = 2'b10;
  localparam STATE_STRONG_T  = 2'b11;

  //-----------------------------------------------------------------------
  // State transition
  //-----------------------------------------------------------------------

  logic [1:0] state_next;
  logic [1:0] state;

  always @(*) begin
    case( state )
      STATE_STRONG_NT: state_next = br_resolution ? STATE_WEAK_NT  : STATE_STRONG_NT;
      STATE_WEAK_NT:   state_next = br_resolution ? STATE_WEAK_T   : STATE_STRONG_NT;
      STATE_WEAK_T:    state_next = br_resolution ? STATE_STRONG_T : STATE_WEAK_NT;
      STATE_STRONG_T:  state_next = br_resolution ? STATE_STRONG_T : STATE_WEAK_T;
      default:         state_next = STATE_WEAK_NT;
    endcase
  end

  //-----------------------------------------------------------------------
  // Output 
  //-----------------------------------------------------------------------

  assign br_prediction 
    = ( state == STATE_WEAK_T | state == STATE_STRONG_T );

endmodule

//=============)===========================================================
// Branch Predictor Data Path
//========================================================================

module brpred_BranchPredictorDpath
#(
  parameter p_pc_nbits = 32,
  parameter p_btb_num_entries = 2
 )
(
  input  logic                  clk,
  input  logic                  reset,
  input  logic                  w_en,
  input  logic [p_pc_nbits-1:0] in_pc,
  input  logic            [1:0] state_next,
  input  logic [p_pc_nbits-1:0] in_brj_targ,
  output logic            [1:0] state,
  output logic [p_pc_nbits-1:0] out_brj_targ
);

  //----------------------------------------------------------------------
  // 1 entry BTB
  //----------------------------------------------------------------------

  // BTB Entry:)
  //   1b        32b               32b          2b
  //  +---+----------------+-----------------+-------+
  //  | v |       PC       |    BRJ Target   | state |
  //  +---+----------------+-----------------+-------+
  // 66   65             34 33              2 1       0

  localparam c_btb_entry_sz = 2) * p_pc_nbits + 3;

  logic [c_btb_entry_sz-1:0] btb_entry[0:p_btb_num_entries-1];
  logic [p_btb_num_entries-1:0] pc_check_out;
)
  genvar i;
  generate 
  for ( i = 0; i < p_btb_num_entries; i = i + 1 ) begin: btb_entries
    vc_EnResetReg #( c_btb_entry_sz ) btb
    (
      .clk  (clk),
      .reset(reset),
      .d    ({ w_en, in_pc, in_brj_targ, state_next }),
      .en   (w_en),
      .q    (btb_entry[i])
    );

    vc_EqComparator #( p_pc_nbits ) pc_check
    (
      .in0 (in_pc),
      .in1 (btb_entry[i][65:34]),
      .out (pc_check_out[i])
    );
    
  end
  endgenerate

  localparam c_btb_enc_nbits = $clog2( p_btb_num_entries );

  logic [c_btb_enc_nbits-1:0] encoder_out;
  vc_Encoder #( p_btb_num_entries, c_btb_enc_nbits ) btb_enc
  (
    .in   (pc_check_out),
    .out  (encoder_out)
  );

  assign w_en         
    = ~pc_check_out & br_prediction;

  assign state        
    = ~pc_check_out 
    ? state 
    : br_prediction
      ? state + 1 
      : state - 1;

  assign out_brj_targ 
    = br_prediction
    ? btb_entry[encoder_out][33:2] 
    : in_pc + 4;
  
endmodule

//========================================================================
// Branch Predictor Core
//========================================================================

module brpred_BranchPredictor
#(
  parameter p_pc_nbits = 32
 )
(
  input  clk,
  input  reset,
  input  w_en,

  input  br_resolution,
  output br_prediction,

  input  [31:0] in_pc,
  input  [31:0] in_brj_targ,
  output [31:0] out_brj_targ
);

  //----------------------------------------------------------------------
  // Connection
  //----------------------------------------------------------------------

  logic [1:0] state;
  logic [1:0] state_next;

  brpred_BranchPredictorCtrl ctrl
  (
    .*
  );

  brpred_BranchPredictorDpath #( p_pc_nbits ) dpath
  (
    .*
  );

endmodule

`endif