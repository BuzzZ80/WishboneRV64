////////////////////////////////////////////////////////////////////////////////
// 
// Copyright (c) 2026 Buzz Pendarvis
//
// Filename: wb_rv_writeback.v
// Project: WishboneRV64
// Description: Handles writing results back into register file
//
////////////////////////////////////////////////////////////////////////////////

module writeback_stage (
    // generic control signals
    input wire i_clk,
    input wire i_rst,
    
    // always ready, no o_ready
    input wire i_valid,
    
    input wire [63:0] i_wb_value,
    input wire [4:0] i_wb_addr,
    
    // control outputs
    output reg [63:0] o_wb_value,
    output reg [4:0] o_wb_addr
);  
    reg r_valid;
    reg [63:0] r_wb_value;
    reg [4:0] r_wb_addr;
    
    always @ (posedge i_clk) begin
        r_valid <= i_valid;
        r_wb_value <= i_wb_value;
        r_wb_addr <= i_wb_addr;
    end
    
    always @ (*) begin
        o_wb_value = r_wb_value;
        o_wb_addr = r_valid ? r_wb_addr : 0;
    end
endmodule