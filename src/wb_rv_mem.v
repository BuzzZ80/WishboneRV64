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
    // states:
    // s0: stage ready, no pending request
    // s1: stage ready but awaiting response
    // s2: stage valid, no pending request
    // s3: stage valid, awaiting response
    reg [1:0] r_fsm_state;
    
    // pipeline registers
    reg [63:0] r_alu_result;
    reg [54:0] r_addr;
    reg [63:0] r_data;
    reg r_load;
    reg r_store;
    reg r_jump;
    reg r_link;
    reg [4:0] r_wb_addr;
    
    // outgoing request register
    reg [4:0] r_rq_buffer_wb_addr;
    
    // logic
    reg is_memory_access;
    
    always @ (*) begin
        is_memory_access = r_load || r_store;
        
        if (i_rst) begin
            o_cyc = 0;
            o_stb = 0;
            o_we = 0;
            o_ready = 0;
            o_valid = 0;
        end
        else case (r_fsm_state)
            // invalid & buffer empty
            0: begin
                o_cyc = 0; // nothing to request
                o_stb = 0;
                o_we = 0;
                o_ready = 1;
                o_valid = 0;
            end
            // invalid & buffer full
            1: begin
                o_cyc = 1; // waiting for a response
                o_stb = 0;
                o_we = 0;
                o_ready = 1; 
                o_valid = i_ack; // done when response is received
            end
            // valid & buffer empty
            // (non-memory instructions executed here, since they can only be executed when the buffer is empty)
            2: begin
                o_cyc = is_memory_access;
                o_stb = is_memory_access;
                o_we = r_store;
                o_ready = !i_stall;
                o_valid = !is_memory_access; // non-memory-accesses have nothing to wait for
            end
            // valid & buffer full
            3: begin
                o_cyc = 1;
                o_stb = !i_stall && i_ack && is_memory_access;
                o_we = r_store;
                o_ready = !i_stall && i_ack && is_memory_access; // instruction moves forward into buffer if it's a memory access. otherwise it sits still here.
                o_valid = i_ack;
            end
        endcase
        // ready for new instructions when not stalling, and invalid or handshaking with next
        o_adr = r_alu_result[52:0];
        o_dat = r_data;
        
        o_jump = r_jump && (r_fsm_state == 2);
        o_jump_base = r_addr;
        o_jump_offset = r_data[55:2];
    end
    
    always @ (posedge i_clk) begin
        if (i_rst) begin
            r_fsm_state <= 0;
        end
        else case (r_fsm_state)
            0: if (i_valid) r_fsm_state <= 2;
            1: r_fsm_state <= {i_valid, !i_ack};
            2: if (!i_stall) r_fsm_state <= {i_valid, is_memory_access};
            3: if (i_stall) r_fsm_state <= {1'b1, !i_ack};
                else r_fsm_state <= is_memory_access ? {i_valid, 1'b1} : 2;
        endcase
        
        // buffer must get loaded:
        // - memory instruction in pipeline registers, no outstanding requests or request is being answered
        // buffer may get loaded:
        // - when there are no outstanding requests
        // - when an outstanding request is being answered
        if (!r_fsm_state[0] || (o_cyc && i_ack)) begin
            r_rq_buffer_wb_addr <= r_wb_addr;
        end
         
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