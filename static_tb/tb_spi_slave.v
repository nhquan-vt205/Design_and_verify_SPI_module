`timescale 1ns/1ps

module tb_spi_slave;
    reg         REFCLK;
    reg         RST_N;
    reg         SCLK;
    reg         CS;
    reg         LOAD;
    reg  [7:0]  data_in;
    reg         MOSI;
    wire        MISO;
    wire [7:0]  data_out;
    wire        READY;

    integer pass_count;
    integer fail_count;
    reg [7:0] miso_capture;

    spi_slave dut (
        .REFCLK(REFCLK), .RST_N(RST_N), .SCLK(SCLK), .CS(CS), .LOAD(LOAD),
        .data_in(data_in), .MOSI(MOSI), .MISO(MISO), .data_out(data_out), .READY(READY)
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
            SCLK = 1'b0;
            CS   = 1'b1;
            LOAD = 1'b0;
            data_in = 8'h00;
            MOSI  = 1'b0;
            repeat (3) @(negedge REFCLK);
            RST_N = 1'b1;
            repeat (2) @(negedge REFCLK);
        end
    endtask

    task load_slave_data;
        input [7:0] data;
        begin
            @(negedge REFCLK);
            data_in = data;
            LOAD  = 1'b1;
            @(negedge REFCLK);
            LOAD  = 1'b0;
            @(negedge REFCLK);
        end
    endtask

    task spi_transaction;
        input [7:0] mosi_byte;
        integer i;
        begin
            miso_capture = 8'h00;
            @(negedge REFCLK);
            CS = 1'b0;
            @(negedge REFCLK);

            for (i = 7; i >= 0; i = i - 1) begin
                MOSI = mosi_byte[i];
                SCLK = 1'b1;              // present SCLK high before REFCLK edge
                #1 miso_capture[i] = MISO; // MISO is valid before the sampled edge
                @(posedge REFCLK);        // DUT detects SCLK rising edge here
                @(negedge REFCLK);
                SCLK = 1'b0;
                @(posedge REFCLK);        // DUT samples SCLK low before next rise
                @(negedge REFCLK);
            end

            CS = 1'b1;
            @(negedge REFCLK);
        end
    endtask

    initial begin
        $dumpfile("tb_spi_slave.vcd");
        $dumpvars(0, tb_spi_slave);

        pass_count = 0;
        fail_count = 0;

        apply_reset;
        $display("\n=== tb_spi_slave ===");

        check_bit(READY === 1'b1, "TC_SLV_001 READY is HIGH in idle after reset");

        load_slave_data(8'hC3);
        spi_transaction(8'h5A);
        check_bit(data_out === 8'h5A, "TC_SLV_002 slave captures MOSI byte 0x5A");
        check_bit(miso_capture === 8'hC3, "TC_SLV_003 slave shifts out loaded byte 0xC3");
        check_bit(READY === 1'b1, "TC_SLV_004 READY returns HIGH after CS release");

        load_slave_data(8'h00);
        spi_transaction(8'hFF);
        check_bit(data_out === 8'hFF, "TC_SLV_005 slave captures all ones");
        check_bit(miso_capture === 8'h00, "TC_SLV_006 slave shifts all zeros");

        $display("=== tb_spi_slave result: %0d PASS / %0d FAIL ===", pass_count, fail_count);
        if (fail_count == 0) $display("TB_RESULT: PASS");
        else                 $display("TB_RESULT: FAIL");
        #20;
        $finish;
    end
endmodule
