`include "defines.v"

module simple_system(

        input  wire          clk_i,
        input  wire          n_rst_i,
        input  wire          jtag_TCK,
        input  wire          jtag_TMS,
        input  wire          jtag_TDI,
        output wire          jtag_TDO
    );

	localparam int NrDevices = 3;
	localparam int NrHosts = 1;
	`define     HOST_CORE          0
    `define     DEV_RAM            0
    `define     DEV_CONSOLE        1
    `define     DEV_TIMER          2
	wire               rom_ce;
	wire[`InstAddrBus] inst_addr;
	wire[`InstBus]     inst;
	wire timer_irq_O;
	wire           host_req    [NrHosts];
	wire           host_gnt    [NrHosts];
	wire [31:0]    host_addr   [NrHosts];
	wire           host_we     [NrHosts];
	wire [3:0]     host_be     [NrHosts];
	wire [31:0]    host_wdata  [NrHosts];
	wire           host_rvalid [NrHosts];
	wire [31:0]    host_rdata  [NrHosts];
	wire           host_err    [NrHosts];
	wire           device_req    [NrDevices];
    wire [31:0]    device_addr   [NrDevices];
    wire           device_we     [NrDevices];
    wire [ 3:0]    device_be     [NrDevices];
    wire [31:0]    device_wdata  [NrDevices];
    wire           device_rvalid [NrDevices];
    wire [31:0]    device_rdata  [NrDevices];
    wire           device_err    [NrDevices];
    wire [31:0] cfg_device_addr_base [NrDevices];
    wire [31:0] cfg_device_addr_mask [NrDevices];
    assign cfg_device_addr_base[`DEV_RAM] = 32'h100000;
    assign cfg_device_addr_mask[`DEV_RAM] = ~32'hFFFFF;
    assign cfg_device_addr_base[`DEV_CONSOLE] = 32'h200000;
    assign cfg_device_addr_mask[`DEV_CONSOLE] = ~32'hFFFFF;
    assign cfg_device_addr_base[`DEV_TIMER] = 32'h300000;
    assign cfg_device_addr_mask[`DEV_TIMER] = ~32'hFFFFF;

    bus #(
            .NrDevices    ( NrDevices ),
            .NrHosts      ( NrHosts   ),
            .DataWidth    ( 32        ),
            .AddressWidth ( 32        )
        ) u_bus (
            .clk_i               (clk_i),
            .rst_ni              (n_rst_i),
            .host_req_i          (host_req     ),
            .host_gnt_o          (host_gnt     ),
            .host_addr_i         (host_addr    ),
            .host_we_i           (host_we      ),
            .host_be_i           (host_be      ),
            .host_wdata_i        (host_wdata   ),
            .host_rvalid_o       (host_rvalid  ),
            .host_rdata_o        (host_rdata   ),
            .host_err_o          (host_err     ),
            .device_req_o        (device_req   ),
            .device_addr_o       (device_addr  ),
            .device_we_o         (device_we    ),
            .device_be_o         (device_be    ),
            .device_wdata_o      (device_wdata ),
            .device_rvalid_i     (device_rvalid),
            .device_rdata_i      (device_rdata ),
            .device_err_i        (device_err   ),
            .cfg_device_addr_base,
            .cfg_device_addr_mask
        );

    ram data_ram0(
            .clk_i(clk_i),
            .ce_i(device_req[`DEV_RAM]),
            .addr_i(device_addr[`DEV_RAM]),
            .we_i(device_we[`DEV_RAM]),
            .sel_i(device_be[`DEV_RAM]),
            .data_i(device_wdata[`DEV_RAM]),
            .rvalid_o(device_rvalid[`DEV_RAM]),
            .data_o(device_rdata[`DEV_RAM]),
            .inst_ce_i(rom_ce),
            .pc_i(inst_addr),
            .inst_o(inst)
        );

    console #(
                .LogName("./log/console.log")
            ) console0 (
                .clk_i     (clk_i),
                .rst_ni    (n_rst_i),
                .req_i     (device_req[`DEV_CONSOLE]),
                .we_i      (device_we[`DEV_CONSOLE]),
                .be_i      (device_be[`DEV_CONSOLE]),
                .addr_i    (device_addr[`DEV_CONSOLE]),
                .wdata_i   (device_wdata[`DEV_CONSOLE]),
                .rvalid_o  (device_rvalid[`DEV_CONSOLE]),
                .rdata_o   (device_rdata[`DEV_CONSOLE])
            );

    timer #(
              .DataWidth    (32),
              .AddressWidth (32)
          ) u_timer (
              .clk_i          (clk_i),
              .rst_ni         (n_rst_i),
              .timer_req_i    (device_req[`DEV_TIMER]),
              .timer_we_i     (device_we[`DEV_TIMER]),
              .timer_be_i     (device_be[`DEV_TIMER]),
              .timer_addr_i   (device_addr[`DEV_TIMER]),
              .timer_wdata_i  (device_wdata[`DEV_TIMER]),
              .timer_rvalid_o (device_rvalid[`DEV_TIMER]),
              .timer_rdata_o  (device_rdata[`DEV_TIMER]),
              .timer_err_o    (device_err[`DEV_TIMER]),
              .timer_intr_o   (timer_irq_O)
          );

    core_top core_top0(
                 .clk_i(clk_i),
                 .n_rst_i(n_rst_i),
                 .rom_ce_o(rom_ce),
                 .rom_addr_o(inst_addr),
                 .rom_data_i(inst),
                 .ram_ce_o(host_req[`HOST_CORE]),
                 .ram_sel_o(host_be[`HOST_CORE]),
                 .ram_addr_o(host_addr[`HOST_CORE]),
                 .ram_we_o(host_we[`HOST_CORE]),
                 .ram_data_o(host_wdata[`HOST_CORE]),
                 .ram_data_rvalid(host_rvalid[`HOST_CORE]),
                 .ram_data_i(host_rdata[`HOST_CORE]),
                 .irq_software_i (1'b0),
                 .irq_timer_i(timer_irq_O),
                 .irq_external_i (1'b0)
             );

endmodule
