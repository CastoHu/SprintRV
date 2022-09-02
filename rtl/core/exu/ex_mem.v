`include "defines.v"

module ex_mem(

        input wire                    clk_i,
        input wire                    n_rst_i,
        /* ------- signals from the ctrl unit --------*/
        input wire[5:0]               stall_i,
        input wire                    flush_i,
        /* ------- signals from the exe unit --------*/
        input wire[`RegBus]           pc_i,
        input reg[`RegBus]            inst_i,
        input wire                    branch_tag_i,
        input wire                    branch_slot_end_i,
        input wire                    rd_we_i,
        input wire[`RegAddrBus]       rd_addr_i,
        input wire[`RegBus]           rd_wdata_i,
        input wire[`AluOpBus]         uopcode_i,
        input wire[`RegBus]           mem_addr_i,
        input wire[`RegBus]           mem_wdata_i,
        input wire                    csr_we_i,
        input wire[`RegBus]           csr_waddr_i,
        input wire[`RegBus]           csr_wdata_i,
        input wire[`RegBus]           exception_i,
        /* ------- signals to the lsu  --------*/
        output reg                    rd_we_o,
        output reg[`RegAddrBus]       rd_addr_o,
        output reg[`RegBus]           rd_wdata_o,
        output reg[`AluOpBus]         uopcode_o,
        output reg[`RegBus]           mem_addr_o,
        output reg[`RegBus]           mem_wdata_o,
        output reg                    csr_we_o,
        output reg[`RegBus]           csr_waddr_o,
        output reg[`RegBus]           csr_wdata_o,
        output reg[`RegBus]           exception_o,
        output reg[`RegBus]           pc_o,
        output reg[`RegBus]           inst_o

    );

    reg             branch_tag;
    reg[`RegBus]    branch_pc;

    always @ (posedge clk_i) begin
        if(n_rst_i == `RstEnable) begin
            rd_addr_o <= `NOPRegAddr;
            rd_we_o <= `WriteDisable;
            rd_wdata_o <= `ZeroWord;
            uopcode_o <= `UOP_CODE_NOP;
            mem_addr_o <= `ZeroWord;
            mem_wdata_o <= `ZeroWord;
            csr_we_o <= `WriteDisable;
            csr_waddr_o <= `ZeroWord;
            csr_wdata_o <= `ZeroWord;
            exception_o <= `ZeroWord;
            pc_o <= `ZeroWord;
            inst_o <= `NOP_INST;
            branch_tag <= 1'b0;
            branch_pc <= `NOP_INST;
        end
        else if(flush_i == 1'b1 ) begin
            rd_addr_o <= `NOPRegAddr;
            rd_we_o <= `WriteDisable;
            rd_wdata_o <= `ZeroWord;
            uopcode_o <= `UOP_CODE_NOP;
            mem_addr_o <= `ZeroWord;
            mem_wdata_o <= `ZeroWord;
            csr_we_o <= `WriteDisable;
            csr_waddr_o <= `ZeroWord;
            csr_wdata_o <= `ZeroWord;
            exception_o <= `ZeroWord;
            pc_o <= `ZeroWord;
            inst_o <= `NOP_INST;
            branch_tag <= 1'b0;
            branch_pc <= `NOP_INST;
        end
        else if(stall_i[3] == `Stop && stall_i[4] == `NoStop) begin
            rd_addr_o <= `NOPRegAddr;
            rd_we_o <= `WriteDisable;
            rd_wdata_o <= `ZeroWord;
            uopcode_o <= `UOP_CODE_NOP;
            mem_addr_o <= `ZeroWord;
            mem_wdata_o <= `ZeroWord;
            csr_we_o <= `WriteDisable;
            csr_waddr_o <= `ZeroWord;
            csr_wdata_o <= `ZeroWord;
            exception_o <= `ZeroWord;
            pc_o <= `ZeroWord;
            inst_o <= `NOP_INST;
            branch_tag <= 1'b0;
            branch_pc <= `NOP_INST;
        end
        else if(stall_i[3] == `NoStop) begin
            rd_addr_o <= rd_addr_i;
            rd_we_o <= rd_we_i;
            rd_wdata_o <= rd_wdata_i;
            uopcode_o <= uopcode_i;
            mem_addr_o <= mem_addr_i;
            mem_wdata_o <= mem_wdata_i;
            csr_we_o <= csr_we_i;
            csr_waddr_o <= csr_waddr_i;
            csr_wdata_o <= csr_wdata_i;
            exception_o <= exception_i;
            if( branch_tag_i == 1'b1 ) begin
                branch_tag <= 1'b1;
                branch_pc <= pc_i;
            end
            else begin
                if(branch_tag && branch_slot_end_i) begin
                    branch_tag <= 1'b0;
                end
            end
            if(branch_tag) begin
                pc_o <= branch_pc;
            end
            else begin
                pc_o <= pc_i;
            end
            inst_o <= inst_i;
        end
    end
endmodule
