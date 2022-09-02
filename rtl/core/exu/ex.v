`include "defines.v"

module ex(

        input wire                    n_rst_i,
        /* ------- signals from the decoder unit --------*/
        input wire[`RegBus]           pc_i,
        input wire[`RegBus]           inst_i,
        input wire[`RegBus]           next_pc_i,
        input wire                    next_branch_i,
        input wire                    branch_slot_end_i,
        input wire[`AluSelBus]        alusel_i,
        input wire[`AluOpBus]         uopcode_i,
        input wire[`RegBus]           rs1_data_i,
        input wire[`RegBus]           rs2_data_i,
        input wire[`RegBus]           imm_i,
        input wire                    rd_we_i,
        input wire[`RegAddrBus]       rd_addr_i,
        input wire                    csr_we_i,
        input wire[`RegBus]           csr_addr_i,
        input wire[31:0]              exception_i,
        /* ------- signals with division unit --------*/
        output reg[`RegBus]           dividend_o,
        output reg[`RegBus]           divisor_o,
        output reg                    div_start_o,
        output reg                    div_signed_o,
        input wire[`DoubleRegBus]     div_result_i,
        input wire                    div_ready_i,
        /* ------- signals to the ctrl unit --------*/
        output reg                    stall_req_o,
        /* ------- signals with csr unit --------*/
        output reg[`RegBus]           csr_raddr_o,
        input wire[`RegBus]           csr_rdata_i,
        /* ------- bypass signals from lsu, for csr dependance detection --------*/
        input wire                    mem_csr_we_i,
        input wire[`RegBus]           mem_csr_waddr_i,
        input wire[`RegBus]           mem_csr_wdata_i,
        /* ------- bypass signals from write back, for csr dependance detection --------*/
        input wire                    wb_csr_we_i,
        input wire[`RegBus]           wb_csr_waddr_i,
        input wire[`RegBus]           wb_csr_wdata_i,
        /* ------- passed to next pipeline --------*/
        output reg[`RegBus]           pc_o,
        output reg[`RegBus]           inst_o,
        output reg                    branch_request_o,
        output reg                    branch_is_taken_o,
        output reg                    branch_is_call_o,
        output reg                    branch_is_ret_o,
        output reg                    branch_is_jmp_o,
        output reg[`RegBus]           branch_target_o,
        output reg                    branch_redirect_o,
        output reg[`RegBus]           branch_redirect_pc_o,
        output reg                    branch_tag_o,
        output reg                    branch_slot_end_o,
        output reg                    csr_we_o,
        output reg[`RegBus]           csr_waddr_o,
        output reg[`RegBus]           csr_wdata_o,
        output reg                    rd_we_o,
        output reg[`RegAddrBus]       rd_addr_o,
        output reg[`RegBus]           rd_wdata_o,
        output reg[`AluOpBus]         uopcode_o,
        output reg[`RegBus]           mem_addr_o,
        output reg[`RegBus]           mem_wdata_o,
        output reg[31:0]             exception_o
    );
    reg    stallreq_for_div;

    assign pc_o = pc_i;
    assign inst_o = inst_i;
    assign branch_slot_end_o = branch_slot_end_i;
    wire[4:0]  rs1 = inst_i[19:15];
    assign csr_we_o =  csr_we_i;
    assign rd_we_o = rd_we_i;
	
    always @ (*) begin
        csr_waddr_o = csr_addr_i;
        rd_addr_o = rd_addr_i;
    end

    assign uopcode_o = uopcode_i;
    assign exception_o = exception_i;
    wire[`RegBus] pc_plus_4;
    assign pc_plus_4 = pc_i + 4;
    wire[`RegBus] pc_add_imm;
    assign pc_add_imm =  pc_i + imm_i;
    wire[`RegBus] rs1_add_imm;
    assign rs1_add_imm =  rs1_data_i + imm_i;
    wire[`RegBus] rs1_or_imm;
    assign  rs1_or_imm = rs1_data_i | imm_i;
    wire[`RegBus] rs1_and_imm;
    assign  rs1_and_imm = rs1_data_i & imm_i;
    wire[`RegBus] rs1_xor_imm;
    assign  rs1_xor_imm = rs1_data_i ^ imm_i;
    wire[`RegBus] rs1_add_rs2;
    assign rs1_add_rs2 =  rs1_data_i + rs2_data_i;
    wire[`RegBus] rs1_sub_rs2;
    assign rs1_sub_rs2 =  rs1_data_i - rs2_data_i;
    wire[`RegBus] rs1_and_rs2;
    assign  rs1_and_rs2 = rs1_data_i & rs2_data_i;
    wire[`RegBus] rs1_or_rs2;
    assign  rs1_or_rs2 = rs1_data_i |rs2_data_i;
    wire[`RegBus] rs1_xor_rs2;
    assign  rs1_xor_rs2 = rs1_data_i ^ rs2_data_i;

    wire rs1_ge_rs2_signed;
    wire rs1_ge_rs2_unsigned;
    wire rs1_eq_rs2;
    assign rs1_ge_rs2_signed = $signed(rs1_data_i) >= $signed(rs2_data_i);
    assign rs1_ge_rs2_unsigned = rs1_data_i >= rs2_data_i;
    assign rs1_eq_rs2 = (rs1_data_i == rs2_data_i);

    wire rs1_ge_imm_signed;
    wire rs1_ge_imm_unsigned;
    wire rs1_eq_imm;
    assign rs1_ge_imm_signed = $signed(rs1_data_i) >= $signed(imm_i);
    assign rs1_ge_imm_unsigned = rs1_data_i >= imm_i;
    assign rs1_eq_imm = (rs1_data_i == imm_i);
    wire[31:0] sr_shift;
    wire[31:0] sr_shift_mask;
    assign sr_shift = rs1_data_i >> rs2_data_i[4:0];
    assign sr_shift_mask = 32'hffffffff >> rs2_data_i[4:0];
    wire[31:0] sri_shift;
    wire[31:0] sri_shift_mask;
    assign sri_shift = rs1_data_i >> imm_i;
    assign sri_shift_mask = 32'hffffffff >> imm_i;


    always @ (*) begin
        if(n_rst_i == `RstEnable) begin
            mem_addr_o = `ZeroWord;
            mem_wdata_o = `ZeroWord;
        end
        else begin
            case (uopcode_i)
                `UOP_CODE_LB, `UOP_CODE_LBU, `UOP_CODE_LH, `UOP_CODE_LHU, `UOP_CODE_LW:  begin
                    mem_addr_o = rs1_add_imm;
                end
                `UOP_CODE_SB, `UOP_CODE_SH, `UOP_CODE_SW:  begin
                    mem_addr_o = rs1_add_imm;
                    mem_wdata_o = rs2_data_i;
                end
                default: begin
                end
            endcase
        end
    end

    reg[`RegBus] jump_result;
    reg[`RegBus] logic_result;
    reg[`RegBus] shift_result;
    reg[`RegBus] arithmetic_result;
    reg[`RegBus] mul_result;
    reg[`RegBus] div_result;
    reg[`RegBus] csr_result;
    wire read_csr_enable;
    assign read_csr_enable = (uopcode_i == `UOP_CODE_CSRRW) || (uopcode_i == `UOP_CODE_CSRRWI) || (uopcode_i == `UOP_CODE_CSRRS)
           || (uopcode_i == `UOP_CODE_CSRRSI) || (uopcode_i == `UOP_CODE_CSRRC) || (uopcode_i == `UOP_CODE_CSRRCI);
		   
    always @ (*) begin
        csr_result = `ZeroWord;
        csr_raddr_o = `ZeroWord;
        if (read_csr_enable) begin
            csr_raddr_o = csr_addr_i;
            csr_result = csr_rdata_i;
            if( mem_csr_we_i == `WriteEnable && mem_csr_waddr_i == csr_addr_i) begin
                csr_result = mem_csr_wdata_i;
            end
            else if( wb_csr_we_i == `WriteEnable && wb_csr_waddr_i == csr_addr_i) begin
                csr_result = wb_csr_wdata_i;
            end
        end
    end

    always @ (*) begin
        if(n_rst_i == `RstEnable) begin
            csr_waddr_o = `ZeroWord;
            csr_wdata_o = `ZeroWord;
        end
        else begin
            csr_wdata_o = `ZeroWord;
            case (uopcode_i)
                `UOP_CODE_CSRRW: begin
                    csr_wdata_o = rs1_data_i;
                end
                `UOP_CODE_CSRRWI: begin
                    csr_wdata_o = imm_i;
                end
                `UOP_CODE_CSRRS: begin
                    csr_wdata_o = rs1_data_i | csr_result;
                end
                `UOP_CODE_CSRRSI: begin
                    csr_wdata_o = imm_i | csr_result;
                end
                `UOP_CODE_CSRRC: begin
                    csr_wdata_o = csr_result & (~rs1_data_i);
                end
                `UOP_CODE_CSRRCI: begin
                    csr_wdata_o = csr_result & (~imm_i);
                end
                default: begin
                end
            endcase
        end
    end

    always @ (*) begin
        if(n_rst_i == `RstEnable) begin
            jump_result = `ZeroWord;
            branch_request_o = 1'b0;
            branch_is_taken_o = 1'b0;
            branch_is_call_o = 1'b0;
            branch_is_ret_o = 1'b0;
            branch_is_jmp_o = 1'b0;
            branch_target_o = `ZeroWord;
            branch_redirect_o = 1'b0;
            branch_redirect_pc_o = `ZeroWord;
            ;
            branch_tag_o = 1'b0;

        end
        else begin
            jump_result = `ZeroWord;

            branch_request_o = 1'b0;
            branch_is_taken_o = 1'b0;
            branch_is_call_o = 1'b0;
            branch_is_ret_o = 1'b0;
            branch_is_jmp_o = 1'b0;
            branch_target_o = `ZeroWord;
            branch_redirect_o = 1'b0;
            branch_redirect_pc_o = `ZeroWord;
            ;
            branch_tag_o = 1'b0;
            case (uopcode_i)
                `UOP_CODE_JAL: begin
                    jump_result = pc_plus_4;  //save to rd
                    branch_target_o = pc_add_imm;
                    branch_is_taken_o = 1'b1;
                    if( (rd_addr_i == 5'b00001) || (rd_addr_i == 5'b00101) ) begin
                        branch_is_call_o = 1'b1;
                    end
                    else begin
                        branch_is_jmp_o = 1'b1;
                    end
                end
                `UOP_CODE_JALR: begin
                    jump_result = pc_plus_4;
                    branch_target_o = rs1_data_i + imm_i;
                    branch_is_taken_o = 1'b1;

                    /* JALR instructions should push/pop a RAS as shown in the Table
                    ------------------------------------------------
                       rd    |   rs1    | rs1=rd  |   RAS action
                    (1) !link |   !link  | -       |   none
                    (2) !link |   link   | -       |   pop
                    (3) link  |   !link  | -       |   push
                    (4) link  |   link   | 0       |   push and pop
                    (5) link  |   link   | 1       |   push
                    ------------------------------------------------ */
                    if(rd_addr_i == 5'b00001 || rd_addr_i == 5'b00101) begin
                        if(rs1 == 5'b00001 || rs1 == 5'b00101) begin
                            if(rd_addr_i == rs1) begin
                                branch_is_call_o = 1'b1;
                            end
                            else begin
                                branch_is_call_o = 1'b1;
                                branch_is_ret_o = 1'b1;
                            end
                        end
                        else begin
                            branch_is_call_o = 1'b1;
                        end
                    end
                    else begin
                        if(rs1 == 5'b00001 || rs1 == 5'b00101) begin
                            branch_is_ret_o = 1'b1;
                        end
                        else begin
                            branch_is_jmp_o = 1'b1;
                        end
                    end
                end
                `UOP_CODE_BEQ: begin
                    branch_target_o = pc_add_imm;
                    branch_is_taken_o = rs1_eq_rs2;
                end
                `UOP_CODE_BNE: begin
                    branch_target_o = pc_add_imm;
                    branch_is_taken_o = (~rs1_eq_rs2);
                end
                `UOP_CODE_BGE: begin
                    branch_target_o = pc_add_imm;
                    branch_is_taken_o = (rs1_ge_rs2_signed);
                end
                `UOP_CODE_BGEU: begin
                    branch_target_o = pc_add_imm;
                    branch_is_taken_o = (rs1_ge_rs2_unsigned);
                end
                `UOP_CODE_BLT: begin
                    branch_target_o = pc_add_imm;
                    branch_is_taken_o = (~rs1_ge_rs2_signed);
                end
                `UOP_CODE_BLTU: begin
                    branch_target_o = pc_add_imm;
                    branch_is_taken_o =  (~rs1_ge_rs2_unsigned);
                end
                default: begin
                end
            endcase

            if( (uopcode_i == `UOP_CODE_JAL) || (uopcode_i == `UOP_CODE_JALR) || (uopcode_i == `UOP_CODE_BEQ) || (uopcode_i == `UOP_CODE_BNE) ||
                    (uopcode_i == `UOP_CODE_BGE) || (uopcode_i == `UOP_CODE_BGEU) || (uopcode_i == `UOP_CODE_BLT) || (uopcode_i == `UOP_CODE_BLTU) ) begin
                branch_request_o = 1'b1;
                if(branch_is_taken_o == 1'b1) begin
                    if( (next_branch_i == 1'b0) || (next_pc_i != branch_target_o) ) begin
                        branch_redirect_o = `Branch;
                        branch_redirect_pc_o = branch_target_o;
                        branch_tag_o = branch_redirect_o;
                        $display("miss predicted, pc=%h, next_take=%d, branch_taken=%d, next_pc=%h, branch_target=%h is_call=%d, is_ret=%d, is_jmp=%d",
                                 pc_i, next_branch_i, branch_is_taken_o, next_pc_i, branch_target_o, branch_is_call_o, branch_is_ret_o, branch_is_jmp_o);
                    end
                end
                else begin
                    if( next_branch_i == 1'b1 ) begin
                        branch_redirect_o = `Branch;
                        branch_redirect_pc_o = pc_i+4;
                        branch_tag_o = branch_redirect_o;
                        $display("miss predicted, pc=%h, branch_taken=%d, next_take=%d, next_pc=%h", pc_i, branch_is_taken_o, next_branch_i, next_pc_i);
                    end
                end
            end
        end
    end

    always @ (*) begin
        if(n_rst_i == `RstEnable) begin
            logic_result = `ZeroWord;
        end
        else begin
            logic_result = `ZeroWord;
            case (uopcode_i)
                `UOP_CODE_LUI:  begin
                    logic_result = imm_i;
                end
                `UOP_CODE_AUIPC:  begin
                    logic_result = pc_add_imm;
                end
                `UOP_CODE_SLTI: begin
                    logic_result = {32{(~rs1_ge_imm_signed)}} & 32'h1;
                end
                `UOP_CODE_SLTIU: begin
                    logic_result = {32{(~rs1_ge_imm_unsigned)}} & 32'h1;
                end
                `UOP_CODE_ANDI: begin
                    logic_result = rs1_and_imm;
                end
                `UOP_CODE_ORI: begin
                    logic_result = rs1_or_imm;
                end
                `UOP_CODE_XORI: begin
                    logic_result = rs1_xor_imm;
                end
                `UOP_CODE_AND: begin
                    logic_result =  rs1_and_rs2;
                end
                `UOP_CODE_OR: begin
                    logic_result =  rs1_or_rs2;
                end
                `UOP_CODE_XOR: begin
                    logic_result =  rs1_xor_rs2;
                end
                `UOP_CODE_SLT: begin
                    logic_result = {32{(~rs1_ge_rs2_signed)}} & 32'h1;
                end
                `UOP_CODE_SLTU: begin
                    logic_result = {32{(~rs1_ge_rs2_unsigned)}} & 32'h1;
                end
                default: begin
                end
            endcase
        end
    end

    always @ (*) begin
        if(n_rst_i == `RstEnable) begin
            shift_result = `ZeroWord;
        end
        else begin
            shift_result = `ZeroWord;
            case (uopcode_i)
                `UOP_CODE_SLLI: begin
                    shift_result = rs1_data_i << imm_i;
                end
                `UOP_CODE_SRLI: begin
                    shift_result = rs1_data_i >> imm_i;
                end
                `UOP_CODE_SRAI: begin
                    shift_result = (sri_shift & sri_shift_mask) | ({32{rs1_data_i[31]}} & (~sri_shift_mask));
                end
                `UOP_CODE_SLL: begin
                    shift_result =  rs1_data_i << rs2_data_i[4:0];
                end
                `UOP_CODE_SRL: begin
                    shift_result =  rs1_data_i >> rs2_data_i[4:0];
                end
                `UOP_CODE_SRA: begin
                    shift_result =  (sr_shift & sr_shift_mask) | ({32{rs1_data_i[31]}} & (~sr_shift_mask));
                end
                default: begin
                end
            endcase
        end
    end

    always @ (*) begin
        if(n_rst_i == `RstEnable) begin
            arithmetic_result = `ZeroWord;
        end
        else begin
            arithmetic_result = `ZeroWord;
            case (uopcode_i)
                `UOP_CODE_ADDI: begin
                    arithmetic_result = rs1_add_imm;
                end

                `UOP_CODE_ADD: begin
                    arithmetic_result = rs1_add_rs2;
                end

                `UOP_CODE_SUB: begin
                    arithmetic_result = rs1_sub_rs2;
                end

                default: begin
                end
            endcase
        end
    end

    reg[`RegBus] mul_op1;
    reg[`RegBus] mul_op2;
    wire[`DoubleRegBus] mul_temp;
    wire[`DoubleRegBus] mul_temp_invert;
    assign mul_temp = mul_op1 * mul_op2;
    assign mul_temp_invert = ~mul_temp + 1;
    reg[`RegBus] rs1_data_invert;
    reg[`RegBus] rs2_data_invert;
    assign rs1_data_invert = ~rs1_data_i + 1;
    assign rs2_data_invert = ~rs2_data_i + 1;
	
    always @ (*) begin
        case (uopcode_i)
            `UOP_CODE_MULT, `UOP_CODE_MULHU: begin
                mul_op1 = rs1_data_i;
                mul_op2 = rs2_data_i;
            end
            `UOP_CODE_MULHSU: begin
                mul_op1 = (rs1_data_i[31] == 1'b1)? (rs1_data_invert): rs1_data_i;
                mul_op2 = rs2_data_i;
            end
            `UOP_CODE_MULH: begin
                mul_op1 = (rs1_data_i[31] == 1'b1)? (rs1_data_invert): rs1_data_i;
                mul_op2 = (rs2_data_i[31] == 1'b1)? (rs2_data_invert): rs2_data_i;
            end
            default: begin
                mul_op1 = rs1_data_i;
                mul_op2 = rs2_data_i;
            end
        endcase
    end


    always @ (*) begin
        if(n_rst_i == `RstEnable) begin
            mul_result = `ZeroWord;
        end
        else begin
            mul_result = `ZeroWord;
            case (uopcode_i)
                `UOP_CODE_MULT: begin
                    mul_result = mul_temp[31:0];
                end

                `UOP_CODE_MULHU: begin
                    mul_result = mul_temp[63:32];
                end

                `UOP_CODE_MULH: begin
                    case ({rs1_data_i[31], rs2_data_i[31]})
                        2'b00: begin
                            mul_result = mul_temp[63:32];
                        end
                        2'b11: begin
                            mul_result = mul_temp[63:32];
                        end
                        2'b10: begin
                            mul_result = mul_temp_invert[63:32];
                        end
                        default: begin
                            mul_result = mul_temp_invert[63:32];
                        end
                    endcase
                end

                `UOP_CODE_MULHSU: begin
                    if (rs1_data_i[31] == 1'b1) begin
                        mul_result = mul_temp_invert[63:32];
                    end
                    else begin
                        mul_result = mul_temp[63:32];
                    end
                end
                default: begin
                end
            endcase
        end
    end

    always @ (*) begin
        stall_req_o = stallreq_for_div;
    end

    always @ (*) begin
        if(n_rst_i == `RstEnable) begin
            stallreq_for_div = `NoStop;
            dividend_o = `ZeroWord;
            divisor_o = `ZeroWord;
            div_start_o = `DivStop;
            div_signed_o = 1'b0;
        end
        else begin
            stallreq_for_div = `NoStop;
            dividend_o = `ZeroWord;
            divisor_o = `ZeroWord;
            div_start_o = `DivStop;
            div_signed_o = 1'b0;
            case (uopcode_i)
                `UOP_CODE_DIV: begin
                    if(div_ready_i == `DivResultNotReady) begin
                        dividend_o = rs1_data_i;
                        divisor_o = rs2_data_i;
                        div_start_o = `DivStart;
                        div_signed_o = 1'b1;
                        stallreq_for_div = `Stop;
                    end
                    else begin
                        dividend_o = rs1_data_i;
                        divisor_o = rs2_data_i;
                        div_start_o = `DivStop;
                        div_signed_o = 1'b1;
                        stallreq_for_div = `NoStop;
                        div_result = div_result_i[31:0];
                    end
                end

                `UOP_CODE_DIVU: begin
                    if(div_ready_i == `DivResultNotReady) begin
                        dividend_o = rs1_data_i;
                        divisor_o = rs2_data_i;
                        div_start_o = `DivStart;
                        div_signed_o = 1'b0;
                        stallreq_for_div = `Stop;
                    end
                    else begin
                        dividend_o = rs1_data_i;
                        divisor_o = rs2_data_i;
                        div_start_o = `DivStop;
                        div_signed_o = 1'b0;
                        stallreq_for_div = `NoStop;
                        div_result = div_result_i[31:0];
                    end
                end

                `UOP_CODE_REM: begin
                    if(div_ready_i == `DivResultNotReady) begin
                        dividend_o = rs1_data_i;
                        divisor_o = rs2_data_i;
                        div_start_o = `DivStart;
                        div_signed_o = 1'b1;
                        stallreq_for_div = `Stop;
                    end
                    else begin
                        dividend_o = rs1_data_i;
                        divisor_o = rs2_data_i;
                        div_start_o = `DivStop;
                        div_signed_o = 1'b1;
                        stallreq_for_div = `NoStop;
                        div_result = div_result_i[63:32];
                    end
                end

                `UOP_CODE_REMU: begin
                    if(div_ready_i == `DivResultNotReady) begin
                        dividend_o = rs1_data_i;
                        divisor_o = rs2_data_i;
                        div_start_o = `DivStart;
                        div_signed_o = 1'b0;
                        stallreq_for_div = `Stop;
                    end
                    else begin
                        dividend_o = rs1_data_i;
                        divisor_o = rs2_data_i;
                        div_start_o = `DivStop;
                        div_signed_o = 1'b0;
                        stallreq_for_div = `NoStop;
                        div_result = div_result_i[63:32];
                    end
                end

                default: begin
                end
            endcase
        end
    end


    always @ (*) begin
        rd_addr_o = rd_addr_i;
        case ( alusel_i )
            `EXE_TYPE_BRANCH:  begin
                rd_wdata_o = jump_result;
            end
            `EXE_TYPE_LOGIC: begin
                rd_wdata_o = logic_result;
            end
            `EXE_TYPE_SHIFT: begin
                rd_wdata_o = shift_result;
            end
            `EXE_TYPE_ARITHMETIC: begin
                rd_wdata_o = arithmetic_result;
            end
            `EXE_TYPE_MUL:  begin
                rd_wdata_o = mul_result;
            end
            `EXE_TYPE_DIV: begin
                rd_wdata_o = div_result;
            end
            `EXE_TYPE_CSR: begin
                rd_wdata_o = csr_result;
            end
            default: begin
                rd_wdata_o = `ZeroWord;
            end
        endcase
    end

endmodule
