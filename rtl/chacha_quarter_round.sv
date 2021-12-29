// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps
`default_nettype none

///////////////////////////////////////////////////////////////////////////////////////////////////
//
// From https://datatracker.ietf.org/doc/html/rfc8439:
//
// The basic operation of the ChaCha algorithm is the quarter round. It operates on four 32-bit
// unsigned integers, denoted a, b, c, and d. The operation is as follows (in C-like notation):
//
//   a += b; d ^= a; d <<<= 16;
//   c += d; b ^= c; b <<<= 12;
//   a += b; d ^= a; d <<<= 8;
//   c += d; b ^= c; b <<<= 7;
//
// Where "+" denotes integer addition modulo 2^32, "^" denotes a bitwise Exclusive OR (XOR), and
// "<<< n" denotes an n-bit left roll (towards the high bits).
//
//   a = 0x11111111
//   b = 0x01020304
//   c = 0x77777777
//   d = 0x01234567
//
//   c = c + d = 0x77777777 + 0x01234567 = 0x789abcde
//   b = b ^ c = 0x01020304 ^ 0x789abcde = 0x7998bfda
//   b = b <<< 7 = 0x7998bfda <<< 7 = 0xcc5fed3c
//
///////////////////////////////////////////////////////////////////////////////////////////////////

module chacha_quarter_round

    #(
    // Activate pipeline stages:
    //  - bit 0 : after the last stage, on output (c += d; b ^= c; b <<<= 7)
    //  - bit 1 : after the third stage (a += b; d ^= a; d <<<= 8)
    //  - bit 2 : after the second stage (c += d; b ^= c; b <<<= 12)
    //  - bit 3 : after the first stage (a += b; d ^= a; d <<<= 16)
        parameter [3:0] PIPELINE = 0
    ) (
        // Global interface
        input  logic        aclk,
        input  logic        aresetn,
        input  logic        srst,
        // Input stage
        input  logic        i_valid,
        output logic        i_ready,
        input  logic [31:0] i_a,
        input  logic [31:0] i_b,
        input  logic [31:0] i_c,
        input  logic [31:0] i_d,
        // Output stage
        output logic        o_valid,
        input  logic        o_ready,
        output logic [31:0] o_a,
        output logic [31:0] o_b,
        output logic [31:0] o_c,
        output logic [31:0] o_d
    );

    //:::::::::::::::::::::::::::::::
    // Local variables
    //:::::::::::::::::::::::::::::::

    logic [31:0] stg0_a;
    logic [31:0] stg0_b;
    logic [31:0] stg0_c;
    logic [31:0] stg0_d;
    logic [31:0] stg0_d_t;
    logic [31:0] stg1_a;
    logic [31:0] stg1_b_t;
    logic [31:0] stg1_b;
    logic [31:0] stg1_c;
    logic [31:0] stg1_d;
    logic [31:0] stg2_a;
    logic [31:0] stg2_b;
    logic [31:0] stg2_c;
    logic [31:0] stg2_d_t;
    logic [31:0] stg2_d;
    logic [31:0] stg3_a;
    logic [31:0] stg3_b_t;
    logic [31:0] stg3_b;
    logic [31:0] stg3_c;
    logic [31:0] stg3_d;

    //:::::::::::::::::::::::::::::::
    // First stage
    //:::::::::::::::::::::::::::::::

    assign stg0_a = i_a + i_b;
    assign stg0_b = i_b;
    assign stg0_c = i_c;
    assign stg0_d_t = i_d ^ stg0_a;
    assign stg0_d = {stg0_d_t[15:0], stg0_d_t[31:16]};

    //:::::::::::::::::::::::::::::::
    // Second stage
    //:::::::::::::::::::::::::::::::

    assign stg1_a = stg0_a;
    assign stg1_b_t = stg0_b ^ stg1_c;
    assign stg1_b = {stg1_b_t[19:0], stg1_b_t[31:20]};
    assign stg1_c = stg0_c + stg0_d;
    assign stg1_d = stg0_d;

    //:::::::::::::::::::::::::::::::
    // Third stage
    //:::::::::::::::::::::::::::::::

    assign stg2_a = stg1_a + stg1_b;
    assign stg2_b = stg1_b;
    assign stg2_c = stg1_c;
    assign stg2_d_t = stg1_d ^ stg2_a;
    assign stg2_d = {stg2_d_t[23:0], stg2_d_t[31:24]};

    //:::::::::::::::::::::::::::::::
    // Fourth stage
    //:::::::::::::::::::::::::::::::

    assign stg3_a = stg2_a;
    assign stg3_b_t = stg2_b ^ stg3_c;
    assign stg3_b = {stg3_b_t[6:0],stg3_b_t[31:7]};
    assign stg3_c = stg2_c + stg2_d;
    assign stg3_d = stg2_d;

    //:::::::::::::::::::::::::::::::
    // Output pipeline stage
    //:::::::::::::::::::::::::::::::

    chacha_pipeline
    #(
    .DATA_BUS_W  (4*32),
    .NB_PIPELINE (PIPELINE[0])
    )
    output_pipeline
    (
    .aclk    (aclk),
    .aresetn (aresetn),
    .srst    (srst),
    .i_valid (i_valid),
    .i_ready (i_ready),
    .i_data  ({stg3_a, stg3_b, stg3_c, stg3_d}),
    .o_valid (o_valid),
    .o_ready (o_ready),
    .o_data  ({o_a, o_b, o_c, o_d})
    );

endmodule

`resetall

