`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// File        : spi_communication.v
// Project     : Lab 2 - SPI Communication
// Description : Top-level module integrating one SPI Master and one SPI Slave.
//               Both submodules use REFCLK and active-low reset RST_N.
// -----------------------------------------------------------------------------

module spi_communication (
    input             REFCLK,
    input             RST_N,

    // Master control/data interface
    input      [7:0]  M_INPUT,
    input      [2:0]  M_SELECT_SS,
    input      [1:0]  M_CNTL,
    output     [7:0]  M_OUTPUT,
    output            M_READY,

    // Slave control/data interface
    input      [7:0]  S_INPUT,
    input             S_LOAD,
    output     [7:0]  S_OUTPUT,
    output            S_READY,

    // Exposed SPI wires for waveform observation
    output            MOSI,
    output            MISO,
    output            SCLK,
    output     [7:0]  SS
);

    wire mosi_w;
    wire miso_w;
    wire sclk_w;
    wire [7:0] ss_w;

    // This complete module integrates one slave on SS[0]. Other SS bits are
    // still decoded by the master and exposed for observation.
    wire cs_slave0 = ss_w[0];

    spi_master u_spi_master (
        .REFCLK (REFCLK),
        .RST_N  (RST_N),
        .data_in   (M_INPUT),
        .select_ss (M_SELECT_SS),
        .CNTL   (M_CNTL),
        .MISO   (miso_w),
        .data_out (M_OUTPUT),
        .READY  (M_READY),
        .MOSI   (mosi_w),
        .SCLK   (sclk_w),
        .SS     (ss_w)
    );

    spi_slave u_spi_slave (
        .REFCLK (REFCLK),
        .RST_N  (RST_N),
        .SCLK   (sclk_w),
        .CS     (cs_slave0),
        .LOAD   (S_LOAD),
        .data_in  (S_INPUT),
        .MOSI   (mosi_w),
        .MISO   (miso_w),
        .data_out (S_OUTPUT),
        .READY  (S_READY)
    );

    assign MOSI = mosi_w;
    assign MISO = miso_w;
    assign SCLK = sclk_w;
    assign SS   = ss_w;
endmodule
