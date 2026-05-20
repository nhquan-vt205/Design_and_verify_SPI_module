`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// File        : spi_slave.v
// Project     : Lab 2 - SPI Communication
// Description : SPI Slave, 8-bit full-duplex, SPI Mode 0 (CPOL=0, CPHA=0),
//               MSB-first. Single clock domain: REFCLK. Active-low reset.
// Notes       : LOAD is treated as a synchronous data-enable, not as a clock.
//               SCLK and CS are sampled on REFCLK and SCLK rising edges are
//               detected internally. MISO is combinational from the current TX
//               bit so it is valid before the master sampling edge.
// -----------------------------------------------------------------------------

module spi_slave (
    input             REFCLK,
    input             RST_N,
    input             SCLK,
    input             CS,       // active-LOW chip select
    input             LOAD,     // active-HIGH synchronous load enable
    input      [7:0]  data_in,
    input             MOSI,
    output            MISO,
    output reg [7:0]  data_out,
    output            READY
);

    reg [7:0] tx_shift;
    reg [7:0] rx_shift;
    reg [2:0] bit_cnt;
    reg       active;
    reg       sclk_d;
    wire      cs_active;

    wire sclk_rise = (SCLK == 1'b1) && (sclk_d == 1'b0);

    assign cs_active = (CS == 1'b0);
    assign READY     = (!cs_active) && (active == 1'b0);
    assign MISO      = cs_active ? tx_shift[bit_cnt] : 1'b0;

    always @(posedge REFCLK or negedge RST_N) begin
        if (!RST_N) begin
            tx_shift <= 8'h00;
            rx_shift <= 8'h00;
            bit_cnt  <= 3'd7;
            active   <= 1'b0;
            sclk_d   <= 1'b0;
            data_out   <= 8'h00;
        end else begin
            sclk_d <= SCLK;

            // Synchronous load. This replaces always @(posedge LOAD), which
            // would incorrectly treat a data-enable as a generated clock.
            if (LOAD && READY) begin
                tx_shift <= data_in;
            end

            if (!cs_active) begin
                active  <= 1'b0;
                bit_cnt <= 3'd7;
            end else begin
                active <= 1'b1;

                if (sclk_rise) begin
                    rx_shift[bit_cnt] <= MOSI;

                    if (bit_cnt == 3'd0) begin
                        data_out  <= {rx_shift[7:1], MOSI};
                        bit_cnt <= 3'd7;
                        active  <= 1'b0;
                    end else begin
                        bit_cnt <= bit_cnt - 3'd1;
                    end
                end
            end
        end
    end
endmodule
