////////////////////////////////////////////////////////////////////////////////
// 
// Copyright (c) 2026 Buzz Pendarvis
//
// Filename: wb_rv_alu.v
// Project: WishboneRV64
// Description: Arithmetic/Logic Unit
//
////////////////////////////////////////////////////////////////////////////////

module alu(
    input clk,
    input start,

    input [2:0] func3,
    input alt_op,
    input word,
    input m_mode,

    input [63:0] in1,
    input [63:0] in2,
    output reg [63:0] out,
    output wire cout,
    output reg out_valid
);  
    reg [63:0] in1_alt;
    reg [63:0] in2_alt;
    reg [63:0] result;

    wire mult_high;
    assign mult_high = (!func3[2] && (func3[1] || func3[0])) || (func3[2] && func3[1]);
    wire [63:0] mult_result;
    wire mult_busy;
    multiplier int_multiplier (
        .clk(clk),
        .start(m_mode && start),
        .word(word),
        .bypass(!m_mode),
        .subtract(alt_op | ({m_mode, func3[2:1]} == 3'b001)),
        .high(mult_high),
        .divide(func3[2]),
        .in1_unsigned(func3 == 3'b011 || (func3[2] && func3[0])),
        .in2_unsigned(func3[2:1] == 2'b01 || (func3[2] && func3[0])),
        .busy(mult_busy),
        .in1(in1_alt),
        .in2(in2_alt),
        .result(mult_result),
        .cout(cout)
    );

    always @(*) begin
        in1_alt = word ? {{32{in1[31]}}, in1[31:0]} : in1;
        in2_alt = word ? {{32{in2[31]}}, in2[31:0]} : in2;
        case ({m_mode, func3})
            4'b0000: result = mult_result;
            4'b0001: result = in1_alt << (in2_alt & 64'h3F);
            4'b0010: result = (cout ^ in1_alt[63] ^ in2_alt[63]) ? 0 : 1;
            4'b0011: result = cout ? 0 : 1;
            4'b0100: result = in1_alt ^ in2_alt;
            4'b0101: if (alt_op) result = $signed(in1_alt) >>> $signed(in2_alt & 64'h3F);
                else result = in1_alt >> (in2_alt & 64'h3F);
            4'b0110: result = in1_alt | in2_alt;
            4'b0111: result = in1_alt & in2_alt;
            4'b1000: result = mult_result;
            4'b1001: result = mult_result;
            4'b1010: result = mult_result;
            4'b1011: result = mult_result;
            4'b1100: result = mult_result;
            4'b1101: result = mult_result;
            4'b1110: result = mult_result;
            4'b1111: result = mult_result;
        endcase
        if (word) result = {{32{result[31]}}, result[31:0]};
    end

    always @(*) begin
        out = result;
        out_valid = m_mode ? !mult_busy : 1;
    end
endmodule