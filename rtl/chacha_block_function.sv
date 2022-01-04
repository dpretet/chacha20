// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps
`default_nettype none

// ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
//
// This module implements the Chacha20 block function as decsribed in RFC8439.
//
// Computes 10x rounds of :
//
//      QUARTERROUND(0, 4, 8, 12)
//      QUARTERROUND(1, 5, 9, 13)
//      QUARTERROUND(2, 6, 10, 14)
//      QUARTERROUND(3, 7, 11, 15)
//      QUARTERROUND(0, 5, 10, 15)
//      QUARTERROUND(1, 6, 11, 12)
//      QUARTERROUND(2, 7, 8, 13)
//      QUARTERROUND(3, 4, 9, 14)
//
// Then once 10 rounds are computed: next state += initial_state
//
// Interfaces comply to AXI4-stream protocol, driving data when new ones are available, handshaking
// when both VALID and READY are asserted high. READY can be asserted when the slave is available,
// TVALID can't be deasserted once high. TDATA can change between two handshakes.
//
//      i_tdata = initial state
//      o_tdata = next state
//
// All fields (constant, key, block count, nonce) are here positioned as following:
//
//      i_tdata[127:  0] = {Constant3, Constant2, Constant1, Constant0}
//      i_tdata[383:128] = {Key15, key14, ..., key1, key0}
//      i_tdata[415:384] = Block count
//      i_tdata[511:416] = {Nonce2, Nonce1, Nonce0}
//
// For instance if key would be 00:01:02:03:04:05:06:07:... (bytes organized here from LSB to MSB),
// i_tdata should be formatted as:
//
//      0x..._07060504_03020100_6b206574_79622d32_3320646e_61707865;
//
// With:
//
//      - constant 0 = 61707865
//      - constant 1 = 3320646e
//      - constant 2 = 79622d32
//      - constant 3 = 6b206574
//
// ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

module chacha_block_function

    #(
        parameter DATA_W = 512,
        parameter ROUND_COUNT = 10

    )(
        // Global interface
        input  logic                  aclk,
        input  logic                  aresetn,
        input  logic                  srst,
        // Input interface, setting up the Chacha state
        input  logic                  i_tvalid,
        output logic                  i_tready,
        input  logic [DATA_W    -1:0] i_tdata,
        // Output interface, updating the Chacha state
        output logic                  o_tvalid,
        input  logic                  o_tready,
        output logic [DATA_W    -1:0] o_tdata
    );


    // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    // Local declarations
    // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

    localparam IDLE = 1'b0;
    localparam COMPUTE = 1'b1;
    localparam MAX_COUNT = ROUND_COUNT/2 - 1;

    logic              fsm;
    logic [4     -1:0] tvalid_stage0;
    logic [4     -1:0] tvalid_stage1;
    logic [4     -1:0] tready_stage0;
    logic [4     -1:0] tready_stage1;
    logic              valid_stage0;
    logic              ready_stage0;
    logic              valid_stage1;
    logic              ready_stage1;
    logic              activation;

    logic [5     -1:0] round_count;
    logic [DATA_W-1:0] state;
    logic [DATA_W-1:0] initial_state;
    logic [DATA_W-1:0] state_stage0;
    logic [DATA_W-1:0] state_stage1;
    logic [DATA_W-1:0] state_final;


    // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    // FSM controlling the initialization, computation and the reboot
    // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

    always @ (posedge aclk or negedge aresetn) begin

        if (!aresetn) begin
            fsm <= 1'b0;
            round_count <= 5'b0;
            initial_state <= {DATA_W{1'b0}};
        end else if (srst) begin
            fsm <= 1'b0;
            round_count <= 5'b0;
            initial_state <= {DATA_W{1'b0}};
        end else begin

            case (fsm)

                // IDLE state
                default: begin
                    if (i_tvalid) begin
                        initial_state <= i_tdata;
                        fsm <= COMPUTE;
                    end
                end

                // Computation state
                COMPUTE: begin

                    if (valid_stage1 && ready_stage0 && round_count!=MAX_COUNT) begin
                        round_count <= round_count + 1;
                    end else if (valid_stage1 && o_tready && round_count==MAX_COUNT) begin
                        round_count <= 5'b0;
                        fsm <= IDLE;
                    end
                end

            endcase
        end

    end

    assign i_tready = (fsm==IDLE && ready_stage0);

    assign activation = (fsm==IDLE && i_tvalid ||
                         fsm==COMPUTE && valid_stage1);

    assign state = (fsm==IDLE) ? i_tdata : state_stage1;

    assign valid_stage0 = &tvalid_stage0;
    assign valid_stage1 = &tvalid_stage1;
    assign ready_stage0 = &tready_stage0;
    assign ready_stage1 = &tready_stage1;

    generate 
        for (genvar i=0;i<16;i=i+1) begin: INIT_PLUS_20_ROUNDS
            assign state_final[i*32+:32] = initial_state[i*32+:32] + state_stage1[i*32+:32];
        end
    endgenerate

    assign o_tvalid = valid_stage1 && (round_count==MAX_COUNT);
    assign o_tdata = state_final;


    // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    //
    // The eight quarter round modules, organized in two stages.
    //
    // First stage, the column rounds:
    //
    //   - QUARTERROUND(0, 4, 8, 12)
    //   - QUARTERROUND(1, 5, 9, 13)
    //   - QUARTERROUND(2, 6, 10, 14)
    //   - QUARTERROUND(3, 7, 11, 15)
    //
    // Second stage, the diagomal rounds:
    //
    //   - QUARTERROUND(0, 5, 10, 15)
    //   - QUARTERROUND(1, 6, 11, 12)
    //   - QUARTERROUND(2, 7, 8, 13)
    //   - QUARTERROUND(3, 4, 9, 14)
    //
    // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

    // Stage 0, QUARTERROUND(0, 4, 8, 12)
    chacha_quarter_round
    #(
    .PIPELINE (4'b0001)
    )
    qr_0_0
    (
    .aclk    (aclk),
    .aresetn (aresetn),
    .srst    (srst),
    .i_valid (activation),
    .i_ready (tready_stage0[0]),
    .i_a     (state[0*32+:32]),
    .i_b     (state[4*32+:32]),
    .i_c     (state[8*32+:32]),
    .i_d     (state[12*32+:32]),
    .o_valid (tvalid_stage0[0]),
    .o_ready (ready_stage1),
    .o_a     (state_stage0[0*32+:32]),
    .o_b     (state_stage0[4*32+:32]),
    .o_c     (state_stage0[8*32+:32]),
    .o_d     (state_stage0[12*32+:32])
    );

    // Stage 0, QUARTERROUND(1, 5, 9, 13)
    chacha_quarter_round
    #(
    .PIPELINE (4'b0001)
    )
    qr_0_1
    (
    .aclk    (aclk),
    .aresetn (aresetn),
    .srst    (srst),
    .i_valid (activation),
    .i_ready (tready_stage0[1]),
    .i_a     (state[1*32+:32]),
    .i_b     (state[5*32+:32]),
    .i_c     (state[9*32+:32]),
    .i_d     (state[13*32+:32]),
    .o_valid (tvalid_stage0[1]),
    .o_ready (ready_stage1),
    .o_a     (state_stage0[1*32+:32]),
    .o_b     (state_stage0[5*32+:32]),
    .o_c     (state_stage0[9*32+:32]),
    .o_d     (state_stage0[13*32+:32])
    );

    // Stage 0, QUARTERROUND(2, 6, 10, 14)
    chacha_quarter_round
    #(
    .PIPELINE (4'b0001)
    )
    qr_0_2
    (
    .aclk    (aclk),
    .aresetn (aresetn),
    .srst    (srst),
    .i_valid (activation),
    .i_ready (tready_stage0[2]),
    .i_a     (state[2*32+:32]),
    .i_b     (state[6*32+:32]),
    .i_c     (state[10*32+:32]),
    .i_d     (state[14*32+:32]),
    .o_valid (tvalid_stage0[2]),
    .o_ready (ready_stage1),
    .o_a     (state_stage0[2*32+:32]),
    .o_b     (state_stage0[6*32+:32]),
    .o_c     (state_stage0[10*32+:32]),
    .o_d     (state_stage0[14*32+:32])
    );

    // Stage 0, QUARTERROUND(3, 7, 11, 15)
    chacha_quarter_round
    #(
    .PIPELINE (4'b0001)
    )
    qr_0_3
    (
    .aclk    (aclk),
    .aresetn (aresetn),
    .srst    (srst),
    .i_valid (activation),
    .i_ready (tready_stage0[3]),
    .i_a     (state[3*32+:32]),
    .i_b     (state[7*32+:32]),
    .i_c     (state[11*32+:32]),
    .i_d     (state[15*32+:32]),
    .o_valid (tvalid_stage0[3]),
    .o_ready (ready_stage1),
    .o_a     (state_stage0[3*32+:32]),
    .o_b     (state_stage0[7*32+:32]),
    .o_c     (state_stage0[11*32+:32]),
    .o_d     (state_stage0[15*32+:32])
    );

    // Stage 1, QUARTERROUND(0, 5, 10, 15)
    chacha_quarter_round
    #(
    .PIPELINE (4'b0001)
    )
    qr_1_0
    (
    .aclk    (aclk),
    .aresetn (aresetn),
    .srst    (srst),
    .i_valid (valid_stage0),
    .i_ready (tready_stage1[0]),
    .i_a     (state_stage0[0*32+:32]),
    .i_b     (state_stage0[5*32+:32]),
    .i_c     (state_stage0[10*32+:32]),
    .i_d     (state_stage0[15*32+:32]),
    .o_valid (tvalid_stage1[0]),
    .o_ready (ready_stage0),
    .o_a     (state_stage1[0*32+:32]),
    .o_b     (state_stage1[5*32+:32]),
    .o_c     (state_stage1[10*32+:32]),
    .o_d     (state_stage1[15*32+:32])
    );

    // Stage 1, QUARTERROUND(1, 6, 11, 12)
    chacha_quarter_round
    #(
    .PIPELINE (4'b0001)
    )
    qr_1_1
    (
    .aclk    (aclk),
    .aresetn (aresetn),
    .srst    (srst),
    .i_valid (valid_stage0),
    .i_ready (tready_stage1[1]),
    .i_a     (state_stage0[1*32+:32]),
    .i_b     (state_stage0[6*32+:32]),
    .i_c     (state_stage0[11*32+:32]),
    .i_d     (state_stage0[12*32+:32]),
    .o_valid (tvalid_stage1[1]),
    .o_ready (ready_stage0),
    .o_a     (state_stage1[1*32+:32]),
    .o_b     (state_stage1[6*32+:32]),
    .o_c     (state_stage1[11*32+:32]),
    .o_d     (state_stage1[12*32+:32])
    );

    // Stage 1, QUARTERROUND(2, 7, 8, 13)
    chacha_quarter_round
    #(
    .PIPELINE (4'b0001)
    )
    qr_1_2
    (
    .aclk    (aclk),
    .aresetn (aresetn),
    .srst    (srst),
    .i_valid (valid_stage0),
    .i_ready (tready_stage1[2]),
    .i_a     (state_stage0[2*32+:32]),
    .i_b     (state_stage0[7*32+:32]),
    .i_c     (state_stage0[8*32+:32]),
    .i_d     (state_stage0[13*32+:32]),
    .o_valid (tvalid_stage1[2]),
    .o_ready (ready_stage0),
    .o_a     (state_stage1[2*32+:32]),
    .o_b     (state_stage1[7*32+:32]),
    .o_c     (state_stage1[8*32+:32]),
    .o_d     (state_stage1[13*32+:32])
    );

    // Stage 1, QUARTERROUND(3, 4, 9, 14)
    chacha_quarter_round
    #(
    .PIPELINE (4'b0001)
    )
    qr_1_3
    (
    .aclk    (aclk),
    .aresetn (aresetn),
    .srst    (srst),
    .i_valid (valid_stage0),
    .i_ready (tready_stage1[3]),
    .i_a     (state_stage0[3*32+:32]),
    .i_b     (state_stage0[4*32+:32]),
    .i_c     (state_stage0[9*32+:32]),
    .i_d     (state_stage0[14*32+:32]),
    .o_valid (tvalid_stage1[3]),
    .o_ready (ready_stage0),
    .o_a     (state_stage1[3*32+:32]),
    .o_b     (state_stage1[4*32+:32]),
    .o_c     (state_stage1[9*32+:32]),
    .o_d     (state_stage1[14*32+:32])
    );


endmodule

`resetall
