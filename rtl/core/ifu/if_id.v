`include "defines.v"

module if_id(

        input wire                    clk_i,
        input wire                    n_rst_i,
        /* ------- signals from the ctrl unit --------*/
        input wire[5:0]               stall_i,
        input wire                    flush_i,
        /* ------- signals from the ifu  -------------*/
        input wire[`InstAddrBus]      pc_i,
        input wire[`InstAddrBus]      next_pc_i,
        input wire                    next_branch_i,
        input wire                    branch_slot_end_i
        /* ------- signals from the inst_rom  --------*/
        input wire[`InstBus]          inst_i,
        /* ---------signals from exu -----------------*/
        input wire                    branch_redirect_i,
        /* ------- signals to the decode -------------*/
        output reg[`InstAddrBus]      pc_o,
        output reg[`InstBus]          inst_o,
        output reg[`InstAddrBus]      next_pc_o,
        output reg                    next_branch_o,
        output reg                    branch_slot_end_o
    );

    always @ (posedge clk_i) begin
        if (n_rst_i == `RstEnable) begin
            pc_o <= `ZeroWord;
            inst_o <= `NOP_INST;
            branch_slot_end_o <= `BranchNotEnd;
        end
        else if (branch_redirect_i == `Branch) begin
            pc_o <= pc_i;
            inst_o <= `NOP_INST;
            branch_slot_end_o <= `BranchNotEnd;
        end
        else if(flush_i == `PipelineFlush ) begin
            pc_o <= pc_i;
            inst_o <= `NOP_INST;
            branch_slot_end_o <= `BranchNotEnd;
        end
        else if(stall_i[1] == `Stop && stall_i[2] == `NoStop) begin
            pc_o <= pc_i;
            inst_o <= `NOP_INST;
            branch_slot_end_o <= `BranchNotEnd;
        end
        else if(stall_i[1] == `NoStop) begin
            pc_o <= pc_i;
            inst_o <= inst_i;
            next_pc_o <= next_pc_i;
            next_branch_o <= next_branch_i;
            branch_slot_end_o <= branch_slot_end_i;
        end
    end
endmodule
