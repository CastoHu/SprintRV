`include "defines.v"

module id(

        input wire                    n_rst_i,
        /* ------- signals from the if_id unit --------*/
        input wire[`InstAddrBus]      pc_i,
        input wire[`InstBus]          inst_i,
        input wire                    branch_slot_end_i,
        input wire[`RegBus]           next_pc_i,
        input wire                    next_branch_i,

        
        output reg                    rs1_re_o,
        output reg                    rs2_re_o,
        output reg[`RegAddrBus]       rs1_raddr_o,
        output reg[`RegAddrBus]       rs2_raddr_o,
        input wire[`RegBus]           rs1_rdata_i,
        input wire[`RegBus]           rs2_rdata_i,

        /* ---------signals from exu -----------------*/
        input wire                    branch_redirect_i,
        input wire[`AluOpBus]         ex_uopcode_i,
        input wire                    ex_rd_we_i,
        input wire[`RegAddrBus]       ex_rd_waddr_i,
        input wire[`RegBus]           ex_rd_wdata_i,

        /* ------- signals forwarded from the lsu unit --------*/
        input wire                    mem_rd_we_i,
        input wire[`RegAddrBus]       mem_rd_waddr_i,
        input wire[`RegBus]           mem_rd_wdata_i,

        /* ------- signals to the ctrl  ---------------*/
        output wire                   stall_req_o,

        /* ------- signals to the execution unit --------*/
        output reg[`RegBus]           pc_o,
        output reg[`RegBus]           inst_o,
        output reg[`RegBus]           next_pc_o,
        output reg                    next_branch_o,
        output reg                    branch_slot_end_o,
        output reg[`RegBus]           imm_o,
        output reg                    csr_we_o,
        output reg[`RegBus]           csr_addr_o,
        output reg[`RegBus]           rs1_data_o,
        output reg[`RegBus]           rs2_data_o,
        output reg                    rd_we_o,
        output reg[`RegAddrBus]       rd_waddr_o,
        output reg[`AluSelBus]        alusel_o,
        output reg[`AluOpBus]         uopcode_o,
        output wire[31:0]             exception_o
    );

    wire[6:0]     opcode = inst_i[6:0];
    wire[4:0]     rd = inst_i[11:7];
    wire[2:0]     funct3 = inst_i[14:12];
    wire[4:0]     rs1 = inst_i[19:15];
    wire[4:0]     rs2 = inst_i[24:20];
    wire[6:0]     funct7 = inst_i[31:25];
    reg[`RegBus]  imm;
    reg           csr_we;
    reg[`RegBus]  csr_addr;
    reg           instvalid;
    reg           rs1_load_depend;
    reg           rs2_load_depend;
    wire          pre_inst_is_load;
    reg           excepttype_mret;
    reg           excepttype_ecall;
    reg           excepttype_ebreak;
    reg           excepttype_illegal_inst;

    assign stall_req_o = rs1_load_depend | rs2_load_depend;
    assign pre_inst_is_load = ( (ex_uopcode_i == `UOP_CODE_LB) || (ex_uopcode_i == `UOP_CODE_LBU)
                                ||(ex_uopcode_i == `UOP_CODE_LH) || (ex_uopcode_i == `UOP_CODE_LHU)
                                ||(ex_uopcode_i == `UOP_CODE_LW) ) ? `True_v : `False_v;
    assign pc_o = pc_i;
    assign imm_o = imm;
    assign next_pc_o = next_pc_i;
    assign next_branch_o = next_branch_i;
    assign branch_slot_end_o = branch_slot_end_i;
    assign csr_we_o = csr_we;
    assign csr_addr_o = csr_addr;

    always @ (*) begin
        rs1_raddr_o = rs1;
        rs2_raddr_o = rs2;
    end

    assign exception_o = {28'b0, excepttype_illegal_inst, excepttype_ebreak, excepttype_ecall, excepttype_mret};

    always @ (*) begin
        if (n_rst_i == `RstEnable) begin
            inst_o = `NOP_INST;
            rs1_re_o = 1'b0;
            rs2_re_o = 1'b0;
            rs1_raddr_o = `NOPRegAddr;
            rs2_raddr_o = `NOPRegAddr;
            imm = `ZeroWord;
            csr_we = `WriteDisable;
            csr_addr = `ZeroWord;
            rs1_data_o = `ZeroWord;
            rs2_data_o = `ZeroWord;
            rd_we_o = `WriteDisable;
            rd_waddr_o = `NOPRegAddr;
            alusel_o = `EXE_TYPE_NOP;
            uopcode_o = `UOP_CODE_NOP;
            excepttype_ecall = `False_v;
            excepttype_mret = `False_v;
            excepttype_ebreak = `False_v;
            excepttype_illegal_inst = `False_v;
            instvalid = `InstValid;
        end
        else if (branch_redirect_i) begin
            inst_o = `NOP_INST;
            rs1_re_o = 1'b0;
            rs2_re_o = 1'b0;
            imm = `ZeroWord;
            csr_we = `WriteDisable;
            csr_addr = `ZeroWord;
            rs1_data_o = `ZeroWord;
            rs2_data_o = `ZeroWord;
            rd_we_o = `WriteDisable;
            rd_waddr_o = `NOPRegAddr;
            alusel_o = `EXE_TYPE_NOP;
            uopcode_o = `UOP_CODE_NOP;
            excepttype_ecall = `False_v;
            excepttype_mret = `False_v;
            excepttype_ebreak = `False_v;
            excepttype_illegal_inst = `False_v;
            instvalid = `InstValid;
        end
        else begin
            inst_o = inst_i;
            rs1_re_o = 1'b0;
            rs2_re_o = 1'b0;
            imm = `ZeroWord;
            csr_we = `WriteDisable;
            csr_addr = `ZeroWord;
            rs1_data_o = `ZeroWord;
            rs2_data_o = `ZeroWord;
            rd_we_o = `WriteDisable;
            rd_waddr_o = `NOPRegAddr;
            alusel_o = `EXE_TYPE_NOP;
            uopcode_o = `UOP_CODE_NOP;
            excepttype_ecall = `False_v;
            excepttype_mret = `False_v;
            excepttype_ebreak = `False_v;
            excepttype_illegal_inst = `False_v;
            instvalid = `InstInvalid;
            case (opcode)
                `INST_OPCODE_LUI: begin  //7'b0110111
                    // imm:[31:12], rd:[11:7], opcode[6:0] = 0110111
                    imm = {inst_i[31:12], 12'b0};
                    rd_we_o = `WriteEnable;
                    rd_waddr_o = rd;
                    alusel_o = `EXE_TYPE_LOGIC;
                    uopcode_o = `UOP_CODE_LUI;
                    instvalid = `InstValid;
                end

                `INST_OPCODE_AUIPC: begin  //7'b0010111
                    // imm:[31:12], rd:[11:7], opcode[6:0] = 0010111
                    imm = {inst_i[31:12], 12'b0};
                    rd_we_o = `WriteEnable;
                    rd_waddr_o = rd;
                    alusel_o = `EXE_TYPE_LOGIC;
                    uopcode_o = `UOP_CODE_AUIPC;
                    instvalid = `InstValid;
                end

                `INST_OPCODE_JAL: begin
                    // imm(20, 10:1, 11, 19:12):[31:12], rd:[11:7], opcode[6:0] = 1101111
                    imm = {{12{inst_i[31]}}, inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0};
                    rd_we_o = `WriteEnable;
                    rd_waddr_o = rd;
                    alusel_o = `EXE_TYPE_BRANCH;
                    uopcode_o = `UOP_CODE_JAL;
                    instvalid = `InstValid;
                end

                `INST_OPCODE_JALR: begin // 7'b1100111
                    // imm:[31:20], rs1:[19:15], funct3 =000, rd:[11:7], opcode[6:0]=1100111
                    imm = {{20{inst_i[31]}}, inst_i[31:20]};
                    rs1_re_o = 1'b1;
                    rd_we_o = `WriteEnable;
                    rd_waddr_o = rd;
                    alusel_o = `EXE_TYPE_BRANCH;
                    uopcode_o = `UOP_CODE_JALR;
                    instvalid = `InstValid;
                end

                `INST_OPCODE_BRANCH: begin  //1100011
                    // imm(12,10:5):[31:25], rs2:[24:20], rs1:[19:15], funct3:[14:12], imm(4:1,11):[11:7], opcode[6:0]
                    imm = {{20{inst_i[31]}}, inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
                    rs1_re_o = 1'b1;
                    rs2_re_o = 1'b1;
                    alusel_o = `EXE_TYPE_BRANCH;
                    instvalid = `InstValid;

                    case (funct3)
                        `INST_BEQ: begin
                            uopcode_o = `UOP_CODE_BEQ;
                        end
                        `INST_BNE: begin
                            uopcode_o = `UOP_CODE_BNE;
                        end
                        `INST_BGE: begin
                            uopcode_o = `UOP_CODE_BGE;
                        end
                        `INST_BGEU: begin
                            uopcode_o = `UOP_CODE_BGEU;
                        end
                        `INST_BLT: begin
                            uopcode_o = `UOP_CODE_BLT;
                        end
                        `INST_BLTU: begin
                            uopcode_o = `UOP_CODE_BLTU;
                        end

                        default: begin
                            $display("invalid funct3 in branch type, pc=%h, inst=%h, funct3=%d", pc_i, inst_i, funct3);
                            instvalid = `InstInvalid;
                        end
                    endcase
                end

                `INST_OPCODE_LOAD: begin  //0000011
                    // imm:[31:20], rs1:[19:15], funct3:[14:12], rd:[11:7], opcode[6:0]
                    imm = {{20{inst_i[31]}}, inst_i[31:20]};
                    rs1_re_o = 1'b1;
                    rd_we_o = `WriteEnable;
                    rd_waddr_o = rd;
                    alusel_o = `EXE_TYPE_LOAD_STORE;
                    instvalid = `InstValid;
                    case (funct3)
                        `INST_LB: begin
                            uopcode_o = `UOP_CODE_LB;
                        end
                        `INST_LBU: begin
                            uopcode_o = `UOP_CODE_LBU;
                        end
                        `INST_LH: begin
                            uopcode_o = `UOP_CODE_LH;
                        end
                        `INST_LHU: begin
                            uopcode_o = `UOP_CODE_LHU;
                        end
                        `INST_LW: begin
                            uopcode_o = `UOP_CODE_LW;
                        end
                        default: begin
                            $display("invalid funct3 in load type, pc=%h, inst=%h, funct3=%d", pc_i, inst_i, funct3);
                            instvalid = `InstInvalid;
                        end
                    endcase
                end
                `INST_OPCODE_STORE: begin   //0100011
                    //  imm(11:5):[31:25], rs2:[24:20], rs1:[19:15], funct3:[14:12], imm(4:0):[11:7], opcode[6:0]
                    imm = {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]};   //need pass the imm to exu
                    rs1_re_o = 1'b1;
                    rs2_re_o = 1'b1;
                    alusel_o = `EXE_TYPE_LOAD_STORE;
                    instvalid = `InstValid;
                    case (funct3)
                        `INST_SB:  begin
                            uopcode_o = `UOP_CODE_SB;
                        end
                        `INST_SH:  begin
                            uopcode_o = `UOP_CODE_SH;
                        end
                        `INST_SW:  begin
                            uopcode_o = `UOP_CODE_SW;
                        end
                        default: begin
                            $display("invalid funct3 in STORE type, pc=%h, inst=%h, funct3=%d", pc_i, inst_i, funct3);
                            instvalid = `InstInvalid;
                        end
                    endcase
                end
                `INST_OPCODE_IMM: begin
                    // imm:[31:20], rs1:[19:15], funct3:[14:12], rd:[11:7], opcode[6:0]
                    rs1_re_o = 1'b1;
                    rd_we_o = `WriteEnable;
                    rd_waddr_o = rd;
                    instvalid = `InstValid;
                    case (funct3)
                        `INST_ADDI: begin
                            imm = {{20{inst_i[31]}}, inst_i[31:20]};
                            alusel_o = `EXE_TYPE_ARITHMETIC;
                            uopcode_o = `UOP_CODE_ADDI;
                        end
                        `INST_SLTI: begin
                            imm = {{20{inst_i[31]}}, inst_i[31:20]};
                            alusel_o = `EXE_TYPE_LOGIC;
                            uopcode_o = `UOP_CODE_SLTI;
                        end
                        `INST_SLTIU: begin
                            imm = {{20{inst_i[31]}}, inst_i[31:20]};
                            alusel_o = `EXE_TYPE_LOGIC;
                            uopcode_o = `UOP_CODE_SLTIU;
                        end
                        `INST_ANDI: begin
                            imm = {{20{inst_i[31]}}, inst_i[31:20]};
                            alusel_o = `EXE_TYPE_LOGIC;
                            uopcode_o = `UOP_CODE_ANDI;
                        end
                        `INST_ORI: begin
                            imm = {{20{inst_i[31]}}, inst_i[31:20]};
                            alusel_o = `EXE_TYPE_LOGIC;
                            uopcode_o = `UOP_CODE_ORI;
                        end
                        `INST_XORI: begin
                            imm = {{20{inst_i[31]}}, inst_i[31:20]};
                            alusel_o = `EXE_TYPE_LOGIC;
                            uopcode_o = `UOP_CODE_XORI;
                        end
                        `INST_SLLI: begin
                            imm = {27'b0, inst_i[24:20]};
                            alusel_o = `EXE_TYPE_SHIFT;
                            uopcode_o = `UOP_CODE_SLLI;
                        end

                        `INST_SRLI_SRAI: begin
                            imm = {27'b0, inst_i[24:20]};
                            if(funct7[6:1] == 6'b000000) begin
                                alusel_o = `EXE_TYPE_SHIFT;
                                uopcode_o = `UOP_CODE_SRLI;
                            end
                            else if (funct7[6:1] == 6'b010000) begin
                                alusel_o = `EXE_TYPE_SHIFT;
                                uopcode_o = `UOP_CODE_SRAI;
                            end
                            else begin
                                $display("invalid funct7 (%b) for SRI, pc=%h, inst=%h, funct3=%d", funct7[6:1], pc_i, inst_i, funct3);
                                instvalid = `InstInvalid;
                            end
                        end

                        default: begin
                            $display("invalid funct3 in I type, pc=%h, inst=%h, funct3=%d", pc_i, inst_i, funct3);
                            instvalid = `InstInvalid;
                        end
                    endcase
                end

                `INST_OPCODE_REG: begin
                    // funct7:[31:25], rs2:[24:20], rs1:[19:15], funct3[14:12], opcode[6:0]
                    rs1_re_o = 1'b1;
                    rs2_re_o = 1'b1;
                    rd_we_o = `WriteEnable;
                    rd_waddr_o = rd;
                    instvalid = `InstValid;
                    if ((funct7 == 7'b0000000) || (funct7 == 7'b0100000)) begin
                        case (funct3)
                            `INST_ADD_SUB: begin
                                if(funct7 == 7'b0000000) begin
                                    alusel_o = `EXE_TYPE_ARITHMETIC;
                                    uopcode_o = `UOP_CODE_ADD;
                                end
                                else begin
                                    alusel_o = `EXE_TYPE_ARITHMETIC;
                                    uopcode_o = `UOP_CODE_SUB;
                                end
                            end
                            `INST_AND: begin
                                alusel_o = `EXE_TYPE_LOGIC;
                                uopcode_o = `UOP_CODE_AND;
                            end
                            `INST_OR: begin
                                alusel_o = `EXE_TYPE_LOGIC;
                                uopcode_o = `UOP_CODE_OR;
                            end
                            `INST_XOR: begin
                                alusel_o = `EXE_TYPE_LOGIC;
                                uopcode_o = `UOP_CODE_XOR;
                            end
                            `INST_SLL: begin
                                alusel_o = `EXE_TYPE_SHIFT;
                                uopcode_o = `UOP_CODE_SLL;
                            end
                            `INST_SRL_SRA: begin
                                if(funct7 == 7'b0000000) begin
                                    alusel_o = `EXE_TYPE_SHIFT;
                                    uopcode_o = `UOP_CODE_SRL;
                                end
                                else begin
                                    alusel_o = `EXE_TYPE_SHIFT;
                                    uopcode_o = `UOP_CODE_SRA;
                                end
                            end
                            `INST_SLT: begin
                                alusel_o = `EXE_TYPE_LOGIC;
                                uopcode_o = `UOP_CODE_SLT;
                            end
                            `INST_SLTU: begin
                                alusel_o = `EXE_TYPE_LOGIC;
                                uopcode_o = `UOP_CODE_SLTU;
                            end
                            default: begin
                                $display("invalid funct3 in R type, pc=%h, inst=%h, funct3=%d", pc_i, inst_i, funct3);
                                instvalid = `InstInvalid;
                            end
                        endcase
                    end
                    else if (funct7 == 7'b0000001) begin
                        case (funct3)
                            `INST_MUL: begin
                                alusel_o = `EXE_TYPE_MUL;
                                uopcode_o = `UOP_CODE_MULT;
                            end
                            `INST_MULH: begin
                                alusel_o = `EXE_TYPE_MUL;
                                uopcode_o = `UOP_CODE_MULH;
                            end
                            `INST_MULHU: begin
                                alusel_o = `EXE_TYPE_MUL;
                                uopcode_o = `UOP_CODE_MULHU;
                            end
                            `INST_MULHSU: begin
                                alusel_o = `EXE_TYPE_MUL;
                                uopcode_o = `UOP_CODE_MULHSU;
                            end
                            `INST_DIV: begin
                                alusel_o = `EXE_TYPE_DIV;
                                uopcode_o = `UOP_CODE_DIV;
                            end
                            `INST_DIVU: begin
                                alusel_o = `EXE_TYPE_DIV;
                                uopcode_o = `UOP_CODE_DIVU;
                            end
                            `INST_REM: begin
                                alusel_o = `EXE_TYPE_DIV;
                                uopcode_o = `UOP_CODE_REM;
                            end
                            `INST_REMU: begin
                                alusel_o = `EXE_TYPE_DIV;
                                uopcode_o = `UOP_CODE_REMU;
                            end
                            default: begin
                                instvalid = `InstValid;
                                $display("invalid funct3 in R type, pc=%h, inst=%h, funct3=%d", pc_i, inst_i, funct3);
                            end
                        endcase
                    end
                    else begin
                        instvalid = `InstInvalid;
                        $display("invalid funct7 in R type, pc=%h, inst=%h, funct3=%d", pc_i, inst_i, funct3);
                    end
                end


                `INST_OPCODE_CSR: begin
                    // csr[31:20], rs1:[19:15], funct3[14:12], opcode[6:0] = 7'b1110011
                    // csr[31:20], uimm[19:15], funct3[14:12], opcode[6:0] = 7'b1110011
                    csr_addr = {20'h0, inst_i[31:20]};
                    imm = {27'b0, inst_i[19:15]};
                    rd_waddr_o = rd;
                    instvalid = `InstValid;
                    case (funct3)
                        `INST_CSRRW: begin
                            rs1_re_o = 1'b1;
                            rd_we_o = `WriteEnable;
                            csr_we = `WriteEnable;
                            alusel_o = `EXE_TYPE_CSR;
                            uopcode_o = `UOP_CODE_CSRRW;
                        end
                        `INST_CSRRWI: begin
                            rd_we_o = `WriteEnable;
                            csr_we = `WriteEnable;
                            alusel_o = `EXE_TYPE_CSR;
                            uopcode_o = `UOP_CODE_CSRRWI;
                        end
                        `INST_CSRRS: begin
                            rs1_re_o = 1'b1;
                            rd_we_o = `WriteEnable;
                            csr_we = `WriteEnable;
                            alusel_o = `EXE_TYPE_CSR;
                            uopcode_o = `UOP_CODE_CSRRS;
                        end
                        `INST_CSRRSI: begin
                            rd_we_o = `WriteEnable;
                            csr_we = `WriteEnable;
                            alusel_o = `EXE_TYPE_CSR;
                            uopcode_o = `UOP_CODE_CSRRSI;
                        end
                        `INST_CSRRC: begin
                            rs1_re_o = 1'b1;
                            rd_we_o = `WriteEnable;
                            csr_we = `WriteEnable;
                            alusel_o = `EXE_TYPE_CSR;
                            uopcode_o = `UOP_CODE_CSRRC;
                        end
                        `INST_CSRRCI: begin
                            rd_we_o = `WriteEnable;
                            csr_we = `WriteEnable;
                            uopcode_o = `UOP_CODE_CSRRCI;
                            alusel_o = `EXE_TYPE_CSR;
                        end
                        `INST_CSR_SPECIAL: begin
                            if((funct7==7'b0000000) &&  (rs2 == 5'b00000))  begin
                                // {00000, 00, rs2(00000), rs1(00000), funct3(000), rd(00000), opcode = 7b'1110011 }
                                alusel_o = `EXE_TYPE_NOP;
                                uopcode_o = `UOP_CODE_ECALL;
                                excepttype_ecall= `True_v;
                            end
                            if( (funct7==7'b0011000) && (rs2 == 5'b00010)) begin
                                // {00110, 00, rs2(00010), rs1(00000), funct3(000), rd(00000), opcode = 7b'1110011 }
                                alusel_o = `EXE_TYPE_NOP;
                                uopcode_o = `UOP_CODE_MRET;
                                excepttype_mret = `True_v;
                            end
                            /*
                             
                                                        if( (funct7==7'b0000000) && (rs2 == 5'b00010) ) begin   //INST_ERET
                                                            // {00000, 00, rs2(00010), rs1(00000), funct3(000), rd(00000), opcode = 7b'1110011 }
                                                            alusel_o = `EXE_TYPE_NOP;
                                                            uopcode_o = `UOP_CODE_ERET;
                                                            excepttype_is_eret = `True_v;
                                                        end
                             
                                                        if((funct7==7'b0000000) && (rs2 == 5'b00001)) begin   //INST_EBREAK:
                                                            // {00000, 00, rs2(00001), rs1(00000), funct3(000), rd(00000), opcode = 7b'1110011 }
                                                            alusel_o = `EXE_TYPE_NOP;
                                                            uopcode_o = `UOP_CODE_EBREAK;
                                                        end
                            */
                            if( (funct7==7'b0000100) && (rs2 == 5'b00010) ) begin   // INST_SRET
                                // {00010, 00, rs2(00010), rs1(00000), funct3(000), rd(00000), opcode = 7b'1110011 }
                            end

                            if( (funct7==7'b0010000) && (rs2 == 5'b00101) ) begin  //INST_WFI
                                // {00100, 00, rs2(00101), rs1(00000), funct3(000), rd(00000), opcode = 7b'1110011 }
                            end

                            if( funct7==7'b0001001) begin  //INST_SFENCE_WMA
                                // {00010, 01, rs2, rs1, funct3(000), rd, opcode = 7b'1110011 }
                            end

                        end
                        default: begin
                            instvalid = `InstValid;
                            $display("invalid funct7 in csr type, pc=%h, inst=%h, funct3=%d", pc_i, inst_i, funct3);
                        end
                    endcase
                end
                `INST_OPCODE_FENCE: begin
                    case (funct3)
                        `INST_FENCE: begin   //funct3 = 000
                            // fm:[32:28]=0000, pred:[27:24], succ[23:20], rs1=00000, funct3=000, rd=00000, opcode=0001111
                        end
                        `INST_FENCE_I: begin   //funct3 = 001
                            // fm:[32:27]=00000, pred:[26:25]=00, succ[24:20]=00000, rs1=00000, funct3=001, rd=00000, opcode=0001111
                        end
                        default: begin

                        end
                    endcase
                end

                default: begin
                    $display("invalid instruction opcode (%h), pc=%d,  the instruction is (%h)", opcode, pc_i, inst_i);
                end
            endcase
        end
    end

    always @ (*) begin
        if(n_rst_i == `RstEnable) begin
            rs1_data_o = `ZeroWord;
            rs1_load_depend = `NoStop;
        end
        else begin
            rs1_data_o = `ZeroWord;
            rs1_load_depend = `NoStop;
            if(rs1_raddr_o == 5'b0) begin
                rs1_data_o = 32'b0;
            end
            else begin
                if(pre_inst_is_load == 1'b1 && ex_rd_waddr_i == rs1_raddr_o && rs1_re_o == 1'b1 ) begin
                    rs1_load_depend = `Stop;
                end
                else begin
                    if((rs1_re_o == 1'b1) && (ex_rd_we_i == 1'b1) && (ex_rd_waddr_i == rs1_raddr_o)) begin
                        rs1_data_o = ex_rd_wdata_i;
                    end
                    else if((rs1_re_o == 1'b1) && (mem_rd_we_i == 1'b1) && (mem_rd_waddr_i == rs1_raddr_o)) begin
                        rs1_data_o = mem_rd_wdata_i;
                    end
                    else if(rs1_re_o == 1'b1) begin
                        rs1_data_o = rs1_rdata_i;
                    end
                end
            end
        end
    end

    always @ (*) begin
        if(n_rst_i == `RstEnable) begin
            rs2_load_depend = `NoStop;
            rs2_data_o = `ZeroWord;
        end
        else begin
            rs2_load_depend = `NoStop;
            rs2_data_o = `ZeroWord;
            if(rs2_raddr_o == 5'b0) begin
                rs2_data_o = 32'b0;
            end
            else begin
                if(pre_inst_is_load == 1'b1 && ex_rd_waddr_i == rs2_raddr_o && rs2_re_o == 1'b1 ) begin
                    rs2_load_depend = `Stop;
                end
                else begin
                    if((rs2_re_o == 1'b1) && (ex_rd_we_i == 1'b1) && (ex_rd_waddr_i == rs2_raddr_o)) begin
                        rs2_data_o = ex_rd_wdata_i;
                    end
                    else if((rs2_re_o == 1'b1) && (mem_rd_we_i == 1'b1) && (mem_rd_waddr_i == rs2_raddr_o)) begin
                        rs2_data_o = mem_rd_wdata_i;
                    end
                    else if(rs2_re_o == 1'b1) begin
                        rs2_data_o = rs2_rdata_i;
                    end
                end
            end
        end
    end
endmodule
