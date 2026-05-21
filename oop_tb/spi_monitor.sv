class spi_monitor;
    int pass_count = 0;
    int fail_count = 0;

    function new();
        pass_count = 0;
        fail_count = 0;
    endfunction

    task run(
        input logic        REFCLK,
        input logic [7:0]  M_OUTPUT,
        input logic [7:0]  S_OUTPUT,
        input logic [7:0]  SS,
        input logic        M_READY
    );
        // Khai báo biến local ở đầu task, KHÔNG khai báo bên trong begin...end
        // vì iverilog không hỗ trợ variable declaration inside procedural blocks
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
            // Dùng 8'bx thay vì 8'hXX (iverilog không nhận 8'hXX)
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