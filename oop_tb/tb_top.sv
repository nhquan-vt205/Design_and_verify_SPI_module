`timescale 1ns/1ps

// `include để iverilog biết thứ tự class trước khi dùng
`include "spi_transaction.sv"
`include "spi_generator.sv"
`include "spi_driver.sv"
`include "spi_monitor.sv"

module tb_top;

    // ══════════════════════════════════════════════════════════════
    // 1. Clock generation
    // ══════════════════════════════════════════════════════════════
    localparam CLK_PERIOD = 10;  // 10ns = 100MHz
    logic REFCLK = 0;
    always #(CLK_PERIOD/2) REFCLK = ~REFCLK;

    // ══════════════════════════════════════════════════════════════
    // 2. DUT signals
    // ══════════════════════════════════════════════════════════════
    logic        RST_N;
    logic [7:0]  M_INPUT;
    logic [2:0]  M_SELECT_SS;
    logic [1:0]  M_CNTL;
    logic [7:0]  S_INPUT;
    logic        S_LOAD;
    logic [7:0]  M_OUTPUT;
    logic        M_READY;
    logic [7:0]  S_OUTPUT;
    logic        S_READY;
    logic        MOSI, MISO, SCLK;
    logic [7:0]  SS;

    // ══════════════════════════════════════════════════════════════
    // 3. DUT instantiation
    // ══════════════════════════════════════════════════════════════
    spi_communication dut (
        .REFCLK(REFCLK), .RST_N(RST_N),
        .M_INPUT(M_INPUT), .M_SELECT_SS(M_SELECT_SS), .M_CNTL(M_CNTL),
        .M_OUTPUT(M_OUTPUT), .M_READY(M_READY),
        .S_INPUT(S_INPUT), .S_LOAD(S_LOAD),
        .S_OUTPUT(S_OUTPUT), .S_READY(S_READY),
        .MOSI(MOSI), .MISO(MISO), .SCLK(SCLK), .SS(SS)
    );

    // ══════════════════════════════════════════════════════════════
    // 4. Testbench components
    // ══════════════════════════════════════════════════════════════
    mailbox #(spi_transaction) gen2drv_mbx;
    spi_generator gen;
    spi_driver    drv;
    spi_monitor   mon;

    initial begin
        // ──────────────────────────────────────────────────────────
        // Tạo mailbox và components
        // ──────────────────────────────────────────────────────────
        gen2drv_mbx = new();        // unbounded mailbox
        gen = new(gen2drv_mbx, 5); // sinh 5 transactions
        drv = new(gen2drv_mbx);
        mon = new();

        // ──────────────────────────────────────────────────────────
        // Reset DUT
        // ──────────────────────────────────────────────────────────
        RST_N      = 0;
        M_INPUT    = 0; M_SELECT_SS = 0; M_CNTL = 0;
        S_INPUT    = 0; S_LOAD      = 0;
        repeat(4) @(posedge REFCLK);
        RST_N = 1;
        repeat(2) @(posedge REFCLK);

        // ──────────────────────────────────────────────────────────
        // Chạy Generator, Driver, Monitor song song
        // join_any: thoát khi gen.run() xong (sau 5 transactions)
        // ──────────────────────────────────────────────────────────
        fork
            gen.run();
            drv.run(REFCLK, M_INPUT, M_SELECT_SS, M_CNTL,
                    S_INPUT, S_LOAD, M_READY, S_READY);
            mon.run(REFCLK, M_OUTPUT, S_OUTPUT, SS, M_READY);
        join_any

        // ──────────────────────────────────────────────────────────
        // Chờ thêm để Monitor xử lý transaction cuối
        // Đã tăng thời gian chờ lên đủ dài để chạy hết 5 transaction
        // (mỗi transaction tốn >160ns, nên 5 cái tốn >800ns)
        // ──────────────────────────────────────────────────────────
        #(CLK_PERIOD * 200);

        // ──────────────────────────────────────────────────────────
        // Report
        // ──────────────────────────────────────────────────────────
        mon.report();
        $finish;
    end

    // ══════════════════════════════════════════════════════════════
    // 5. Waveform dump
    // ══════════════════════════════════════════════════════════════
    initial begin
        $dumpfile("obj_dir/oop/tb_top.vcd");
        $dumpvars(0, tb_top);
    end

endmodule