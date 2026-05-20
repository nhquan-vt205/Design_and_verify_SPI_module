VERILATOR ?= verilator
JOBS      ?= 4
BUILD_DIR ?= obj_dir

RTL_DIR = RTL
TB_DIR  = Testbench

MASTER_RTL = $(RTL_DIR)/spi_master.v
SLAVE_RTL  = $(RTL_DIR)/spi_slave.v
TOP_RTL    = $(RTL_DIR)/spi_communication.v

TB_MASTER = $(TB_DIR)/tb_spi_master.v
TB_SLAVE  = $(TB_DIR)/tb_spi_slave.v
TB_COMM   = $(TB_DIR)/tb_spi_communication.v

.PHONY: comm master slave all build run \
	build-comm build-master build-slave \
	run-comm run-master run-slave clean

build-comm:
	mkdir -p $(BUILD_DIR)/comm
	$(VERILATOR) --binary --trace -j $(JOBS) --Mdir $(BUILD_DIR)/comm \
		--top-module tb_spi_communication \
		$(MASTER_RTL) $(SLAVE_RTL) $(TOP_RTL) $(TB_COMM)

run-comm:
	./$(BUILD_DIR)/comm/Vtb_spi_communication

comm: build-comm run-comm

build-master:
	mkdir -p $(BUILD_DIR)/master
	$(VERILATOR) --binary --trace -j $(JOBS) --Mdir $(BUILD_DIR)/master \
		--top-module tb_spi_master \
		$(MASTER_RTL) $(TB_MASTER)

run-master:
	./$(BUILD_DIR)/master/Vtb_spi_master

master: build-master run-master

build-slave:
	mkdir -p $(BUILD_DIR)/slave
	$(VERILATOR) --binary --trace -j $(JOBS) --Mdir $(BUILD_DIR)/slave \
		--top-module tb_spi_slave \
		$(SLAVE_RTL) $(TB_SLAVE)

run-slave:
	./$(BUILD_DIR)/slave/Vtb_spi_slave

slave: build-slave run-slave

build: build-master build-slave build-comm

run: run-comm

all: master slave comm

clean:
	rm -rf $(BUILD_DIR)
