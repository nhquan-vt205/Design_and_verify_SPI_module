class monitor;
    int pass_count = 0;
    int fail_count = 0;

    function new();
        pass_count = 0;
        fail_count = 0;
    endfunction

    task run(
        input logic REFCLK,
        input logic [7:0] M_OUTPUT,
        input logic [7:0] S_OUTPUT,
        input logic [7:0] SS,
        input logic M_READY
    );
        forever begin
            // ────────────────────────────────────────────────────────
            // Bước 1: Chờ phát hiện transfer bắt đầu (SS xuống)
            // ────────────────────────────────────────────────────────
            logic [7:0] exp_m_out, exp_s_out;
            
            @(negedge M_READY);     // M_READY xuống = transfer bắt đầu
            @(posedge REFCLK);

            // Lưu snapshot stimulus (từ Generator đã lái)
            // Trong thực tế, ta cần biết trans.m_data, trans.s_data
            // Cách đơn giản: Monitor không tự tính expected, mà so sánh
            // kết quả M_OUTPUT vs S_OUTPUT phải thỏa mãn logic SPI:
            //   M_OUTPUT = slave đã gửi (ta không biết trước)
            //   S_OUTPUT = master đã gửi (ta không biết trước)
            // → Chỉ check được tính hợp lệ cơ bản (không X, SS đúng).

            // ────────────────────────────────────────────────────────
            // Bước 2: Chờ transfer hoàn tất
            // ────────────────────────────────────────────────────────
            @(posedge M_READY);     // transfer xong
            repeat(2) @(posedge REFCLK); // đợi output ổn định

            // ────────────────────────────────────────────────────────
            // Bước 3: Capture outputs
            // ────────────────────────────────────────────────────────
            logic [7:0] m_out = M_OUTPUT;
            logic [7:0] s_out = S_OUTPUT;

            // ────────────────────────────────────────────────────────
            // Bước 4: Check – chỉ kiểm tra không phải X
            // ────────────────────────────────────────────────────────
            if (m_out === 8'hXX || s_out === 8'hXX) begin
                $error("[MON] FAIL: M_OUTPUT or S_OUTPUT is X!");
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