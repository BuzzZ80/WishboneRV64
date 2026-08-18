////////////////////////////////////////////////////////////////////////////////
// 
// Copyright (c) 2026 Buzz Pendarvis
//
// Filename: wb_rv_fetch.v
// Project: WishboneRV64
// Description: Fetches instructions through a pipelined wishbone bus
//
////////////////////////////////////////////////////////////////////////////////

module fetch_stage(
    input wire i_clk,
    input wire i_rst,
    
    // wishbone bus for fetching instructions
    output reg o_cyc,
    output reg o_stb,
    input wire i_ack,
    input wire i_stall,
    input wire [63:0] i_dat,
    output reg [52:0] o_adr,
    
    // next-stage handshake signals
    input wire i_ready,
    output reg o_valid,
    // next-stage data
    output reg [31:0] o_instr,
    output reg [53:0] o_pc,
    
    // control inputs
    input wire i_ctrl_jump,
    input wire [53:0] i_ctrl_jump_base,
    input wire [53:0] i_ctrl_jump_offset
);
    // program counter
    reg [52:0] r_pc;
    
    // FSM for pipelined fetching
    // States:
    // 0 - instruction buffer is invalid, no request has been made - therefore, start a request
    // 1 - instruction buffer is invalid, there's an outstanding request - wait
    // 2 - instruction buffer is valid. if it's about to be emptied, make a request.
    // cannot be both valid *and* waiting on an already outstanding request
    reg [1:0] r_fsm_state;
    
    // aforementioned instruction buffer
    reg [63:0] r_instr_buffer;      // held instruction
    reg [52:0] r_instr_buffer_pc;   // address of held instruction
    reg r_instr_buffer_position;    // which of the 2 instructions held in the buffer is to be read next
    
    reg buffer_emptying;    // indicates next-stage handshake on second instruction in buffer
    reg buffer_filling;     // indicates wishbone handshake
    reg forwarding; // forwards wishbone response to next stage when possible
    
    always @ (posedge i_clk) begin
        if (i_rst) begin
            r_pc <= 0;
            r_fsm_state <= 0;
            r_instr_buffer_position <= 0;
        end
        else begin
            // on wishbone handshake, load instr into buffer,
            if (buffer_filling) begin
                r_instr_buffer <= i_dat;
                r_instr_buffer_pc <= r_pc;
                r_pc <= r_pc + 1;
            end
            // if reading from a full buffer, move on to next instruction in buffer.
            // if reading but a wishbone handshake is occurring, 
            //   then it's forwarding the first instruction and we can go to the second instr next cycle
            if (o_valid && i_ready) begin
                r_instr_buffer_position <= buffer_filling ? 1 : ~r_instr_buffer_position;
            end
            
            // FSM logic
            case (r_fsm_state)
                // a request is being made this clock cycle. 
                // move on to waiting (state 1), if the request is not stalled.
                0: if (!i_stall) r_fsm_state <= 1;
                // currently awaiting handshake. 
                // when it happens, mark buffer valid (state 2).
                1: if (buffer_filling) r_fsm_state <= 2;
                // buffer is valid. 
                // if it's emptying, make a request for the next instruction.
                // if this request is stalled, invalidate buffer and keep trying (state 0)
                // otherwise just wait for it (state 1)
                2: if (buffer_emptying) r_fsm_state <= i_stall ? 0 : 1;
            endcase
        end
    end
    
    always @ (*) begin
        buffer_emptying = (o_valid && i_ready) && r_instr_buffer_position;
        buffer_filling = o_cyc && i_ack;
        
        forwarding = buffer_filling && i_ready;
        
        o_adr = r_pc;
        
        if (forwarding) begin
            o_instr = i_dat[31:0];
            o_pc = {r_pc, 1'b0};
        end
        else begin
            o_instr = r_instr_buffer_position ? r_instr_buffer[63:32] : r_instr_buffer[31:0];
            o_pc = {r_instr_buffer_pc, r_instr_buffer_position};
        end
        
        if (i_rst) begin
            o_cyc = 0;
            o_stb = 0;
            o_valid = 0;
        end
        // FSM outputs
        else case (r_fsm_state)
            // instruction buffer invalid. make a request.
            0: begin
                o_cyc = 1;
                o_stb = 1;
                o_valid = 0;    // instruction buffer is invalid
            end
            // buffer is invalid, request has been made. wait.
            1: begin
                o_cyc = 1;
                o_stb = 0;
                o_valid = buffer_filling;   // forward response possible
            end
            // buffer is valid. make a request if it's about to be emptied
            2: begin
                o_cyc = buffer_emptying;
                o_stb = buffer_emptying;
                o_valid = 1;
            end
            // invalid state. values chosen based on what i reckon will be the
            // fewest gates :P
            3: begin
                o_cyc = 1;
                o_stb = 0;
                o_valid = 1;
            end
        endcase
    end
endmodule