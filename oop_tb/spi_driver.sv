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