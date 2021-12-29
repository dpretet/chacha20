/// Mandatory file to be able to launch SVUT flow
`include "svut_h.sv"

`timescale 1 ns / 100 ps

module chacha_quarter_round_testbench();

    `SVUT_SETUP

    parameter [3:0] PIPELINE = 0;

    logic        aclk;
    logic        aresetn;
    logic        srst;
    logic        i_valid;
    logic        i_ready;
    logic [31:0] i_a;
    logic [31:0] i_b;
    logic [31:0] i_c;
    logic [31:0] i_d;
    logic        o_valid;
    logic        o_ready;
    logic [31:0] o_a;
    logic [31:0] o_b;
    logic [31:0] o_c;
    logic [31:0] o_d;

    chacha_quarter_round
    #(
    .PIPELINE (PIPELINE)
    )
    dut
    (
    .aclk      (aclk),
    .aresetn   (aresetn),
    .srst      (srst),
    .i_valid   (i_valid),
    .i_ready   (i_ready),
    .i_a       (i_a),
    .i_b       (i_b),
    .i_c       (i_c),
    .i_d       (i_d),
    .o_valid   (o_valid),
    .o_ready   (o_ready),
    .o_a       (o_a),
    .o_b       (o_b),
    .o_c       (o_c),
    .o_d       (o_d)
    );

    // To create a clock:
    initial aclk = 0;
    always #2 aclk = ~aclk;

    // To dump data for visualization:
    // initial begin
    //     $dumpfile("chacha_quarter_round_testbench.vcd");
    //     $dumpvars(0, chacha_quarter_round_testbench);
    // end

    // Setup time format when printing with $realtime
    initial $timeformat(-9, 1, "ns", 8);

    task setup(msg="");
    begin
        aresetn = 1'b0;
        srst = 1'b0;
        #10;
        aresetn = 1'b1;
    end
    endtask

    task teardown(msg="");
    begin
        /// teardown() runs when a test ends
    end
    endtask

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

    `UNIT_TEST("TEST_VECTOR")

        @(posedge aclk);
        i_a = 32'h516461b1;
        i_b = 32'h2a5f714c;
        i_c = 32'h53372767;
        i_d = 32'h3d631689;
        @(posedge aclk);
        `ASSERT(o_a==32'hBDB886DC);
        `ASSERT(o_b==32'hCFACAFD2);
        `ASSERT(o_c==32'hE46BEA80);
        `ASSERT(o_d==32'hCCC07C79);

    `UNIT_TEST_END

    `TEST_SUITE_END

endmodule
