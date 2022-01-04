// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps
`default_nettype none


module chacha_csr

    #(
        parameter ADDRW     = 16,
        parameter BUSW      = 32*11
    )(
        // clock & reset
        input  logic                        aclk,
        input  logic                        aresetn,
        input  logic                        srst,
        // APB slave interface
        input  logic                        slv_en,
        input  logic                        slv_wr,
        input  logic [ADDRW           -1:0] slv_addr,
        input  logic [32              -1:0] slv_wdata,
        input  logic [32/8            -1:0] slv_strb,
        output logic [32              -1:0] slv_rdata,
        output logic                        slv_ready,
        // Shared bus carrying the key and nonce
        output logic [BUSW            -1:0] shared_bus
    );

    //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    // Parameters and variables declaration
    //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    parameter         KEY0_ADDR = 0;
    parameter         KEY1_ADDR = 4;
    parameter         KEY2_ADDR = 8;
    parameter         KEY3_ADDR = 12;
    parameter         KEY4_ADDR = 16;
    parameter         KEY5_ADDR = 20;
    parameter         KEY6_ADDR = 24;
    parameter         KEY7_ADDR = 28;
    parameter         NONCE0_ADDR = 32;
    parameter         NONCE1_ADDR = 36;
    parameter         NONCE2_ADDR = 40;

    logic [32   -1:0] key0;
    logic [32   -1:0] key1;
    logic [32   -1:0] key2;
    logic [32   -1:0] key3;
    logic [32   -1:0] key4;
    logic [32   -1:0] key5;
    logic [32   -1:0] key6;
    logic [32   -1:0] key7;
    logic [32   -1:0] nonce0;
    logic [32   -1:0] nonce1;
    logic [32   -1:0] nonce2;

    //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    // Function managing the write access to a register
    //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    function automatic logic [31:0] write_reg(
        input logic [3 :0] strb,
        input logic [31:0] data,
        input logic [31:0] register
    );

        write_reg = register;

        if (strb[0]) write_reg[ 0+:8] = data[ 0+:8];
        if (strb[1]) write_reg[ 8+:8] = data[ 8+:8];
        if (strb[2]) write_reg[16+:8] = data[16+:8];
        if (strb[3]) write_reg[24+:8] = data[24+:8];

    endfunction
    //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


    //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    // Register management
    //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    always @ (posedge aclk or negedge aresetn) begin

        if (~aresetn) begin
            register0 <= 32'b0;
            slv_rdata <= 32'b0;
            slv_ready <= 1'b0;
        end else if (srst) begin
            register0 <= 32'b0;
            slv_rdata <= 32'b0;
            slv_ready <= 1'b0;
        end else begin

            // READY assertion
            if (slv_en && ~slv_ready) begin
                slv_ready <= 1'b1;
            end else begin
                slv_ready <= 1'b0;
            end

            // Registers access
            if (slv_en) begin

                //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                // Key
                //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

                if (slv_addr==KEY0_ADDR[ADDRW-1:0]) begin
                    if (slv_wr) begin
                        key0 <= write_reg(slv_strb, slv_wdata, key0);
                    end else begin
                        slv_rdata <= key0;
                    end
                end

                if (slv_addr==KEY1_ADDR[ADDRW-1:0]) begin
                    if (slv_wr) begin
                        key1 <= write_reg(slv_strb, slv_wdata, key1);
                    end else begin
                        slv_rdata <= key1;
                    end
                end

                if (slv_addr==KEY2_ADDR[ADDRW-1:0]) begin
                    if (slv_wr) begin
                        key2 <= write_reg(slv_strb, slv_wdata, key2);
                    end else begin
                        slv_rdata <= key2;
                    end
                end

                if (slv_addr==KEY3_ADDR[ADDRW-1:0]) begin
                    if (slv_wr) begin
                        key3 <= write_reg(slv_strb, slv_wdata, key3);
                    end else begin
                        slv_rdata <= key3;
                    end
                end

                if (slv_addr==KEY4_ADDR[ADDRW-1:0]) begin
                    if (slv_wr) begin
                        key4 <= write_reg(slv_strb, slv_wdata, key4);
                    end else begin
                        slv_rdata <= key4;
                    end
                end

                if (slv_addr==KEY5_ADD5[ADDRW-1:0]) begin
                    if (slv_wr) begin
                        key5 <= write_reg(slv_strb, slv_wdata, key5);
                    end else begin
                        slv_rdata <= key5;
                    end
                end

                if (slv_addr==KEY6_ADDR[ADDRW-1:0]) begin
                    if (slv_wr) begin
                        key6 <= write_reg(slv_strb, slv_wdata, key6);
                    end else begin
                        slv_rdata <= key6;
                    end
                end

                if (slv_addr==KEY7_ADDR[ADDRW-1:0]) begin
                    if (slv_wr) begin
                        key7 <= write_reg(slv_strb, slv_wdata, key7);
                    end else begin
                        slv_rdata <= key7;
                    end
                end

                //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                // Nonce
                //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

                if (slv_addr==NONCE0_ADDR[ADDRW-1:0]) begin
                    if (slv_wr) begin
                        nonce0 <= write_reg(slv_strb, slv_wdata, nonce0);
                    end else begin
                        slv_rdata <= nonce0;
                    end
                end

                if (slv_addr==NONCE1_ADDR[ADDRW-1:0]) begin
                    if (slv_wr) begin
                        nonce1 <= write_reg(slv_strb, slv_wdata, nonce1);
                    end else begin
                        slv_rdata <= nonce1;
                    end
                end

                if (slv_addr==NONCE2_ADDR[ADDRW-1:0]) begin
                    if (slv_wr) begin
                        nonce2 <= write_reg(slv_strb, slv_wdata, nonce2);
                    end else begin
                        slv_rdata <= nonce2;
                    end
                end

            end
        end
    end

    //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    // Shared bus assignments
    //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    assign shared_bus = {
        nonce2,
        nonce1,
        nonce0,
        key7,
        key6,
        key5,
        key4,
        key3,
        key2,
        key1,
        key0
    };

endmodule

`resetall

