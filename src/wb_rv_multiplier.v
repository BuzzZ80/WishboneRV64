////////////////////////////////////////////////////////////////////////////////
// 
// Copyright (c) 2026 Buzz Pendarvis
//
// Filename: wb_rv_multiplier.v
// Project: WishboneRV64
// Description: Implements addition, multiplication, and division
//
////////////////////////////////////////////////////////////////////////////////

module multiplier(
    input clk,
    input start,

    input word,     // 32 bit mode
    input bypass,   // isolate the 64b adder
    input subtract, // inverts in2 and sets carry in for bypass
    input high,     // get high word from multiplication result
    input divide,   // perform division instead of multiplication
    input in1_unsigned,
    input in2_unsigned,
    output reg busy,

    input [63:0] in1,
    input [63:0] in2,
    output reg [63:0] result,
    output reg cout
);
    // genereal purpose adder
    reg adder_carry_in;
    reg [63:0] adder_in1;
    reg [63:0] adder_in2;
    reg [63:0] adder_sum;
    reg adder_carry_out;
    reg adder_subtract;
    always @ (*) begin
        {adder_carry_out, adder_sum} = {1'b0, adder_in1} + ({1'b0, {64{adder_subtract}}} ^ {1'b0, adder_in2}) + adder_carry_in;
    end
    /*add64 adder(
        .carry0(adder_carry_in),
        .a(adder_in1),
        .b(adder_in2),
        .sum({adder_carry_out, adder_sum}),
        .subtract(adder_subtract)
    );*/

    // logic signals between carry save adders
    reg [127:0] stage1_sum;
    reg [127:0] stage1_carry;
    reg [127:0] stage2_sum;
    reg [127:0] stage2_carry;
    reg [127:0] stage3_sum;
    reg [127:0] stage3_carry;
    reg [127:0] stage4_sum;
    reg [127:0] stage4_carry;
    // carry save adder sequential loop registers
    reg [127:0] accumulator;
    reg [127:0] saved_carries;
    reg [127:0] mplicand;   // multiplicand (shifted)
    reg [63:0] mplier;      // multiplier   (shifted)

    // state -1: await start and adjust multiplicand
    // state 0: adjust multiplier
    // state 1: multiplication algorithm
    // state 2: carry adition
    // state 3: sign adjust

    reg [2:0] state;
    reg [5:0] stepcount;    // sub-states
    reg busy_flag;          // internal busy state
    reg adder_carry_save;   // for inverting whole accumulator

    // keeps track of what sign the result should have
    reg sign_adjust;

    // state machine
    reg [2:0] next_state;
    reg [5:0] next_stepcount;
    reg [127:0] next_mplicand;
    reg [63:0] next_mplier;
    always @(*) begin
        result = adder_sum;
        cout = adder_carry_out;
        busy = busy_flag || start;
        // if bypassing multiplication to use adder
        if (bypass) begin
            adder_carry_in = 0;
            adder_subtract = subtract;
            adder_in1 = in1;
            adder_in2 = in2;

            // set others to default values or keep them the same
            next_state = 3'b000;
            next_stepcount = 0;
            next_mplicand = mplicand;
            next_mplier = mplier;
        end
        else if (start) begin
            // set up multiplicand sign
            adder_carry_in = 0;
            adder_subtract = in1[63] && !in1_unsigned;
            adder_in1 = 0;
            adder_in2 = in1;

            // go to next state
            next_state = ((!divide && in1 == 0) || in2 == 0) ? 3'b111 : 3'b000;
            next_stepcount = stepcount;
            next_mplicand = {64'b0, adder_sum}; // update multiplicand
            next_mplier = mplier;
        end
        else case (state)
            3'b000: begin
                // set up multiplier sign
                adder_carry_in = 0;
                adder_subtract = in2[63] && !in2_unsigned;
                adder_in1 = 0;
                adder_in2 = in2;

                // go to next state
                next_state = 3'b001;
                next_stepcount = divide ? 63 : 15;
                next_mplicand = mplicand;
                next_mplier = adder_sum; // update multiplier
            end
            3'b001: begin
                // change algorithm if dividing
                if (divide) begin
                    adder_carry_in = 0;
                    adder_subtract = 1;
                    adder_in1 = (accumulator[127:64] << 1) | {63'b0, mplicand[63]};
                    adder_in2 = mplier;

                    next_state = (stepcount == 0) ? 3'b100 : 3'b001;
                    next_stepcount = stepcount - 1;
                    next_mplicand = mplicand << 1;
                    next_mplier = mplier;
                end
                else begin
                    adder_carry_in = 0;
                    adder_subtract = 0;
                    adder_in1 = 0;
                    adder_in2 = 0;

                    next_state = (stepcount == 0) ? 3'b010 : 3'b001;
                    next_stepcount = stepcount - 1;
                    next_mplicand = mplicand << 4;
                    next_mplier = mplier >> 4;
                end
            end
            3'b010: begin
                adder_carry_in = 0;
                adder_subtract = 0;
                adder_in1 = accumulator[63:0];
                adder_in2 = saved_carries[63:0];

                next_state = high ? 3'b011 : 3'b100;
                next_stepcount = 0;
                next_mplicand = mplicand;
                next_mplier = mplier;
            end
            3'b011: begin
                adder_carry_in = adder_carry_save;
                adder_subtract = 0;
                adder_in1 = accumulator[127:64];
                adder_in2 = saved_carries[127:64];

                next_state = 3'b100;
                next_stepcount = 0;
                next_mplicand = mplicand;
                next_mplier = mplier;
            end
            3'b100: begin
                adder_carry_in = 0;
                adder_subtract = sign_adjust;
                adder_in1 = 0;
                adder_in2 = accumulator[63:0];

                next_state = high ? 3'b101 : 3'b110;
                next_stepcount = 0;
                next_mplicand = mplicand;
                next_mplier = mplier;
            end
            3'b101: begin
                adder_carry_in = divide ? 0 : sign_adjust ^ adder_carry_save;
                adder_subtract = divide ? (!in1_unsigned && in1[63]) : sign_adjust;
                adder_in1 = 0;
                adder_in2 = accumulator[127:64];

                next_state = 3'b111;
                next_stepcount = 0;
                next_mplicand = mplicand;
                next_mplier = mplier;
            end
            default: begin
                adder_carry_in = 0;
                adder_subtract = 0;
                adder_in1 = 0;
                adder_in2 = high ? accumulator[127:64] : accumulator[63:0];

                next_state = 3'b111;
                next_stepcount = 0;
                next_mplicand = mplicand;
                next_mplier = mplier;
            end
        endcase
    end

    always @ (posedge clk) begin
        state <= next_state;
        stepcount <= next_stepcount;
        mplicand <= next_mplicand;
        mplier <= next_mplier;

        adder_carry_save <= adder_carry_out;

        if (start) begin
            accumulator <= 0;
            saved_carries <= 0;
            sign_adjust <= (!in1_unsigned && in1[63]) ^ (!in2_unsigned && in2[63]);
            busy_flag <= 1;
        end
        else if (state == 3'b001) begin
            if (divide) begin
                accumulator <= {
                    adder_carry_out ? adder_sum : adder_in1,
                    accumulator[63:0] | (adder_carry_out ? 64'b1 << stepcount : 0)
                };
            end
            else begin
                accumulator <= stage4_sum;
                saved_carries <= stage4_carry;
            end
        end
        else if (state == 3'b010 || state == 3'b100) begin
            accumulator[63:0] <= adder_sum;
        end
        else if (state == 3'b011 || state == 3'b101) begin
            accumulator[127:64] <= adder_sum;
        end
        else if (busy_flag && state == 3'b111) begin
            if (!divide && (in1 == 0 || in2 == 0)) begin
                accumulator <= 0;
            end
            else if (divide && in2 == 0) begin
                accumulator <= {in1, {64{1'b1}}};
            end
            busy_flag <= 0;
        end
    end

    // carry save adder logic
    always @(*) begin
        stage1_sum = accumulator ^ saved_carries ^ (mplier[0] ? mplicand : 0);
        stage1_carry = {(accumulator & saved_carries) | ((accumulator ^ saved_carries) & (mplier[0] ? mplicand : 0))} << 1;
        stage2_sum = stage1_sum ^ stage1_carry ^ (mplier[1] ? mplicand << 1 : 0);
        stage2_carry = {(stage1_sum & stage1_carry) | ((stage1_sum ^ stage1_carry) & (mplier[1] ? mplicand << 1 : 0))} << 1;
        stage3_sum = stage2_sum ^ stage2_carry ^ (mplier[2] ? mplicand << 2 : 0);
        stage3_carry = {(stage2_sum & stage2_carry) | ((stage2_sum ^ stage2_carry) & (mplier[2] ? mplicand << 2 : 0))} << 1;
        stage4_sum = stage3_sum ^ stage3_carry ^ (mplier[3] ? mplicand << 3 : 0);
        stage4_carry = {(stage3_sum & stage3_carry) | ((stage3_sum ^ stage3_carry) & (mplier[3] ? mplicand << 3 : 0))} << 1;
    end
endmodule