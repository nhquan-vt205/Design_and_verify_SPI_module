# SPI Module Design & Verification

## 1. Project Overview
This repository contains an RTL design and verification project for an **8-bit full-duplex SPI subsystem** using **SPI Mode 0** (CPOL=0, CPHA=0) and **MSB-first** transfer.

The project demonstrates a complete mini flow for digital design verification:
- Implementing synthesizable RTL blocks for SPI master/slave communication.
- Integrating the design at top level.
- Verifying protocol behavior with both directed and class-based testbench methodologies.

---

## 2. Project Scope and Objectives
The implemented subsystem targets the following objectives:
- Build a working SPI data path between one master and one integrated slave.
- Support deterministic 8-bit transfer sequencing with explicit control signaling.
- Validate protocol correctness for:
  - transfer start/stop behavior,
  - slave select activation/deactivation,
  - TX/RX byte exchange on both ends,
  - ready/idle handshaking around each transaction.

---

## 3. RTL Design Architecture

### 3.1 `spi_master`
The master is implemented as a finite state machine driven by `REFCLK` with active-low reset `RST_N`.

**State machine:**
- `ST_IDLE`
- `ST_TRANSFER`
- `ST_WAIT_RELEASE`

**Control interface (`CNTL`):**
- `2'b00`: no operation
- `2'b01`: load transmit byte (`tx_data`)
- `2'b10`: store slave-select decode from `select_ss`
- `2'b11`: start one 8-bit transfer

**Protocol behavior:**
- `SS` is asserted only during active transfer and returns to `8'hFF` in idle.
- Mode-0 timing is respected:
  - sample `MISO` on SCLK rising edge,
  - update/shift `MOSI` on SCLK falling edge.
- `READY` is deasserted during transfer and reasserted when the transaction is fully released.

### 3.2 `spi_slave`
The slave is synchronously implemented on `REFCLK` and uses:
- active-low `CS` for chip selection,
- synchronous `LOAD` as data-enable for transmit preload,
- internal rising-edge detection of `SCLK` to capture incoming MOSI bits.

**Protocol behavior:**
- `MISO` is driven from the current TX bit when `CS` is active.
- Receive data is assembled bit-by-bit into `data_out`.
- Slave `READY` indicates idle/not-selected completion status.

### 3.3 `spi_communication` (Top Module)
The top module integrates one master and one slave instance and wires internal SPI signals:
- `MOSI`, `MISO`, `SCLK`, and `SS` are exposed for observability.
- `SS[0]` is mapped as the active chip-select for the integrated slave.
- Remaining `SS` bits still reflect master decode behavior for visibility.

---

## 4. Top-Level Module Diagram

```text
                    +---------------------------------------+
                    |           spi_communication           |
                    |                                       |
 M_INPUT ---------->|                                       |
 M_SELECT_SS ------>|                                       |
 M_CNTL ----------->|           +---------------+           |
 M_OUTPUT <---------|-----------|   spi_master  |-----------|--> SCLK
 M_READY <----------|           +---------------+           |
                    |                 |   ^                 |
                    |               MOSI  | MISO            |
                    |                 v   |                 |
 S_INPUT ---------->|           +---------------+           |
 S_LOAD ----------->|-----------|   spi_slave   |           |
 S_OUTPUT <---------|-----------+---------------+           |
 S_READY <----------|                 ^                     |
                    |                 | CS = SS[0]          |
                    +---------------------------------------+
```

---

## 5. Verification Methodology

## 5.1 Directed Static Testbench (`static_tb/`)
The static environment is task-driven and deterministic. It sequences reset, preload, slave selection, and transfer start through explicit tasks.

**Verification characteristics:**
- Directed functional test scenarios.
- Self-checking conditions with pass/fail accounting.
- Protocol checks around:
  - master/slave ready states,
  - SS assertion timing,
  - correctness of received bytes on both sides,
  - consecutive transaction behavior.
- Waveform dumping for debug traceability.

### 5.2 Class-Based OOP Testbench (`oop_tb/`)
The OOP environment models a compact verification architecture using reusable components:
- `spi_transaction`: randomized stimulus object.
- `spi_generator`: transaction producer.
- `spi_driver`: protocol-aware pin-level stimulus executor.
- `spi_monitor`: output collection and runtime checking.

**Verification characteristics:**
- Constrained-random transaction generation.
- Mailbox-based inter-component communication.
- Concurrent execution of generator/driver/monitor.
- Runtime pass/fail statistics from monitored transaction completions.

---

## 6. Repository Structure

```text
Design_and_verify_SPI_module/
├── RTL/
│   ├── spi_master.v
│   ├── spi_slave.v
│   └── spi_communication.v
├── static_tb/
│   ├── tb_spi_master.v
│   ├── tb_spi_slave.v
│   └── tb_spi_communication.v
├── oop_tb/
│   ├── spi_transaction.sv
│   ├── spi_generator.sv
│   ├── spi_driver.sv
│   ├── spi_monitor.sv
│   ├── tb_top.sv
│   └── testbench_eda.sv
├── SPI_Design_Spec.docx
├── SPI_Checklist_static_testing.xlsx
├── Makefile
└── tb_spi_communication.vcd
```

---

## 7. Technical Boundaries and Improvement Opportunities
Current boundaries:
- The integrated top connects one physical slave (`SS[0]`); additional SS lines are observable but not connected to extra slave instances.
- The verification flow includes directed checks and basic constrained-random stimulus, but does not yet include full assertion-based verification (SVA) or functional coverage metrics.

Potential next improvements:
- Add assertion checks for SPI timing/protocol invariants.
- Add scoreboard-based expected-vs-actual data comparison per transaction.
- Extend top-level architecture to multi-slave integration.
- Add structured regression scripts for repeatable batch verification.

---

## 8. Important Note
- The current **Makefile is not usable as-is** for running this project end-to-end in its present form.
