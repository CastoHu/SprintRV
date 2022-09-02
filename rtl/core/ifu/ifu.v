`include "defines.v"

module ifu(
        input   wire                  clk_i,
        input   wire                  n_rst_i,
        /* ------- signals from the ctrl unit --------*/
        input wire[5:0]               stall_i,
        input wire                    flush_i,
        input wire[`InstAddrBus]      trap_pc_i,
        /* --------signals from bp --------------------*/
        input reg[`InstAddrBus]       next_pc_i,
        input reg                     next_branch_i,
        input wire[`InstAddrBus]      branch_redirect_pc_i,
        /* ------- signals to inst_rom and decode unit --------*/
        output reg[`InstAddrBus]      pc_o,
        output reg                    ce_o,
        /* ---stall the pipeline, waiting for the rom to response with instruction ----*/
        output wire                   stall_req_o,
        /*-----the prediction info to exe unit---------------*/
        output reg[`InstAddrBus]      next_pc_o,
        output reg                    next_branch_o,
        /*-----if miss predicted, redirected pc to branch target started from here*/
        output reg                    branch_slot_end_o
    );

    assign  stall_req_o = `NoStop;
    assign  next_pc_o = next_pc_i;
    assign  next_branch_o = next_branch_i;

    always @ (posedge clk_i or negedge n_rst_i) begin
        if (n_rst_i == `RstEnable) begin
            ce_o <= `ChipDisable;
        end
        else begin
            ce_o <= `ChipEnable;
        end
    end

    always @ (posedge clk_i) begin
        if (ce_o == `ChipDisable) begin
            pc_o <= `REBOOT_ADDR;
            branch_slot_end_o <= `BranchNotEnd;
        end
        else begin
            if(flush_i == 1'b1) begin
                pc_o <= trap_pc_i;
                branch_slot_end_o <= `BranchNotEnd;
            end
            else if(stall_i[0] == `NoStop) begin
                if(branch_redirect_i == `Branch) begin
                    pc_o <= branch_redirect_pc_i;
                    branch_slot_end_o <= `BranchEnd;
                end
                else begin
                    pc_o <= next_pc_i;
                    branch_slot_end_o <= `BranchNotEnd;
                end
            end
            else begin
                pc_o <= pc_o;
                branch_slot_end_o <= `BranchNotEnd;
            end
        end
    end
endmodule
