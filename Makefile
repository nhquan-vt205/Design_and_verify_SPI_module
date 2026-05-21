IVERILOG  ?= iverilog
VVP       ?= vvp
BUILD_DIR ?= obj_dir

RTL_DIR = RTL
TB_DIR  = static_tb
OOP_DIR = oop_tb

MASTER_RTL = $(RTL_DIR)/spi_master.v
SLAVE_RTL  = $(RTL_DIR)/spi_slave.v
TOP_RTL    = $(RTL_DIR)/spi_communication.v

TB_MASTER = $(TB_DIR)/tb_spi_master.v
TB_SLAVE  = $(TB_DIR)/tb_spi_slave.v
TB_COMM   = $(TB_DIR)/tb_spi_communication.v

.PHONY: all build run clean \
	build-master run-master master \
	build-slave  run-slave  slave  \
	build-comm   run-comm   comm   \
	build-oop    run-oop    oop

# ──────────────────────────────────────────────────────────────────
# Static Testbench – Master
# ──────────────────────────────────────────────────────────────────
build-master:
	mkdir -p $(BUILD_DIR)/master
	$(IVERILOG) -g2012 -o $(BUILD_DIR)/master/sim.vvp \
		$(MASTER_RTL) $(TB_MASTER)

run-master:
	$(VVP) $(BUILD_DIR)/master/sim.vvp

master: build-master run-master

# ──────────────────────────────────────────────────────────────────
# Static Testbench – Slave
# ──────────────────────────────────────────────────────────────────
build-slave:
	mkdir -p $(BUILD_DIR)/slave
	$(IVERILOG) -g2012 -o $(BUILD_DIR)/slave/sim.vvp \
		$(SLAVE_RTL) $(TB_SLAVE)

run-slave:
	$(VVP) $(BUILD_DIR)/slave/sim.vvp

slave: build-slave run-slave

# ──────────────────────────────────────────────────────────────────
# Static Testbench – Communication (top)
# ──────────────────────────────────────────────────────────────────
build-comm:
	mkdir -p $(BUILD_DIR)/comm
	$(IVERILOG) -g2012 -o $(BUILD_DIR)/comm/sim.vvp \
		$(MASTER_RTL) $(SLAVE_RTL) $(TOP_RTL) $(TB_COMM)

run-comm:
	$(VVP) $(BUILD_DIR)/comm/sim.vvp

comm: build-comm run-comm

# ──────────────────────────────────────────────────────────────────
# OOP Testbench
# Verilator không hỗ trợ SV classes/mailbox → dùng iverilog -g2012
# ──────────────────────────────────────────────────────────────────
OOP_SRCS = \
	$(MASTER_RTL) \
	$(SLAVE_RTL) \
	$(TOP_RTL) \
	$(OOP_DIR)/tb_top.sv

build-oop:
	mkdir -p $(BUILD_DIR)/oop
	$(IVERILOG) -g2012 -o $(BUILD_DIR)/oop/sim.vvp $(OOP_SRCS)

run-oop:
	$(VVP) $(BUILD_DIR)/oop/sim.vvp

oop: build-oop run-oop

# ──────────────────────────────────────────────────────────────────
# Aliases
# ──────────────────────────────────────────────────────────────────
build: build-master build-slave build-comm build-oop

run: run-comm

all: master slave comm oop

clean:
	rm -rf $(BUILD_DIR)
