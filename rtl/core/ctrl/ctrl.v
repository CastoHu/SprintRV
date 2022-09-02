`include "defines.v"

module ctrl(
        input wire                   clk_i,
        input wire                   n_rst_i,
        input wire[`RegBus]          exception_i,
        input wire[`RegBus]          pc_i,
        input wire[`RegBus]          inst_i,

        /* ----- stall request from other modules --------*/
        input wire                   stallreq_from_if_i,
        input wire                   stallreq_from_id_i,
        input wire                   stallreq_from_ex_i,
        input wire                   stallreq_from_mem_i,

        /* ------------  signals from CSR  ---------------*/
        input wire                   mstatus_ie_i,
        input wire                   mie_external_i,
        input wire                   mie_timer_i,
        input wire                   mie_sw_i,
        input wire                   mip_external_i,
        input wire                   mip_timer_i,
        input wire                   mip_sw_i,
        input wire[`RegBus]          mtvec_i,
        input wire[`RegBus]          epc_i,

        /* ------------  signals from CSR  ---------------*/
        output reg                   ie_type_o,
        output reg                   set_cause_o,
        output reg[3:0]              trap_casue_o,
        output reg                   set_epc_o,
        output reg[`RegBus]          epc_o,
        output reg                   set_mtval_o,
        output reg[`RegBus]          mtval_o,
        output reg                   mstatus_ie_clear_o,
        output reg                   mstatus_ie_set_o,

        /* ---signals to other stages of the pipeline  ----*/
        output reg[5:0]              stall_o,
        output reg                   flush_o,
        output reg[`RegBus]          new_pc_o
    );

    /* --------------------- handle the stall request -------------------*/
    always @ (*) begin
        if(n_rst_i == `RstEnable) begin
            stall_o = 6'b000000;
        end
        else if(stallreq_from_mem_i == `Stop) begin
            stall_o = 6'b011111;
        end
        else if(stallreq_from_ex_i == `Stop) begin
            stall_o = 6'b001111;
        end
        else if(stallreq_from_id_i == `Stop) begin
            stall_o = 6'b000111;
        end
        else if(stallreq_from_if_i == `Stop) begin
            stall_o = 6'b000111;
        end
        else begin
            stall_o = 6'b000000;
        end
    end


    /* --------------------- handle the the interrupt and exceptions -------------------*/
    reg [3:0] curr_state;
    reg [3:0] next_state;
    parameter STATE_RESET         = 4'b0001;
    parameter STATE_OPERATING     = 4'b0010;
    parameter STATE_TRAP_TAKEN    = 4'b0100;
    parameter STATE_TRAP_RETURN   = 4'b1000;

    wire   mret;
    wire   ecall;
    wire   ebreak;
    wire   misaligned_inst;
    wire   illegal_inst;
    wire   misaligned_store;
    wire   misaligned_load;
    assign {misaligned_load, misaligned_store, illegal_inst, misaligned_inst, ebreak, ecall, mret} = exception_i[6:
            0];
    wire   eip;
    wire   tip;
    wire   sip;
    wire   ip;
    assign eip = mie_external_i & mip_external_i;
    assign tip = mie_timer_i &  mip_timer_i;
    assign sip = mie_sw_i & mip_sw_i;
    assign ip = eip | tip | sip;

    wire   trap_happened;
    assign trap_happened = (mstatus_ie_i & ip) | ecall | misaligned_inst | illegal_inst | misaligned_store | misaligned_load;
    /*debug info
    always @ (*) begin
        if(tip)
            $display("view num: eip:%h tip:%h sip:%h ip:%h trap_happened:%h mstatus_ie_i:%h \n", eip, tip, sip, ip, trap_happened, mstatus_ie_i);
        if(mret)
            $display("====mret set\n");
    end
	*/
    always @ (*)   begin
        case(curr_state)
            STATE_RESET: begin
                next_state = STATE_OPERATING;
            end

            STATE_OPERATING: begin
                if(trap_happened) begin
                    next_state = STATE_TRAP_TAKEN;
                end
                else if(mret) begin
                    next_state = STATE_TRAP_RETURN;
                end
                else begin
                    next_state = STATE_OPERATING;
                end
            end

            STATE_TRAP_TAKEN: begin
                next_state = STATE_OPERATING;
            end

            STATE_TRAP_RETURN: begin
                next_state = STATE_OPERATING;
            end

            default: begin
                next_state = STATE_OPERATING;
            end
        endcase
    end

    always @(posedge clk_i) begin
        if(n_rst_i == `RstEnable) begin
            curr_state <= STATE_RESET;
        end
        else begin
            curr_state <= next_state;
        end
    end

    assign epc_o = pc_i;
    reg [1:0]          mtvec_mode;
    reg [29:0]         mtvec_base;
    assign mtvec_base = mtvec_i[31:2];
    assign mtvec_mode = mtvec_i[1:0];
    reg[`RegBus] trap_mux_out;
    wire [`RegBus] vec_mux_out;
    wire [`RegBus] base_offset;

    assign base_offset = {26'b0, trap_casue_o, 2'b0};  // trap_casue_o * 4
    assign vec_mux_out = mtvec_i[0] ? {mtvec_base, 2'b00} + base_offset : {mtvec_base, 2'b00};
    assign trap_mux_out = ie_type_o ? vec_mux_out : {mtvec_base, 2'b00};

    always @ (*)   begin
        case(curr_state)
            STATE_RESET: begin
                flush_o = 1'b0;
                new_pc_o = `REBOOT_ADDR;
                set_epc_o = 1'b0;
                set_cause_o = 1'b0;
                mstatus_ie_clear_o = 1'b0;
                mstatus_ie_set_o = 1'b0;
            end

            STATE_OPERATING: begin
                flush_o = 1'b0;
                new_pc_o = `ZeroWord;
                set_epc_o = 1'b0;
                set_cause_o = 1'b0;
                mstatus_ie_clear_o = 1'b0;
                mstatus_ie_set_o = 1'b0;
            end

            STATE_TRAP_TAKEN: begin
                flush_o = 1'b1;
                new_pc_o = trap_mux_out;
                set_epc_o = 1'b1;
                set_cause_o = 1'b1;
                mstatus_ie_clear_o = 1'b1;
                mstatus_ie_set_o = 1'b0;
            end

            STATE_TRAP_RETURN: begin
                flush_o = 1'b1;
                new_pc_o =  epc_i;
                set_epc_o = 1'b0;
                set_cause_o = 1'b0;
                mstatus_ie_clear_o = 1'b0;
                mstatus_ie_set_o = 1'b1;
            end

            default: begin
                flush_o = 1'b0;
                new_pc_o = `ZeroWord;
                set_epc_o = 1'b0;
                set_cause_o = 1'b0;
                mstatus_ie_clear_o = 1'b0;
                mstatus_ie_set_o = 1'b0;
            end
        endcase
    end


    always @(posedge clk_i)begin
        if(n_rst_i == `RstEnable) begin
            trap_casue_o <= 4'b0;
            ie_type_o <= 1'b0;
            set_mtval_o <= 1'b0;
            mtval_o <= `ZeroWord;

        end
        else if(curr_state == STATE_OPERATING) begin
            if(mstatus_ie_i & eip) begin
                trap_casue_o <= 4'b1011;
                ie_type_o <= 1'b1;
            end
            else if(mstatus_ie_i & sip) begin
                trap_casue_o <= 4'b0011;
                ie_type_o <= 1'b1;
            end
            else if(mstatus_ie_i & tip) begin
                trap_casue_o <= 4'b0111;
                ie_type_o <= 1'b1;

            end
            else if(misaligned_inst) begin
                trap_casue_o <= 4'b0000;
                ie_type_o <= 1'b0;
                set_mtval_o <= 1'b1;
                mtval_o <= pc_i;

            end
            else if(illegal_inst) begin
                trap_casue_o <= 4'b0010;
                ie_type_o <= 1'b0;
                set_mtval_o <= 1'b1;
                mtval_o <= inst_i;

            end
            else if(ebreak) begin
                trap_casue_o <= 4'b0011;
                ie_type_o <= 1'b0;
                set_mtval_o <= 1'b1;
                mtval_o <= pc_i;

            end
            else if(misaligned_store) begin
                trap_casue_o <= 4'b0110;
                ie_type_o <= 1'b0;
                set_mtval_o <= 1'b1;
                mtval_o <= pc_i;

            end
            else if(misaligned_load) begin
                trap_casue_o <= 4'b0100;
                ie_type_o <= 1'b0;
                set_mtval_o <= 1'b1;
                mtval_o <= pc_i;

            end
            else if(ecall) begin
                trap_casue_o <= 4'b1011;
                ie_type_o <= 1'b0;
            end
        end
    end

endmodule
