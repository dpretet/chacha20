// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps
`default_nettype none

// ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
//
// This module is the main of Chacha20 IP core. It receives and transmits a data stream to encrypt
// or decrypt with the key and nonce setup in the IP's CSRs. The block count is automatically 
// incremented when the input interface injects 64 bytes of data. The block count is reset back to
// 0 when TLAST is asserted, TLAST being mirrored on output.
//
// Input and output interfaces formatted as in RFC8439, page 23 with the text illustrating a 
// test vector:
//
// Byte number               Data phases                              Bits index
//
//     000        4c 61 64 69 65 .... 65 6e 74 6c     [127:120] = 4c [119:112] = 61 .... [7:0] 6c
//     016        65 6d 65 6e 20 .... 63 6c 61 73     [127:120] = 65 [119:112] = 6d .... [7:0] 73
//
// This makes possible to visualize the data in ASCII in a waveform viewer.
//
// ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

module chacha_stream_engine

    #(
        parameter DATA_W = 512,
        parameter KEY_W = 256,
        parameter NOUNCE_W = 96,
        parameter COUNT_W = 32,
        parameter ROUND_COUNT = 20

    )(
        // Global interface
        input  logic                  aclk,
        input  logic                  aresetn,
        input  logic                  srst,
        // Keyw & nouce
        input  logic [KEY_W     -1:0] key,
        input  logic [NOUNCE_W  -1:0] nounce,
        // Input interface
        input  logic                  i_tvalid,
        output logic                  i_tready,
        input  logic [DATA_W    -1:0] i_tdata,
        input  logic                  i_tlast,
        // Output interface
        output logic                  o_tvalid,
        input  logic                  o_tready,
        output logic [DATA_W    -1:0] o_tdata,
        output logic                  o_tlast
    );


    // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    // Local variables and parameters
    // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

    // The first four constant words [0-3] as specified in RFC8439:
    localparam             CONSTANT0 = 32'h61707865;
    localparam             CONSTANT1 = 32'h3320646E;
    localparam             CONSTANT2 = 32'h79622D32;
    localparam             CONSTANT3 = 32'h6B206574;

    logic [32        -1:0] block_count;

    // Control fsm
    typedef enum logic[3:0] {
        IDLE = 0,
        PREFETCH = 1,
        RELOAD = 2,
        FENCE = 3,
        FENCE_I = 4,
        WFI = 5,
        EBREAK = 6
    } cfsm_t;

    cfsm_t cfsm;


    // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    //
    // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::


    logic                  i_tvalid;
    logic                  i_tready;
    logic [DATA_W    -1:0] i_tdata;
    logic                  o_tvalid;
    logic                  o_tready;
    logic [DATA_W    -1:0] o_tdata;

    chacha_block_function block_function
    (
        .aclk     (aclk),
        .aresetn  (aresetn),
        .srst     (srst),
        .i_tvalid (i_tvalid),
        .i_tready (i_tready),
        .i_tdata  (i_tdata),
        .o_tvalid (o_tvalid),
        .o_tready (o_tready),
        .o_tdata  (o_tdata)
    );

endmodule

`resetall

