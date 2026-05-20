`timescale 1ns/1ps

module tb_spi_communication;
    reg         REFCLK;
    reg         RST_N;
    reg  [7:0]  M_INPUT;
    reg  [2:0]  M_SELECT_SS;
    reg  [1:0]  M_CNTL;
    wire [7:0]  M_OUTPUT;
    wire        M_READY;

    reg  [7:0]  S_INPUT;
    reg         S_LOAD;
    wire [7:0]  S_OUTPUT;
    wire        S_READY;

    wire        MOSI;
    wire        MISO;
    wire        SCLK;
    wire [7:0]  SS;

    integer pass_count;
    integer fail_count;

    spi_communication dut (
        .REFCLK(REFCLK), .RST_N(RST_N),
        .M_INPUT(M_INPUT), .M_SELECT_SS(M_SELECT_SS), .M_CNTL(M_CNTL), .M_OUTPUT(M_OUTPUT), .M_READY(M_READY),
        .S_INPUT(S_INPUT), .S_LOAD(S_LOAD), .S_OUTPUT(S_OUTPUT), .S_READY(S_READY),
        .MOSI(MOSI), .MISO(MISO), .SCLK(SCLK), .SS(SS)
    );

    initial REFCLK = 1'b0;
    always #5 REFCLK = ~REFCLK;

    task check_bit;
        input condition;
        input [1023:0] message;
        begin
            if (condition) begin
                $display("PASS | %0s", message);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL | %0s", message);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task apply_reset;
        begin
            RST_N = 1'b0;
            M_INPUT = 8'h00;
            M_SELECT_SS = 3'd0;
            M_CNTL  = 2'b00;
            S_INPUT = 8'h00;
            S_LOAD  = 1'b0;
            repeat (3) @(negedge REFCLK);
            RST_N = 1'b1;
            repeat (2) @(negedge REFCLK);
        end
    endtask

    task load_slave_data;
        input [7:0] data;
        begin
            @(negedge REFCLK);
            S_INPUT = data;
            S_LOAD  = 1'b1;
            @(negedge REFCLK);
            S_LOAD  = 1'b0;
            @(negedge REFCLK);
        end
    endtask

    task load_master_data;
        input [7:0] data;
        begin
            @(negedge REFCLK);
            M_INPUT = data;
            M_CNTL  = 2'b01;
            @(negedge REFCLK);
            M_CNTL  = 2'b00;
            @(negedge REFCLK);
        end
    endtask

    task select_slave;
        input [2:0] addr;
        begin
            @(negedge REFCLK);
            M_SELECT_SS = addr;
            M_CNTL      = 2'b10;
            @(negedge REFCLK);
            M_CNTL  = 2'b00;
            @(negedge REFCLK);
        end
    endtask

    task start_transfer;
        input [7:0] expected_ss;
        begin
            @(negedge REFCLK);
            M_CNTL = 2'b11;
            @(posedge REFCLK); // DUT samples the start command here.
            @(negedge REFCLK);
            check_bit(M_READY === 1'b0, "transfer drives master READY LOW");
            check_bit(SS === expected_ss, "SS is asserted only while transfer is active");
            M_CNTL = 2'b00;
            wait (M_READY === 1'b1);
            @(negedge REFCLK);
            check_bit(SS === 8'hFF, "SS returns inactive after transfer");
        end
    endtask

    initial begin
        $dumpfile("tb_spi_communication.vcd");
        $dumpvars(0, tb_spi_communication);

        pass_count = 0;
        fail_count = 0;

        apply_reset;
        $display("\n=== tb_spi_communication ===");

        check_bit(M_READY === 1'b1, "TC_TOP_001 master READY is HIGH in idle after reset");
        check_bit(S_READY === 1'b1, "TC_TOP_002 slave READY is HIGH in idle after reset");
        check_bit(SS === 8'hFF, "TC_TOP_003 SS is inactive before any transfer");

        load_slave_data(8'h3C);
        select_slave(3'd0);
        check_bit(SS === 8'hFF, "TC_TOP_004 selected slave is stored; SS stays inactive before TX");
        load_master_data(8'hA5);
        start_transfer(8'hFE);
        check_bit(M_OUTPUT === 8'h3C, "TC_TOP_005 master receives slave byte 0x3C");
        check_bit(S_OUTPUT === 8'hA5, "TC_TOP_006 slave receives master byte 0xA5");
        check_bit(M_READY === 1'b1, "TC_TOP_007 master READY returns HIGH after transfer");
        check_bit(S_READY === 1'b1, "TC_TOP_008 slave READY returns HIGH after transfer");

        // Consecutive transfer after READY/CNTL release.
        load_slave_data(8'h81);
        select_slave(3'd0);
        load_master_data(8'h7E);
        start_transfer(8'hFE);
        check_bit(M_OUTPUT === 8'h81, "TC_TOP_009 second transfer M_OUTPUT=0x81");
        check_bit(S_OUTPUT === 8'h7E, "TC_TOP_010 second transfer S_OUTPUT=0x7E");

        // Explicit complete-module loopback-style test: same byte loaded on both sides.
        load_slave_data(8'h5A);
        select_slave(3'd0);
        load_master_data(8'h5A);
        start_transfer(8'hFE);
        check_bit(M_OUTPUT === 8'h5A, "TC_TOP_011 loopback-style master receives 0x5A");
        check_bit(S_OUTPUT === 8'h5A, "TC_TOP_012 loopback-style slave receives 0x5A");

        select_slave(3'd3);
        check_bit(SS === 8'hFF, "TC_TOP_013 selecting unconnected slave stores address but keeps SS inactive before TX");

        $display("=== tb_spi_communication result: %0d PASS / %0d FAIL ===", pass_count, fail_count);
        if (fail_count == 0) $display("TB_RESULT: PASS");
        else                 $display("TB_RESULT: FAIL");
        #30;
        $finish;
    end
endmodule
