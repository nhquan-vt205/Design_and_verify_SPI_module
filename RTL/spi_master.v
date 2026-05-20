`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// File        : spi_master.v
// Project     : Lab 2 - SPI Communication
// Description : SPI Master, 8-bit full-duplex, SPI Mode 0 (CPOL=0, CPHA=0),
//               MSB-first. Single clock domain: REFCLK. Active-low reset.
// Notes       : CNTL=00 no-op, CNTL=01 load TX data, CNTL=10 store slave
//               address, CNTL=11 start transfer. SS is active only while the
//               transfer is running; it returns to 8'hFF in IDLE/WAIT_RELEASE.
// -----------------------------------------------------------------------------

module spi_master (
    input             REFCLK,
    input             RST_N,
    input      [7:0]  data_in,
    input      [2:0]  select_ss,
    input      [1:0]  CNTL,
    input             MISO,
    output reg [7:0]  data_out,
    output reg        READY,
    output reg        MOSI,
    output reg        SCLK,
    output reg [7:0]  SS
);

    localparam ST_IDLE         = 2'd0;
    localparam ST_TRANSFER     = 2'd1;
    localparam ST_WAIT_RELEASE = 2'd2;

    reg [1:0] state;
    reg [7:0] tx_data;
    reg [7:0] rx_shift;
    reg [7:0] selected_ss;
    reg [2:0] bit_cnt;
    reg       sclk_level;

    always @(posedge REFCLK or negedge RST_N) begin
        if (!RST_N) begin
            state       <= ST_IDLE;
            tx_data     <= 8'h00;
            rx_shift    <= 8'h00;
            selected_ss <= 8'hFF;
            bit_cnt     <= 3'd7;
            sclk_level  <= 1'b0;
            data_out    <= 8'h00;
            READY       <= 1'b1;
            MOSI        <= 1'b0;
            SCLK        <= 1'b0;
            SS          <= 8'hFF;
        end else begin
            case (state)
                ST_IDLE: begin
                    READY      <= 1'b1;
                    SCLK       <= 1'b0;
                    MOSI       <= 1'b0;
                    SS         <= 8'hFF;
                    sclk_level <= 1'b0;

                    case (CNTL)
                        2'b00: begin
                            // No operation.
                        end

                        2'b01: begin
                            // Load data to be transmitted when the master is ready.
                            tx_data <= data_in;
                        end

                        2'b10: begin
                            // Store the slave-select decode. Do not assert SS yet.
                            selected_ss <= ~(8'b0000_0001 << select_ss);
                        end

                        2'b11: begin
                            // Start one 8-bit full-duplex transfer.
                            state       <= ST_TRANSFER;
                            READY       <= 1'b0;
                            bit_cnt     <= 3'd7;
                            rx_shift    <= 8'h00;
                            MOSI        <= tx_data[7];
                            SCLK        <= 1'b0;
                            sclk_level  <= 1'b0;
                            SS          <= selected_ss;
                        end
                    endcase
                end

                ST_TRANSFER: begin
                    READY <= 1'b0;
                    SS    <= selected_ss;

                    if (sclk_level == 1'b0) begin
                        // SPI Mode 0 rising edge: sample MISO.
                        SCLK              <= 1'b1;
                        sclk_level        <= 1'b1;
                        rx_shift[bit_cnt] <= MISO;

                        if (bit_cnt == 3'd0) begin
                            data_out <= {rx_shift[7:1], MISO};
                        end
                    end else begin
                        // SPI Mode 0 falling edge: prepare the next MOSI bit or finish.
                        SCLK       <= 1'b0;
                        sclk_level <= 1'b0;

                        if (bit_cnt == 3'd0) begin
                            state <= ST_WAIT_RELEASE;
                            MOSI  <= 1'b0;
                            SS    <= 8'hFF;
                        end else begin
                            bit_cnt <= bit_cnt - 3'd1;
                            MOSI    <= tx_data[bit_cnt - 3'd1];
                        end
                    end
                end

                ST_WAIT_RELEASE: begin
                    SCLK <= 1'b0;
                    MOSI <= 1'b0;
                    SS   <= 8'hFF;

                    // Avoid repeated transfers if CNTL is still held at 2'b11.
                    if (CNTL != 2'b11) begin
                        READY <= 1'b1;
                        state <= ST_IDLE;
                    end else begin
                        READY <= 1'b0;
                    end
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end
endmodule
