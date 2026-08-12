////////////////////////////////////////////////////////////////////////////////
// 
// Copyright (c) 2026 Buzz Pendarvis
//
// Filename: wb_rv_regfile.v
// Project: WishboneRV64
// Description: RISC-V register file. register 0 always maps to zero, all
//   others are general purpose.
//
////////////////////////////////////////////////////////////////////////////////

module regfile (
    input wire i_clk,
    input wire i_wr_en,

    input wire [4:0] i_r1_addr,
    input wire [4:0] i_r2_addr,
    input wire [4:0] i_wr_addr,
    
    output reg [63:0] o_r1_data,
    output reg [63:0] o_r2_data,
    input wire [63:0] i_wr_data
);
    // actual register state
    reg [63:0] registers [1:31];

    // register read interface
    always @(*) begin
        o_r1_data = (i_r1_addr == 0) ? 64'b0 : registers[i_r1_addr];
        o_r2_data = (i_r2_addr == 0) ? 64'b0 : registers[i_r2_addr];
    end

    // register write interface
    always @ (posedge i_clk) if (i_wr_addr != 0 && i_wr_en) begin
        registers[i_wr_addr] <= i_wr_data;
    end
endmodule
