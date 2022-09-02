.PHONY: all
.DELETE_ON_ERROR:
CC      = g++
AR      = ar 
ARFLAGS = -r
LD      = ld
LDFLAGS = 
VERILATOR = verilator
VERILATOR_ROOT ?= $(shell bash -c '$(VERILATOR) -V|grep VERILATOR_ROOT | head -1 | sed -e "s/^.*=\s*//"')
VINC = $(VERILATOR_ROOT)/include
VINC1 = $(VERILATOR_ROOT)/include/vltstd
VERILOG_OBJ_DIR = ../rtl/obj_dir

CFLAGS = -g -Wall -faligned-new -c -I$(VINC) -I$(VINC1) -I$(VERILOG_OBJ_DIR)

STANDARD_LIBS     = 
STANDARD_LIBS_DIR = 
TARGET_DIR = ./obj_dir
objects = $(TARGET_DIR)/simu_main.o $(TARGET_DIR)/verilated_vcd_c.o $(TARGET_DIR)/verilated.o $(TARGET_DIR)/verilated_dpi.o
target  = $(TARGET_DIR)/libtb.a
$(TARGET_DIR):
	mkdir $@

$(TARGET_DIR)/simu_main.o: simu_main.cc $(TARGET_DIR)
	@echo 'Building file: $<'
	@echo 'Invoking: $(CC) C Compiler'
	$(CC) $(CFLAGS)  $< -o $@
	@echo 'Finished building: $<'
	@echo ' '

$(TARGET_DIR)/verilated_vcd_c.o: $(VINC)/verilated_vcd_c.cpp
	@echo 'Building file: $<'
	@echo 'Invoking: $(CC) C Compiler'
	$(CC) $(CFLAGS)  $< -o $@
	@echo 'Finished building: $<'
	@echo ' '

$(TARGET_DIR)/verilated.o: $(VINC)/verilated.cpp
	@echo 'Building file: $<'
	@echo 'Invoking: $(CC) C Compiler'
	$(CC) $(CFLAGS)  $< -o $@
	@echo 'Finished building: $<'
	@echo ' '

$(TARGET_DIR)/verilated_dpi.o: $(VINC)/verilated_dpi.cpp
	@echo 'Building file: $<'
	@echo 'Invoking: $(CC) C Compiler'
	$(CC) $(CFLAGS)  $< -o $@
	@echo 'Finished building: $<'
	@echo ' '

all: $(target)

$(target): $(objects) 
	@echo "add objects [$(objects)] to lib:$(target)"
	@$(AR) $(ARFLAGS) $(target) $(objects)
	@echo ' '

clean:
	$(RM) $(target)
	$(RM) $(objects)
	
.PHONY: all clean
