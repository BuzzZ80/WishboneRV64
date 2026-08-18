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
    input i_clk,
    input i_rst,
    
    // always ready, no o_ready
    input i_valid,
    
    input [63:0] i_wb_value,
    input [4:0] i_wb_addr,
    
    // control outputs
    output reg [63:0] o_wb_value,
    output reg [4:0] o_wb_addr
);  
    reg r_wb_value;
    reg r_wb_addr;
    
    always @ (posedge i_clk) begin
        r_wb_value <= i_wb_value;
        r_wb_addr <= i_wb_addr;
    end
    
    always @ (*) begin
        o_wb_value = r_wb_value;
        o_wb_addr = r_wb_addr;
    end
endmodule