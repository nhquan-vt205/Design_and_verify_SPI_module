`timescale 1ns/1ps

// ═══════════════════════════════════════════════════════════════════════════
// CONSOLIDATED TESTBENCH FOR EDA PLAYGROUND
// This file combines all OOP testbench components in correct compilation order
// ═══════════════════════════════════════════════════════════════════════════

// ───────────────────────────────────────────────────────────────────────────
// 1. SPI_TRANSACTION CLASS (MUST BE FIRST)
// ───────────────────────────────────────────────────────────────────────────
class spi_transaction;
    rand logic [7:0] m_data;
    rand logic [7:0] s_data;
    rand logic [2:0] ss_addr;

    //monitor record the result to this two fields
    logic [7:0] m_result;
    logic [7:0] s_result;

    constraint c_addr {
        ss_addr inside {3'd0, 3'd1, 3'd2};
    }

    function new();
        m_data = 0;
        s_data = 0;
        ss_addr = 0;
        m_result = 0;
        s_result = 0;
    endfunction

    function void display(string tag = "");
        $display("%s: m_data = 0x%x, s_data = 0x%x, ss_addr = 0x%x",
                 tag, m_data, s_data, ss_addr);
    endfunction

endclass

// ───────────────────────────────────────────────────────────────────────────
// 2. SPI_GENERATOR CLASS
// ───────────────────────────────────────────────────────────────────────────
class spi_generator;
    mailbox #(spi_transaction) gen2drv_mbx;
    int repeat_count = 10;
    
    function new(mailbox #(spi_transaction) mbx, int count = 10);
        gen2drv_mbx = mbx;
        repeat_count = count;
    endfunction

    task run();
        for (int i = 0; i < repeat_count; i++) begin
            spi_transaction trans = new();

            if (!trans.randomize()) begin
                $fatal("[GEN] Randomize failed for trans #%0d", i);
            end 

            trans.display("[GEN]");
            gen2drv_mbx.put(trans);
        end

        $display("[GEN] Done: %0d transactions generated", repeat_count);
    endtask
endclass

// ───────────────────────────────────────────────────────────────────────────
// 3. SPI_DRIVER CLASS
// ───────────────────────────────────────────────────────────────────────────
class spi_driver;
    mailbox #(spi_transaction) gen2drv_mbx;

    function new(mailbox #(spi_transaction) mbx);
        gen2drv_mbx = mbx;
    endfunction

    task drive_transfer(
        spi_transaction trans,
        ref    logic REFCLK,
        ref    logic [7:0] M_INPUT,
        ref    logic [2:0] M_SELECT_SS,
        ref    logic [1:0] M_CNTL,
        ref    logic [7:0] S_INPUT,
        ref    logic       S_LOAD,
        ref    logic       M_READY,
        ref    logic       S_READY
    );
        // ────────────────────────────────────────────────────────────
        // Chiến lược drive: tất cả tín hiệu input được đặt tại
        // NEGEDGE REFCLK để dữ liệu ổn định (setup time) trước khi
        // DUT sample tại posedge tiếp theo → tránh race condition.
        // ────────────────────────────────────────────────────────────

        // ────────────────────────────────────────────────────────────
        // Bước 1: Preload Slave TX data
        // ────────────────────────────────────────────────────────────
        @(negedge REFCLK);
        wait(S_READY == 1);         // chờ slave sẵn sàng
        @(negedge REFCLK);          // lấy negedge kế tiếp để drive
        S_INPUT = trans.s_data;     // đặt byte slave muốn gửi (ổn định trước posedge)
        S_LOAD  = 1;
        @(negedge REFCLK);          // DUT đã latch ở posedge vừa qua, hạ S_LOAD
        S_LOAD  = 0;

        // ────────────────────────────────────────────────────────────
        // Bước 2: Load Master TX data (CNTL=01)
        // ────────────────────────────────────────────────────────────
        @(negedge REFCLK);
        wait(M_READY == 1);         // chờ master idle
        @(negedge REFCLK);          // lấy negedge kế tiếp để drive
        M_INPUT = trans.m_data;     // đặt byte master muốn gửi (ổn định trước posedge)
        M_CNTL  = 2'b01;
        @(negedge REFCLK);          // DUT đã latch CNTL=01 ở posedge, trả về 00
        M_CNTL  = 2'b00;

        // ────────────────────────────────────────────────────────────
        // Bước 3: Store Slave Address (CNTL=10)
        // ────────────────────────────────────────────────────────────
        @(negedge REFCLK);
        M_SELECT_SS = trans.ss_addr;
        M_CNTL      = 2'b10;
        @(negedge REFCLK);          // DUT đã decode selected_ss, trả về 00
        M_CNTL      = 2'b00;

        // ────────────────────────────────────────────────────────────
        // Bước 4: Start Transfer (CNTL=11)
        // ────────────────────────────────────────────────────────────
        @(negedge REFCLK);
        M_CNTL = 2'b11;             // đặt ở negedge → DUT thấy CNTL=11 tại posedge tới
        @(negedge M_READY);         // M_READY xuống khi transfer bắt đầu

        // Release CNTL so master can transition back to IDLE later
        M_CNTL = 2'b00;

        // ────────────────────────────────────────────────────────────
        // Bước 5: Chờ transfer hoàn tất
        // ────────────────────────────────────────────────────────────
        @(posedge M_READY);         // M_READY lên lại khi về ST_IDLE
        @(posedge REFCLK);
    endtask

    task run(
        ref    logic       REFCLK,
        ref    logic [7:0] M_INPUT,
        ref    logic [2:0] M_SELECT_SS,
        ref    logic [1:0] M_CNTL,
        ref    logic [7:0] S_INPUT,
        ref    logic       S_LOAD,
        ref    logic       M_READY,
        ref    logic       S_READY
    );
        spi_transaction trans;
        forever begin
            gen2drv_mbx.get(trans);
            trans.display("[DRV]");
            drive_transfer(trans, REFCLK, M_INPUT, M_SELECT_SS, M_CNTL,
                           S_INPUT, S_LOAD, M_READY, S_READY);
        end
    endtask

endclass

// ───────────────────────────────────────────────────────────────────────────
// 4. SPI_MONITOR CLASS
// ───────────────────────────────────────────────────────────────────────────
class spi_monitor;
    int pass_count = 0;
    int fail_count = 0;

    function new();
        pass_count = 0;
        fail_count = 0;
    endfunction

    task run(
        ref logic        REFCLK,
        ref logic [7:0]  M_OUTPUT,
        ref logic [7:0]  S_OUTPUT,
        ref logic [7:0]  SS,
        ref logic        M_READY
    );
        logic [7:0] m_out;
        logic [7:0] s_out;

        forever begin
            // ────────────────────────────────────────────────────────
            // Bước 1: Chờ transfer bắt đầu
            // ────────────────────────────────────────────────────────
            @(negedge M_READY);         // M_READY xuống = transfer bắt đầu
            @(posedge REFCLK);

            // ────────────────────────────────────────────────────────
            // Bước 2: Chờ transfer hoàn tất
            // ────────────────────────────────────────────────────────
            @(posedge M_READY);         // transfer xong
            repeat(2) @(posedge REFCLK); // đợi output ổn định

            // ────────────────────────────────────────────────────────
            // Bước 3: Capture outputs
            // ────────────────────────────────────────────────────────
            m_out = M_OUTPUT;
            s_out = S_OUTPUT;

            // ────────────────────────────────────────────────────────
            // Bước 4: Check – chỉ kiểm tra không phải X
            // ────────────────────────────────────────────────────────
            if (m_out === 8'bx || s_out === 8'bx) begin
                $display("[MON] FAIL: M_OUTPUT or S_OUTPUT is X!");
                fail_count++;
            end else begin
                $display("[MON] PASS: M_OUTPUT=0x%02h, S_OUTPUT=0x%02h", m_out, s_out);
                pass_count++;
            end
        end
    endtask

    function void report();
        $display("==========================================");
        $display("  MONITOR REPORT");
        $display("  PASS: %0d", pass_count);
        $display("  FAIL: %0d", fail_count);
        $display("==========================================");
    endfunction

endclass

// ───────────────────────────────────────────────────────────────────────────
// 5. TESTBENCH MODULE (tb_top)
// ───────────────────────────────────────────────────────────────────────────
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
