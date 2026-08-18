////////////////////////////////////////////////////////////////////////////////
// 
// Copyright (c) 2026 Buzz Pendarvis
//
// Filename: wb_rv_decode.v
// Project: WishboneRV64
// Description: Decodes instructions and fetches register values from the
//   register file (which is declared inside of this module too)
//
////////////////////////////////////////////////////////////////////////////////

module decode_stage (
    // generic control signals
    input wire i_clk,
    input wire i_rst,
    
    // previous stage handshake
    output reg o_ready,
    input wire i_valid,
    // previous stage data
    input wire [31:0] i_instr,
    input wire [53:0] i_pc,
    
    // next stage handshake
    input wire i_ready,
    output reg o_valid,
    // next stage data
    output reg [53:0] o_pc,
    output reg [63:0] o_imm,
    output reg [63:0] o_rs1_value,
    output reg [63:0] o_rs2_value,
    output reg o_use_pc,        // determines ALU inputs
    output reg o_use_imm,       // ^^^
    output reg [5:0] o_alu_op,  // ALU operation
    output reg o_load,          // Memory operation
    output reg o_store,         // ^^^
    output reg o_link,          // Writeback operation, for jumps
    output reg [4:0] o_wb_addr, // Writeback location
    output reg o_jump,
    output reg o_branch,
    output reg [1:0] o_branch_cond,

    // control
    input wire i_stall,
    input wire [4:0] i_wb_addr,
    input wire [63:0] i_wb_value,
    output reg [4:0] o_rs1_addr, // used for detecting hazards
    output reg [4:0] o_rs2_addr,
    output reg o_regs_valid
);
    reg r_valid;
    reg [31:0] r_instr;
    reg [53:0] r_pc;
    
    wire [63:0] port_1_data;
    wire [63:0] port_2_data;
    
    reg [2:0] imm_type;
    
    reg uses_rs1;
    reg uses_rs2;
    reg force_rs1_low;
    
    regfile _regfile(
        .i_clk(i_clk),
        .i_wr_en(1),
        .i_r1_addr(r_instr[19:15]),
        .i_r2_addr(r_instr[24:20]),
        .i_wr_addr(i_wb_addr),
        .o_r1_data(port_1_data),
        .o_r2_data(port_2_data),
        .i_wr_data(i_wb_value)
    );
    
    always @ (posedge i_clk) begin
        if (i_rst)
            r_valid <= 0;
        else if (i_valid && o_ready)
            r_valid <= 1;   // set whenever previous-stage handshake occurs
        else if (o_valid && i_ready)
            r_valid <= 0;   // reset if next-stage handshake occurs and it's not being loaded
        
        if (o_ready && i_valid) begin
            r_instr <= i_instr;
            r_pc <= i_pc;
        end
    end
    
    always @ (*) begin
        // ready for new instructions when not stalling, and invalid or handshaking with next
        o_ready = !i_stall && (!r_valid || (o_valid && i_ready));
        // output is valid when internal state is valid and not resetting
        o_valid = !i_stall && r_valid;
        o_regs_valid = r_valid;
        
        imm_type = 0;
        o_use_pc = 0;
        o_use_imm = 0;
        force_rs1_low = 0;
        o_alu_op = 0;
        o_load = 0;
        o_store = 0;
        o_wb_addr = r_instr[11:7];
        
        o_jump = 0;
        o_branch = 0;
        o_branch_cond = {r_instr[12], r_instr[14]};
        o_link = 0;
        
        case (r_instr[6:0])
            // load instructions
            7'b0000011: begin
                imm_type = 1;
                o_use_imm = 1;
                o_load = 1;
            end
            // immediate ALU operations
            7'b0010011: begin
                imm_type = 1;
                o_use_imm = 1;
                o_alu_op = {2'b00, r_instr[30] && (r_instr[14:12] == 3'b101), r_instr[14:12]};
            end
            // AUIPC
            7'b0010111: begin
                imm_type = 4;
                o_use_imm = 1;
                o_use_pc = 1;
            end
            // immediate word ALU operations
            7'b0011011: begin
                imm_type = 1;
                o_use_imm = 1;
                o_alu_op = {2'b01, r_instr[30] && (r_instr[14:12] == 3'b101), r_instr[14:12]};
            end
            // store instructions
            7'b0100011: begin
                imm_type = 2;
                o_use_imm = 1;
                o_store = 1;
            end
            // register ALU operations
            7'b0110011: begin
                imm_type = 0;
                o_alu_op = {r_instr[25], 1'b0, r_instr[30], r_instr[14:12]};
            end
            // LUI
            7'b0110111: begin
                imm_type = 4;
                o_use_imm = 1;
                force_rs1_low = 1;
            end
            // register word ALU operations
            7'b0111011: begin
                imm_type = 0;
                o_alu_op = {3'b010, r_instr[14:12]};
            end
            // Branch
            7'b1100011: begin
                imm_type = 3;
                o_alu_op[0] = r_instr[13];
                o_alu_op[1] = r_instr[14];
                o_alu_op[3] = !r_instr[14];
                o_branch = 1;
            end
            // JALR
            7'b1100111: begin
                imm_type = 1;
                o_use_imm = 1;
                o_alu_op = 0;
                o_jump = 1;
                o_link = 1;
            end
            // JAL
            7'b1101111: begin
                imm_type = 5;
                o_use_pc = 1;
                o_alu_op = 0;
                o_jump = 1;
                o_link = 1;
            end
            default: begin
                // do nothing
            end
        endcase
        
        case (imm_type)
            // R type
            0: begin
                o_imm = 0;
                uses_rs1 = 1;
                uses_rs2 = 1;
            end
            // I-type
            1: begin
                o_imm = {{52{r_instr[31]}}, r_instr[31:20]};
                uses_rs1 = 1;
                uses_rs2 = 0;
            end
            // S-type
            2: begin
                o_imm = {{52{r_instr[31]}}, r_instr[31:25], r_instr[11:7]};
                uses_rs1 = 1;
                uses_rs2 = 1;
            end
            // B-type
            3: begin
                o_imm = {{52{r_instr[31]}}, r_instr[7], r_instr[30:25], r_instr[11:8], 1'b0};
                uses_rs1 = 1;
                uses_rs2 = 1;
            end
            // U-type
            4: begin
                o_imm = {{32{r_instr[31]}}, r_instr[31:12], 12'b0};
                uses_rs1 = 0;
                uses_rs2 = 0;
            end
            // J-type
            5: begin
                o_imm = {{44{r_instr[31]}}, r_instr[19:12], r_instr[20], r_instr[30:21], 1'b0};
                uses_rs1 = 0;
                uses_rs2 = 0;
            end
            default: begin
                o_imm = 0;
                uses_rs1 = 0;
                uses_rs2 = 0;
            end
        endcase
        
        o_rs1_addr = uses_rs1 ? r_instr[19:15] : 0;
        o_rs2_addr = uses_rs2 ? r_instr[24:20] : 0;
        
        o_rs1_value = force_rs1_low ? 0 : port_1_data;
        o_rs2_value = port_2_data;
        
        o_pc = r_pc;
    end
endmodule
