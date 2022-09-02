.PHONY: all
.DELETE_ON_ERROR:
RTL_ROOT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
RTL_DIR :=$(RTL_ROOT_DIR)/core
TB_DIR :=$(RTL_ROOT_DIR)/tb
INC_DIR :=$(RTL_ROOT_DIR)/core/include
CORE_RTL_FILES := $(RTL_DIR)/ifu/ifu.v     $(RTL_DIR)/ifu/bp.v        $(RTL_DIR)/ifu/if_id.v     $(RTL_DIR)/dec/id.v        $(RTL_DIR)/dec/id_ex.v   \
				  $(RTL_DIR)/exu/ex.v      $(RTL_DIR)/exu/div.v       $(RTL_DIR)/exu/ex_mem.v    $(RTL_DIR)/lsu/mem.v     \
				  $(RTL_DIR)/lsu/mem_wb.v  $(RTL_DIR)/wb/gpr.v        $(RTL_DIR)/wb/csr.v	     $(RTL_DIR)/ctrl/ctrl.v   \
				  $(RTL_DIR)/core_top.v
TB_RTL_FILES := $(TB_DIR)/ram.v $(TB_DIR)/simple_system.v $(TB_DIR)/timer.v $(TB_DIR)/console.v  $(TB_DIR)/bus.v
VERILOG_FILES :=  $(TB_RTL_FILES)  \
	              $(CORE_RTL_FILES)
TOP_MOD = simple_system
VERILOG_OBJ_DIR = ./obj_dir
VERILATOR = verilator
VFLAGS = --cc -trace -Wno-style
VERILATOR_ROOT ?= $(shell bash -c '$(VERILATOR) -V|grep VERILATOR_ROOT | head -1 | sed -e "s/^.*=\s*//"')

$(VERILOG_OBJ_DIR)/V$(TOP_MOD).cpp: $(VERILOG_FILES)
#	@echo "===================compile RTL into cpp files, start=========================="
	$(VERILATOR) $(VFLAGS) -I$(INC_DIR) --top-module $(TOP_MOD) $(VERILOG_FILES) V$(TOP_MOD).cpp
#	@echo "===================compile RTL into cpp files, end ==========================="

$(VERILOG_OBJ_DIR)/V$(TOP_MOD)__ALL.a: $(VERILOG_OBJ_DIR)/V$(TOP_MOD).cpp
#	@echo "===============add rtl object files into cpp files, start======================"
	make -C $(VERILOG_OBJ_DIR) -f V$(TOP_MOD).mk
#	@echo "===============add rtl object files into cpp files, end======================"

all: $(VERILOG_OBJ_DIR)/V$(TOP_MOD)__ALL.a

.PHONY: clean
clean:
#	@echo "=========================cleaning RTL objects, start============================"
	rm -rf $(VERILOG_OBJ_DIR)/
#	@echo "=========================cleaning RTL objects, end============================"

