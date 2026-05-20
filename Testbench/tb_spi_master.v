`timescale 1ns/1ps

module tb_spi_master;
    reg         REFCLK;
    reg         RST_N;
    reg  [7:0]  data_in;
    reg  [2:0]  select_ss;
    reg  [1:0]  CNTL;
    reg         MISO;
    wire [7:0]  OUTPUT;
    wire        READY;
    wire        MOSI;
    wire        SCLK;
    wire [7:0]  SS;

    integer pass_count;
    integer fail_count;

    spi_master dut (
        .REFCLK(REFCLK), .RST_N(RST_N), .data_in(data_in), .select_ss(select_ss), .CNTL(CNTL), .MISO(MISO),
        .data_out(OUTPUT), .READY(READY), .MOSI(MOSI), .SCLK(SCLK), .SS(SS)
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
            data_in   = 8'h00;
            select_ss = 3'd0;
            CNTL  = 2'b00;
            MISO  = 1'b0;
            repeat (3) @(negedge REFCLK);
            RST_N = 1'b1;
            repeat (2) @(negedge REFCLK);
        end
    endtask

    task load_master_data;
        input [7:0] data;
        begin
            @(negedge REFCLK);
            data_in = data;
            CNTL  = 2'b01;
            @(negedge REFCLK);
            CNTL  = 2'b00;
            @(negedge REFCLK);
        end
    endtask

    task select_slave;
        input [2:0] addr;
        begin
            @(negedge REFCLK);
            select_ss = addr;
            CNTL      = 2'b10;
            @(negedge REFCLK);
            CNTL  = 2'b00;
            @(negedge REFCLK);
        end
    endtask

    task master_transfer_with_miso;
        input [7:0] miso_byte;
        input [7:0] expected_ss;
        integer i;
        begin
            @(negedge REFCLK);
            CNTL = 2'b11;
            @(posedge REFCLK); // DUT samples the start command here.
            @(negedge REFCLK);
            check_bit(READY === 1'b0, "READY goes LOW during transfer");
            check_bit(SS === expected_ss, "SS has expected value only during transfer");
            CNTL = 2'b00;

            for (i = 7; i >= 0; i = i - 1) begin
                MISO = miso_byte[i];
                @(posedge SCLK);
                @(negedge SCLK);
            end

            wait (READY === 1'b1);
            @(negedge REFCLK);
            check_bit(SS === 8'hFF, "SS returns inactive HIGH after transfer");
        end
    endtask

    initial begin
        $dumpfile("tb_spi_master.vcd");
        $dumpvars(0, tb_spi_master);

        pass_count = 0;
        fail_count = 0;

        apply_reset;
        $display("\n=== tb_spi_master ===");

        check_bit(READY === 1'b1, "TC_MST_001 READY is HIGH in idle after reset");
        check_bit(SS === 8'hFF, "TC_MST_002 SS is inactive in idle after reset");

        select_slave(3'd0);
        check_bit(SS === 8'hFF, "TC_MST_003 selecting slave 0 stores address but keeps SS inactive before TX");
        load_master_data(8'hA5);
        master_transfer_with_miso(8'h3C, 8'hFE);
        check_bit(OUTPUT === 8'h3C, "TC_MST_004 master receives 0x3C from MISO");
        check_bit(READY === 1'b1, "TC_MST_005 READY returns HIGH after CNTL release");

        select_slave(3'd3);
        load_master_data(8'h00);
        master_transfer_with_miso(8'hFF, 8'hF7);
        check_bit(OUTPUT === 8'hFF, "TC_MST_006 selected slave 3 transfer receives all ones");

        select_slave(3'd7);
        load_master_data(8'h00);
        master_transfer_with_miso(8'h00, 8'h7F);
        check_bit(OUTPUT === 8'h00, "TC_MST_007 selected slave 7 transfer receives all zeros");

        $display("=== tb_spi_master result: %0d PASS / %0d FAIL ===", pass_count, fail_count);
        if (fail_count == 0) $display("TB_RESULT: PASS");
        else                 $display("TB_RESULT: FAIL");
        #20;
        $finish;
    end
endmodule
