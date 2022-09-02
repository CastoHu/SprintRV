`include "defines.v"

module mem_wb(
        input wire                    clk_i,
        input wire                    n_rst_i,
        /*-- signals from contrl module -----*/
        input wire[5:0]               stall_i,
        input wire                    flush_i,
        /*-- signals from mem -----*/
        input wire                    rd_we_i,
        input wire[`RegAddrBus]       rd_addr_i,
        input wire[`RegBus]           rd_wdata_i,
        input wire                    csr_we_i,
        input wire[`RegBus]           csr_waddr_i,
        input wire[`RegBus]           csr_wdata_i,
        /*-- signals passed to mem_wb stage -----*/
        output reg                    rd_we_o,
        output reg[`RegAddrBus]       rd_addr_o,
        output reg[`RegBus]           rd_wdata_o,
        output reg                    csr_we_o,
        output reg[`RegBus]           csr_waddr_o,
        output reg[`RegBus]           csr_wdata_o,
        output reg                    instret_incr_o
    );

    always @ (posedge clk_i) begin
        if(n_rst_i == `RstEnable) begin
            rd_we_o <= `WriteDisable;
            rd_addr_o <= `NOPRegAddr;
            rd_wdata_o <= `ZeroWord;
            csr_we_o <= `WriteDisable;
            csr_waddr_o <= `ZeroWord;
            csr_wdata_o <= `ZeroWord;
            instret_incr_o  <= 1'b0;
        end
        else if(flush_i == 1'b1 ) begin
            rd_we_o <= `WriteDisable;
            rd_addr_o <= `NOPRegAddr;
            rd_wdata_o <= `ZeroWord;
            csr_we_o <= `WriteDisable;
            csr_waddr_o <= `ZeroWord;
            csr_wdata_o <= `ZeroWord;
            instret_incr_o <= 1'b0;
        end
        else if(stall_i[4] == `Stop && stall_i[5] == `NoStop) begin
            rd_we_o <= `WriteDisable;
            rd_addr_o <= `NOPRegAddr;
            rd_wdata_o <= `ZeroWord;
            csr_we_o <= `WriteDisable;
            csr_waddr_o <= `ZeroWord;
            csr_wdata_o <= `ZeroWord;
            instret_incr_o  <= 1'b0;
        end
        else if(stall_i[4] == `NoStop) begin
            rd_we_o <= rd_we_i;
            rd_addr_o <= rd_addr_i;
            rd_wdata_o <= rd_wdata_i;
            csr_we_o <= csr_we_i;
            csr_waddr_o <= csr_waddr_i;
            csr_wdata_o <= csr_wdata_i;
            instret_incr_o  <= 1'b1;
        end
    end
endmodule
