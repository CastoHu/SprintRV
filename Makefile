CC      = g++
AR      = ar 
ARFLAGS = -r
LD      = ld
LDFLAGS = 
STANDARD_LIBS     = 
STANDARD_LIBS_DIR = 
MAKE   = make
RM = rm -rf
LOCAL_LIBS := ./simulation/obj_dir/libtb.a ./rtl/obj_dir/Vsimple_system__ALL.a
target = tb
rtl/obj_dir/Vsimple_system__ALL.a:
	$(MAKE) -C ./rtl -f rtl.mk all
simulation/obj_dir/libtb.a: ./rtl/obj_dir/Vsimple_system__ALL.a
	$(MAKE) -C ./simulation -f simulation.mk all

all: $(target)
$(target): $(LOCAL_LIBS) 
#	@echo 'Building target: $@'
#	@echo 'Invoking: gcc C Linker'
	$(CC) $(STANDARD_LIBS_DIR) -o $(target) $(STANDARD_LIBS) $(LOCAL_LIBS) $(LOCAL_LIBS)
#	@echo 'Finished building target: $@'
#	@echo ' '

clean:
	$(MAKE) -C ./simulation -f simulation.mk clean
	$(MAKE) -C ./rtl -f rtl.mk clean
	$(RM) $(target)

.PHONY: all clean
