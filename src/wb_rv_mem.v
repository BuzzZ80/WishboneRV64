////////////////////////////////////////////////////////////////////////////////
// 
// Copyright (c) 2026 Buzz Pendarvis
//
// Filename: wb_rv_exec.v
// Project: WishboneRV64
// Description: Holds the ALU, calculates addresses, resolves jumps
//
////////////////////////////////////////////////////////////////////////////////

module memory_stage(
    // generic control signals
    input wire i_clk,
    input wire i_rst,
    
    // wishbone interface
    output reg o_cyc,
    output reg o_stb,
    output reg o_we,
    input wire i_ack,
    input wire i_stall,
    input wire [63:0] i_dat,
    output reg [63:0] o_dat,
    output reg [52:0] o_adr,
    
    // previous stage handshake
    output reg o_ready,
    input wire i_valid,
    // previous stage data
    input wire [63:0] i_alu_result,
    input wire [54:0] i_addr,
    input wire [63:0] i_data,
    input wire i_load,
    input wire i_store,
    input wire i_jump,
    input wire i_link,
    input wire [4:0] i_wb_addr,
    
    // next stage handshake
    //input wire i_ready, // writebacks are always ready, assumed to be 1
    output reg o_valid,
    // next stage data
    output reg [63:0] o_wb_value,
    output reg [4:0] o_wb_addr,

    // jump control outputs
    output reg o_jump,
    output reg [53:0] o_jump_base,
    output reg [53:0] o_jump_offset
);
    reg r_valid;
    
    reg r_fsm_state;
    
    // pipeline registers
    reg [63:0] r_alu_result;
    reg [54:0] r_addr;
    reg [63:0] r_data;
    reg r_load;
    reg r_store;
    reg r_jump;
    reg r_link;
    reg [4:0] r_wb_addr;
    
    always @ (*) begin
        // ready for new instructions when not stalling, and invalid or handshaking with next
        o_ready = !i_stall && (!r_valid || o_valid);
        o_valid = !i_rst && r_valid && (!(r_load || r_store) || o_cyc && i_ack);

        o_adr = r_alu_result[52:0];
        o_dat = r_data;
        
        o_jump = r_jump && r_valid;
        o_jump_base = r_addr;
        o_jump_offset = r_data[55:2];
    end
    
    always @ (posedge i_clk) begin
        if (i_rst)
            r_valid <= 0;
        else if (i_valid && o_ready)
            r_valid <= 1;   // set whenever previous-stage handshake occurs
        else if (o_valid)
            r_valid <= 0;   // reset if next-stage handshake occurs and it's not being loaded
            
        if (o_ready && i_valid) begin
            r_alu_result <= i_alu_result;
            r_addr <= i_addr;
            r_data <= i_data;
            r_load <= i_load;
            r_store <= i_store;
            r_jump <= i_jump;
            r_link <= i_link;
            r_wb_addr <= i_wb_addr;
        end
    end
endmodule