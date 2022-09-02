`include "defines.v"

module csr_file(

        input wire               clk_i,
        input wire               n_rst_i,
        /* --- interrupt signals from clint or plic--------*/
        input  wire              irq_software_i,
        input  wire              irq_timer_i,
        input  wire              irq_external_i,
        /* --- exu read csr -------------------*/
        input wire[`RegBus]      raddr_i,
        output reg[`RegBus]      rdata_o,
        /*------ wb module update the csr  --------*/
        input wire               we_i,
        input wire[`RegBus]      waddr_i,
        input wire[`RegBus]      wdata_i,
        input wire               instret_incr_i,
        /* ---- ctrl update epc, mcause, mtval, global ie ----*/
        input wire               ie_type_i,
        input wire               set_cause_i,
        input wire [3:0]         trap_casue_i,
        input wire               set_epc_i,
        input wire[`RegBus]      epc_i,
        output reg               set_mtval_i,
        output reg[`RegBus]      mtval_i,
        input wire               mstatus_ie_clear_i,
        input wire               mstatus_ie_set_i,
        /*-- to control , interrupt enablers, mtvec, epc etc-----*/
        output reg               mstatus_ie_o,
        output wire              mie_external_o,
        output wire              mie_timer_o,
        output wire              mie_sw_o,
        output wire              mip_external_o,
        output wire              mip_timer_o,
        output wire              mip_sw_o,
        output wire[`RegBus]     mtvec_o,
        output wire[`RegBus]     epc_o
    );

    localparam CSR_MVENDORID_VALUE  = 32'b0;
    localparam CSR_MARCHID_VALUE = {1'b0, 31'd22};
    localparam  CSR_MIMPID_VALUE = 32'b0;
    localparam CSR_MHARTID = 32'b0;
    wire [1:0]  mxl;
    wire [25:0] mextensions;
    wire [`RegBus] misa;
    assign mxl = 2'b01;
    assign mextensions = 26'b00000000000001000100000000;
    assign misa = {mxl, 4'b0, mextensions};
    reg[`DoubleRegBus] mcycle;
    reg[`DoubleRegBus] minstret;

    always @ (posedge clk_i) begin
        if (n_rst_i == `RstEnable) begin
            mcycle <= {`ZeroWord, `ZeroWord};
            minstret <= {`ZeroWord, `ZeroWord};
        end
        else begin
            mcycle <= mcycle + 64'd1;
            if(instret_incr_i) begin
                minstret <= minstret + 64'd1;
            end
        end
    end

    reg[`RegBus]       mstatus;
    reg                mstatus_pie;
    reg                mstatus_ie;
    assign             mstatus_ie_o = mstatus_ie;
    assign mstatus = {19'b0, 2'b11, 3'b0, mstatus_pie, 3'b0 , mstatus_ie, 3'b0};

    always @(posedge clk_i) begin
        if(n_rst_i == `RstEnable) begin
            mstatus_ie <= 1'b0;
            mstatus_pie <= 1'b1;
        end
        else if( (waddr_i[11:0] == `CSR_MSTATUS_ADDR) && (we_i == `WriteEnable) ) begin
            mstatus_ie <= wdata_i[3];
            mstatus_pie <= wdata_i[7];
        end
        else if(mstatus_ie_clear_i == 1'b1) begin
            mstatus_pie <= mstatus_ie;
            mstatus_ie <= 1'b0;
        end
        else if(mstatus_ie_set_i == 1'b1) begin
            mstatus_ie <= mstatus_pie;
            mstatus_pie <= 1'b1;
        end
    end

    reg[`RegBus]  mie;
    reg           mie_external;
    reg           mie_timer;
    reg           mie_sw;

    assign mie_external_o = mie_external;
    assign mie_timer_o = mie_timer;
    assign mie_sw_o = mie_sw;
    assign mie = {20'b0, mie_external, 3'b0, mie_timer, 3'b0, mie_sw, 3'b0};

    always @(posedge clk_i) begin
        if(n_rst_i == `RstEnable) begin
            mie_external <= 1'b0;
            mie_timer <= 1'b0;
            mie_sw <= 1'b0;
        end
        else if((waddr_i[11:0] == `CSR_MIE_ADDR) && (we_i == `WriteEnable)) begin
            mie_external <= wdata_i[11];
            mie_timer <= wdata_i[7];
            mie_sw <= wdata_i[3];
        end
    end

    reg[`RegBus]     mtvec;
    assign mtvec_o = mtvec;

    always @(posedge clk_i) begin
        if(n_rst_i == `RstEnable) begin
            mtvec <= `MTVEC_RESET;
        end
        else if( (waddr_i[11:0] == `CSR_MTVEC_ADDR) && (we_i == `WriteEnable) ) begin
            mtvec <= wdata_i;
        end
    end
	
    reg[`RegBus]       mscratch;

    always @(posedge clk_i) begin
        if(n_rst_i == `RstEnable)
            mscratch <= `ZeroWord;
        else if( (waddr_i[11:0] == `CSR_MSCRATCH_ADDR) && (we_i == `WriteEnable) )
            mscratch <= wdata_i;
    end

    reg[`RegBus]       mepc;

    assign epc_o = mepc;
    always @(posedge clk_i) begin
        if(n_rst_i == `RstEnable) begin
            mepc <= `ZeroWord;
        end
        else if(set_epc_i) begin
            mepc <= {epc_i[31:2], 2'b00};
        end
        else if( (waddr_i[11:0] == `CSR_MEPC_ADDR) && (we_i == `WriteEnable) ) begin
            mepc <= {wdata_i[31:2], 2'b00};
        end
      
    end

    reg[`RegBus]       mcause;
    reg [3:0]          cause;
    reg [26:0]         cause_rem;
    reg                int_or_exc;

    assign mcause = {int_or_exc, cause_rem, cause};
    always @(posedge clk_i) begin
        if(n_rst_i == `RstEnable) begin
            cause <= 4'b0000;
            cause_rem <= 27'b0;
            int_or_exc <= 1'b0;
        end
        else if(set_cause_i) begin
            cause <= trap_casue_i;
            cause_rem <= 27'b0;
            int_or_exc <= ie_type_i;
        end
        else if( (waddr_i[11:0] == `CSR_MCAUSE_ADDR) && (we_i == `WriteEnable) ) begin
            cause <= wdata_i[3:0];
            cause_rem <= wdata_i[30:4];
            int_or_exc <= wdata_i[31];
        end
    end

    reg[`RegBus]       mip;
    reg                mip_external;
    reg                mip_timer;
    reg                mip_sw;

    assign mip = {20'b0, mip_external, 3'b0, mip_timer, 3'b0, mip_sw, 3'b0};
    assign mip_external_o = mip_external;
    assign mip_timer_o = mip_timer;
    assign mip_sw_o = mip_sw;

    always @(posedge clk_i) begin
        if(n_rst_i == `RstEnable) begin
            mip_external <= 1'b0;
            mip_timer <= 1'b0;
            mip_sw <= 1'b0;
        end
        else begin
            mip_external <= irq_external_i;
            mip_timer <= irq_timer_i;
            mip_sw <= irq_software_i;
        end
    end

    reg[`RegBus]       mtval;
    wire               MISALIGNED_EXCEPTION;

    always @(posedge clk_i)  begin
        if(n_rst_i == `RstEnable)
            mtval <= 32'b0;
        else if(set_mtval_i) begin
            mtval <= mtval_i;
        end
        else if( (waddr_i[11:0] == `CSR_MTVAL_ADDR) && (we_i == `WriteEnable) )
            mtval <= wdata_i;
    end

    always @ (*) begin
        if ((waddr_i[11:0] == raddr_i[11:0]) && (we_i == `WriteEnable)) begin
            rdata_o = wdata_i;
        end
        else begin
            case (raddr_i[11:0])
                `CSR_MVENDORID_ADDR: begin
                    rdata_o = CSR_MVENDORID_VALUE;
                end
                `CSR_MARCHID_ADDR: begin
                    rdata_o = CSR_MARCHID_VALUE;
                end
                `CSR_MIMPID_ADDR: begin
                    rdata_o = CSR_MIMPID_VALUE;
                end
                `CSR_MHARTID_ADDR: begin
                    rdata_o = CSR_MHARTID;
                end
                `CSR_MISA_ADDR: begin
                    rdata_o = misa;
                end
                `CSR_MCYCLE_ADDR, `CSR_CYCLE_ADDR: begin
                    rdata_o = mcycle[`RegBus];
                end
                `CSR_MCYCLEH_ADDR, `CSR_CYCLEH_ADDR: begin
                    rdata_o = mcycle[63:32];
                end
                `CSR_MINSTRET_ADDR: begin
                    rdata_o = minstret[`RegBus];
                end
                `CSR_MINSTRETH_ADDR: begin
                    rdata_o = minstret[63:32];
                end
                `CSR_MSTATUS_ADDR: begin
                    rdata_o = mstatus;
                end
                `CSR_MIE_ADDR: begin
                    rdata_o = mie;
                end
                `CSR_MTVEC_ADDR: begin
                    rdata_o = mtvec;
                end
                `CSR_MSCRATCH_ADDR: begin
                    rdata_o = mscratch;
                end
                `CSR_MEPC_ADDR: begin
                    rdata_o = mepc;
                end
                `CSR_MCAUSE_ADDR: begin
                    rdata_o = mcause;
                end
                `CSR_MIP_ADDR: begin
                    rdata_o = mip;
                end
                default: begin
                    rdata_o = `ZeroWord;
                end
            endcase
        end
    end
endmodule
