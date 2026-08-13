////////////////////////////////////////////////////////////////////////////////
// 
// Copyright (c) 2026 Buzz Pendarvis
//
// Filename: wb_rv_exec.v
// Project: WishboneRV64
// Description: Holds the ALU, calculates addresses, resolves jumps
//
////////////////////////////////////////////////////////////////////////////////

module exec_stage(
    // generic control signals
    input wire i_clk,
    input wire i_rst,
    
    // previous stage handshake
    output reg o_ready,
    input wire i_valid,
    // previous stage data
    input wire [53:0] i_pc,
    input wire [63:0] i_imm,
    input wire [63:0] i_rs1_value,
    input wire [63:0] i_rs2_value,
    input wire i_use_pc,        // determines ALU inputs
    input wire i_use_imm,       // ^^^
    input wire [5:0] i_alu_op,  // ALU operation
    input wire i_load,          // Memory operation
    input wire i_store,         // ^^^
    input wire i_link,          // Writeback operation, for jumps
    input wire [4:0] i_wb_addr, // Writeback location
    input wire i_jump,
    input wire i_branch,
    input wire [1:0] i_branch_cond,
    
    // next stage handshake
    input wire i_ready,
    output reg o_valid,
    // next stage data
    output reg [63:0] o_alu_result,
    output reg [54:0] o_addr,
    output reg [63:0] o_data,
    output reg o_load,
    output reg o_store,
    output reg o_jump,
    output reg o_link,
    output reg [4:0] o_wb_addr,
    
    // control
    input wire i_stall
);
    reg r_valid;    // contents are valid
    
    // pipeline registers
    reg [53:0] r_pc;
    reg [63:0] r_imm;
    reg [63:0] r_rs1;
    reg [63:0] r_rs2;
    reg r_use_pc;
    reg r_use_imm;
    reg [5:0] r_op;
    reg r_load;
    reg r_store;
    reg r_link;
    reg [4:0] r_wb_addr;
    reg r_jump;
    reg r_branch;
    reg [1:0] r_branch_cond;
    
    wire [63:0] alu_result;
    //wire alu_cout;
    wire alu_ready;
    alu _alu(
        .clk(i_clk),
        .start(o_ready && i_valid),
        .func3(r_op[2:0]),
        .alt_op(r_op[3]),
        .word(r_op[4]),
        .m_mode(r_op[5]),
        .in1(r_use_pc ? {8'b0, r_pc, 1'b0} : r_rs1),
        .in2(r_use_imm ? r_imm : r_rs2),
        .out(alu_result),
        .cout(/*alu_cout*/),
        .out_valid(alu_ready)
    );
    
    // whether the branch condition is satisfied
    reg cond;
    
    always @ (*) begin
        // ready for new instructions when not stalling, and invalid or handshaking with next
        o_ready = !i_stall && (!r_valid || (o_valid && i_ready));
        o_valid = !i_rst && r_valid && alu_ready;
        cond = (r_branch_cond[0] ? alu_result[0] : alu_result == 0) ^ r_branch_cond[1];

        o_alu_result <= alu_result;
        o_jump = r_jump || (r_branch && !cond);
        o_addr = r_branch ? r_pc : r_rs1[55:2];
        if (r_branch) o_data = 0;
        else if (r_jump) o_data = r_imm;
        else o_data = r_rs2;
        o_load = r_load;
        o_store = r_store;
        o_link = r_link;
        o_wb_addr = r_wb_addr;
    end
    
    always @ (posedge i_clk) begin
        if (i_rst)
            r_valid <= 0;
        else if (i_valid && o_ready)
            r_valid <= 1;   // set whenever previous-stage handshake occurs
        else if (o_valid && i_ready)
            r_valid <= 0;   // reset if next-stage handshake occurs and it's not being loaded
        
        if (o_ready && i_valid) begin
            r_pc <= i_pc;
            r_imm <= i_imm;
            r_rs1 <= i_rs1_value;
            r_rs2 <= i_rs2_value;
            r_use_pc <= i_use_pc;
            r_use_imm <= i_use_imm;
            r_op <= i_alu_op;
            r_load <= i_load;
            r_store <= i_store;
            r_link <= i_link;
            r_wb_addr <= i_wb_addr;
            r_jump <= i_jump;
            r_branch <= i_branch;
            r_branch_cond <= i_branch_cond;
        end
    end
endmodule