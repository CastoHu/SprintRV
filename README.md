# SprintRV
A traditional 5-level pipelined RISCVIMZicsr instruction set core based on System Verilog. The project was guided using Verilator Simulation. Before emulation, you might ensure that the Linux VM/system includes the RISCV32 toolchain for cross-compilation.
To make sure that the user has a good emulation environment, I provide a helloworld file that has been compiled as a `.vmem` type for verification. The detailed usage is described later.

## Introduce

The design goal of this project is to be compatible with RV32I basic instruction set and M, Zicsr extensions, and support fixed entry interrupt, machine mode only. SprintRV test bench consists of the CPU core, the data bus, and some other necessary peripheral devices,  including a dual-port RAM, the simulator ctrl, and a timer to produce interrupts. The bus,  simulator ctrl and the timer are from the open-source project provided by lowRISC.

SprintRV uses the branch prediction method to reduce NOP instruction vacuoles generated in the pipeline, and considering that there is no error in the memory access stage in the 5-level pipelined CPU, the processing of interrupts is postponed to the memory access stage for unified processing (memory address alignment, error address and other problems have been solved in the decoding/execution stage).

SprintRV uses the bus provided by lowRISC and can be easily extended when adding future peripherals by simply fixing the memory address mapping and number of devices in `simple_system.v`.

This project related simulation program in the `simulation` directory(`simu_main.cc` file), in the actual simulation process, we can specify program parameters to realize the simulation of different `.vmem` files. For specific file compilation parameters and compilation process, you see the related `Makefile` and.`.mk` files.

This project has passed the `coremark` test, the ordinary 32-bit program running and completed the clock interrupt processing.

## Usage

In the main file directory, use the following command to compile all simulation files and generate the Verilator simulation tool program:

```
make all
```

After compiling a `tb` file, run the corresponding program file with specified program parameters. You can view the corresponding result in the `./log/console.log` file.

For example, you can run the `helloworld.vmem` program:

```
./tb ./examples/test/helloworld/helloworld.vmem
```

You can run the `helloworld.vmem` program:

```
./tb ./examples/test/coremark/core_main.vmem
```

## System Architecture

![image](https://github.com/CastoHu/SprintRV/blob/main/docs/system_arch.png)

## Update Plan

1. Jtag support
2. Off-chip Flash boot
3. BSP support (I have successfully simulated on FPGA offline, but do not provide relevant steps, BSP is under development 70%)
4. Peripheral I/O interface and related peripheral support
