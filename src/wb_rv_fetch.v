module fetch_stage(
    input i_clk,
    input i_rst,
    
    // wishbone bus for fetching instructions
    output wire o_cyc,
    output wire o_stb,
    input wire i_ack,
    input wire i_stall,
    input wire [63:0] i_dat,
    output wire [52:0] o_adr,
    
    // next-stage handshake signals
    input wire i_rdy,
    output reg o_valid,
    // next-stage data
    output reg [31:0] o_instr,
    output reg [52:0] o_pc,
);

endmodule