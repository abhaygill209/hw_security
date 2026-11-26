SHELL := /bin/bash

VERIF_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
RTL_DIR := $(abspath $(VERIF_DIR)/../RTL)
REF_DIR := $(abspath $(VERIF_DIR)/../../ml_dsa_golden/dilithium/ref)
GENERATOR := $(VERIF_DIR)/build/generate_vectors
VECTORS := $(VERIF_DIR)/vectors.csv

CC ?= cc
CFLAGS := -std=c11 -O2 -Wall -Wextra -Werror -I$(REF_DIR)
SIM ?= verilator
TOPLEVEL_LANG := verilog
TOPLEVEL := ntt_vcd_tb
COCOTB_TEST_MODULES := test_ntt
VERILOG_SOURCES := $(VERIF_DIR)/ntt_vcd_tb.v $(RTL_DIR)/NTT_engine.v $(RTL_DIR)/ButterflyUnitCT.v \
                   $(RTL_DIR)/Delay_Unit.v $(RTL_DIR)/FIFO.v $(RTL_DIR)/PairReorder.v $(RTL_DIR)/TwiddleROM.v
COMPILE_ARGS += -I$(RTL_DIR)
SIM_BUILD := $(VERIF_DIR)/build/sim
export PYTHONPATH := $(VERIF_DIR):$(PYTHONPATH)

.DEFAULT_GOAL := all
.PHONY: all vectors clean lint
all: sim
lint:
	cd $(VERIF_DIR) && verilator --lint-only -Wall --top-module NTT_engine -I$(RTL_DIR) $(filter-out $(VERIF_DIR)/ntt_vcd_tb.v,$(VERILOG_SOURCES))
vectors: $(VECTORS)

$(GENERATOR): $(VERIF_DIR)/generate_vectors.c $(REF_DIR)/ntt.c $(REF_DIR)/reduce.c
	mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -o $@ $^

$(VECTORS): $(GENERATOR)
	$(GENERATOR) $@

# The RTL ROM paths are relative to Verif, so keep the simulator here.
sim: $(VECTORS)

clean::
	rm -rf $(VERIF_DIR)/build $(VERIF_DIR)/vectors.csv $(VERIF_DIR)/results.xml $(VERIF_DIR)/ntt.vcd

include $(shell cocotb-config --makefiles)/Makefile.sim
