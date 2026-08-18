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
    input wire i_instr_stall,
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
    wire fetch_valid;
    wire [31:0] fetch_instr;
    wire [53:0] fetch_pc;

    wire decode_ready;
    wire decode_valid;
    wire [53:0] decode_pc;
    wire [63:0] decode_imm;
    wire [63:0] decode_rs1_value;
    wire [63:0] decode_rs2_value;
    wire decode_use_pc;
    wire decode_use_imm;
    wire [5:0] decode_alu_op;
    wire decode_load;
    wire decode_store;
    wire decode_link;
    wire [4:0] decode_wb_addr;
    wire decode_jump;
    wire decode_branch;
    wire [1:0] decode_branch_cond;

    wire exec_ready;
    

    fetch_stage _fetch (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .o_cyc(o_instr_cyc),
        .o_stb(o_instr_stb),
        .i_ack(i_instr_ack),
        .i_stall(i_instr_stall),
        .i_dat(i_instr_dat),
        .o_adr(o_instr_adr),
        .i_ready(decode_ready),
        .o_valid(fetch_valid),
        .o_instr(fetch_instr),
        .o_pc(fetch_pc),
        .in_ctrl_jump(),
        .in_ctrl_jump_base(),
        .in_ctrl_jump_offset()
    );

    decode_stage _decode (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .o_ready(decode_ready),
        .i_valid(fetch_valid),
        .i_instr(fetch_instr),
        .i_pc(fetch_pc),
        .i_ready(exec_ready),
        .o_valid(decode_valid),
        .o_pc(decode_pc),
        .o_imm(decode_imm),
        .o_rs1_value(decode_rs1_value),
        .o_rs2_value(decode_rs2_value),
        .o_use_pc(decode_use_pc),
        .o_use_imm(decode_use_imm),
        .o_alu_op(decode_alu_op),
        .o_load(decode_load),
        .o_store(decode_store),
        .o_link(decode_link),
        .o_wb_addr(decode_wb_addr),
        .o_jump(decode_jump),
        .o_branch(decode_branch),
        .o_branch_cond(decode_branch_cond),
        .i_stall(),
        .i_wb_addr(),
        .i_wb_value(),
        .o_rs1_addr(),
        .o_rs2_addr()
    );

    exec_stage _exec (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .o_ready(exec_ready),
        .i_valid(decode_valid),
        .i_pc(decode_pc),
        .i_imm(decode_imm),
        .i_rs1_value(decode_rs1_value),
        .i_rs2_value(decode_rs2_value),
        .i_use_pc(decode_use_pc),
        .i_use_imm(decode_use_imm),
        .i_alu_op(decode_alu_op),
        .i_load(decode_load),
        .i_store(decode_store),
        .i_link(decode_link),
        .i_wb_addr(decode_wb_addr),
        .i_jump(decode_jump),
        .i_branch(decode_branch),
        .i_branch_cond(decode_branch_cond),
        .i_ready(),
        .o_valid(),
        .o_alu_result(),
        .o_addr(),
        .o_data(),
        .o_load(),
        .o_store(),
        .o_jump(),
        .o_link(),
        .o_wb_addr(),
        .i_stall()
    );

    memory_stage _memory (
        .i_clk(),
        .i_rst(),
        .o_cyc(),
        .o_stb(),
        .o_we(),
        .i_ack(),
        .i_stall(),
        .i_dat(),
        .o_dat(),
        .o_adr(),
        .o_ready(),
        .i_valid(),
        .i_alu_result(),
        .i_addr(),
        .i_data(),
        .i_load(),
        .i_store(),
        .i_jump(),
        .i_link(),
        .i_wb_addr(),
        .o_valid(),
        .o_wb_value(),
        .o_wb_addr(),
        .o_jump(),
        .o_jump_base(),
        .o_jump_offset()
    );
    
    writeback_stage _writeback (
        .i_clk(),
        .i_rst(),
        .i_valid(),
        .i_wb_value(),
        .i_wb_addr(),
        .o_wb_value(),
        .o_wb_addr()
    );

endmodule