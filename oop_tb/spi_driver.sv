class spi_driver;
    mailbox #(spi_transaction) gen2drv_mbx;

    function new(mailbox #(spi_transaction) mbx);
        gen2drv_mbx = mbx;
    endfunction

    task drive_transfer(
        spi_transaction trans,
        input  logic REFCLK,
        ref    logic [7:0] M_INPUT,
        ref    logic [2:0] M_SELECT_SS,
        ref    logic [1:0] M_CNTL,
        ref    logic [7:0] S_INPUT,
        ref    logic       S_LOAD,
        input  logic       M_READY,
        input  logic       S_READY
    );
        // ────────────────────────────────────────────────────────────
        // Bước 1: Preload Slave TX data
        // ────────────────────────────────────────────────────────────
        @(posedge REFCLK);
        wait(S_READY == 1);         // chờ slave sẵn sàng
        S_INPUT = trans.s_data;     // đặt byte slave muốn gửi
        S_LOAD  = 1;
        @(posedge REFCLK);          // 1 cycle: slave latch vào tx_shift
        S_LOAD  = 0;

        // ────────────────────────────────────────────────────────────
        // Bước 2: Load Master TX data (CNTL=01)
        // ────────────────────────────────────────────────────────────
        wait(M_READY == 1);         // chờ master idle
        @(posedge REFCLK);
        M_INPUT = trans.m_data;     // đặt byte master muốn gửi
        M_CNTL  = 2'b01;
        @(posedge REFCLK);          // 1 cycle: master latch vào tx_data
        M_CNTL  = 2'b00;

        // ────────────────────────────────────────────────────────────
        // Bước 3: Store Slave Address (CNTL=10)
        // ────────────────────────────────────────────────────────────
        @(posedge REFCLK);
        M_SELECT_SS = trans.ss_addr;
        M_CNTL      = 2'b10;
        @(posedge REFCLK);          // 1 cycle: master decode selected_ss
        M_CNTL      = 2'b00;

        // ────────────────────────────────────────────────────────────
        // Bước 4: Start Transfer (CNTL=11)
        // ────────────────────────────────────────────────────────────
        @(posedge REFCLK);
        M_CNTL = 2'b11;             // master vào ST_TRANSFER
        @(negedge M_READY);         // M_READY xuống khi transfer bắt đầu

        // ────────────────────────────────────────────────────────────
        // Bước 5: Chờ transfer hoàn tất
        // ────────────────────────────────────────────────────────────
        @(posedge M_READY);         // M_READY lên lại khi về ST_IDLE

        // ────────────────────────────────────────────────────────────
        // Bước 6: Release CNTL
        // ────────────────────────────────────────────────────────────
        M_CNTL = 2'b00;
        @(posedge REFCLK);
    endtask

    task run(
        input  logic       REFCLK,
        ref    logic       RST_N,
        ref    logic [7:0] M_INPUT,
        ref    logic [2:0] M_SELECT_SS,
        ref    logic [1:0] M_CNTL,
        ref    logic [7:0] S_INPUT,
        ref    logic       S_LOAD,
        input  logic       M_READY,
        input  logic       S_READY
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