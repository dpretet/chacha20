/// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"

/// Specify the module to load or on files.f
`include "../../rtl/chacha_block_function.sv"

`timescale 1 ns / 100 ps

module chacha_block_function_testbench();

    `SVUT_SETUP

    parameter DATA_W = 512;
    parameter ROUND_COUNT = 20;

    logic                  aclk;
    logic                  aresetn;
    logic                  srst;
    logic                  en;
    logic                  i_tvalid;
    logic                  i_tready;
    logic [DATA_W    -1:0] i_tdata;
    logic                  o_tvalid;
    logic                  o_tready;
    logic [DATA_W    -1:0] o_tdata;
    logic [DATA_W    -1:0] expected;
    integer                timeout;

    chacha_block_function
    #(
    .DATA_W      (DATA_W),
    .ROUND_COUNT (ROUND_COUNT)
    )
    dut
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

    // To create a clock:
    initial aclk = 0;
    always #2 aclk = ~aclk;

    // To dump data for visualization:
    initial begin
        $dumpfile("chacha_block_function_testbench.vcd");
        $dumpvars(0, chacha_block_function_testbench);
    end

    // Setup time format when printing with $realtime
    initial $timeformat(-9, 1, "ns", 8);

    task setup(msg="");
    begin
        aresetn = 1'b0;
        srst = 1'b0;
        en = 1'b0;
        expected = 512'h0;
        o_tready = 1'b1;
        timeout = 0;
        #14;
        aresetn = 1'b1;
    end
    endtask

    task teardown(msg="");
    begin
    end
    endtask

    always @ (posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            i_tvalid <= 1'b0;
            i_tdata <= 512'h0;
        end else if (srst) begin
            i_tvalid <= 1'b0;
            i_tdata <= 512'h0;
        end else begin

            i_tdata = 512'h00000000_4a000000_09000000_00000001_1f1e1d1c_1b1a1918_17161514_13121110_0f0e0d0c_0b0a0908_07060504_03020100_6b206574_79622d32_3320646e_61707865;

            if (i_tvalid && i_tready) begin
                i_tvalid <= 1'b0;
            end else if (en) begin
                i_tvalid <= 1'b1;
            end
        end
    end

    `TEST_SUITE("SUITE_NAME")

    ///    Available macros:"
    ///
    ///    - `MSG("message"):       Print a raw white message
    ///    - `INFO("message"):      Print a blue message with INFO: prefix
    ///    - `SUCCESS("message"):   Print a green message if SUCCESS: prefix
    ///    - `WARNING("message"):   Print an orange message with WARNING: prefix and increment warning counter
    ///    - `CRITICAL("message"):  Print a purple message with CRITICAL: prefix and increment critical counter
    ///    - `ERROR("message"):     Print a red message with ERROR: prefix and increment error counter
    ///
    ///    - `FAIL_IF(aSignal):                 Increment error counter if evaluaton is true
    ///    - `FAIL_IF_NOT(aSignal):             Increment error coutner if evaluation is false
    ///    - `FAIL_IF_EQUAL(aSignal, 23):       Increment error counter if evaluation is equal
    ///    - `FAIL_IF_NOT_EQUAL(aSignal, 45):   Increment error counter if evaluation is not equal
    ///    - `ASSERT(aSignal):                  Increment error counter if evaluation is not true
    ///    - `ASSERT((aSignal == 0)):           Increment error counter if evaluation is not true
    ///
    ///    Available flag:
    ///
    ///    - `LAST_STATUS: tied to 1 is last macro did experience a failure, else tied to 0

    `UNIT_TEST("TEST_NAME")

    // expected result without initial state addition
    // expected = 512'h4e3c50a2_9e83d0cb_b04e16de_d19c12b4_82e46ebd_eabda8fc_f29489f3_335271c2_3f5ec7b7_8fa018fc_fc62bb2f_c4f2d0c7_5950bb2f_a67ae21e_e238d763_837778ab;
    // expected result with initial state addition
    expected = 512'h4e3c50a2_e883d0cb_b94e16de_d19c12b5_a2028bd9_05d7c214_09aa9f07_466482d2_4e6cd4c3_9aaa2204_0368c033_c7f4d1c7_c47120a3_1fdd0f50_15593bd1_e4e7f110;

    fork
    begin
        en = 1;
        while (!o_tvalid) @(posedge aclk);
        `ASSERT((o_tdata==expected), "Test vector hasn't been catched by BlockFunction");
    end
    begin
        while (timeout<100) begin
            @(posedge aclk);
            timeout = timeout + 1;
        end
        `ASSERT((timeout<100), "Reached timeout!");
    end
    join_any


    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
