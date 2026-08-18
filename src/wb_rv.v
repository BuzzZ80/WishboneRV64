////////////////////////////////////////////////////////////////////////////////
// 
// Copyright (c) 2026 Buzz Pendarvis
//
// Filename: wb_rv.v
// Project: WishboneRV64
// Description: The processor core itself. Ties together all the stages.
//
////////////////////////////////////////////////////////////////////////////////

module core(
    // shared by both wishbone interfaces
    input i_clk,
    input i_rst,
    
    // instruction wishbone interface
    output wire o_instr_cyc,
    output wire o_instr_stb,
    input wire i_instr_ack,
    input wire [63:0] i_instr_dat,
    output wire [52:0] o_instr_adr,
    
    // data wishbone interface
    output wire o_data_cyc,
    output wire o_data_stb,
    output wire o_data_we,
    input wire i_data_ack,
    input wire i_data_stall,
    input wire [63:0] i_data_dat,
    output wire [63:0] o_data_dat,
    output wire [52:0] o_data_adr
);  

endmodule