`include "defines.v"

module regfile(

        input wire                    clk_i,
        input wire                    n_rst_i,
        /*---------------- write port-----------*/
        input wire                    rd_we_i,
        input wire[`RegAddrBus]       rd_addr_i,
        input wire[`RegBus]           rd_wdata_i,
        /*---------------- read port1 -----------*/
        input wire                    rs1_re_i,
        input wire[`RegAddrBus]       rs1_raddr_i,
        output reg[`RegBus]           rs1_rdata_o,
        /*---------------- read port2 -----------*/
        input wire                    rs2_re_i,
        input wire[`RegAddrBus]       rs2_raddr_i,
        output reg[`RegBus]           rs2_rdata_o

    );

    reg[`RegBus]  regs[0:`RegNum-1];

    always @ (posedge clk_i) begin
        if (n_rst_i == `RstDisable) begin
            if((rd_we_i == `WriteEnable) && (rd_addr_i != `RegNumLog2'h0)) begin
                regs[rd_addr_i] <= rd_wdata_i;
            end

            /*used for ISA test */
            /*
            if(regs[26] == 32'b1 && regs[27] == 32'b1) begin
                $display("test passed!");
                $finish();
            end
            */
        end
    end

    always @ (*) begin
        if(n_rst_i == `RstEnable) begin
            rs1_rdata_o = `ZeroWord;
        end
        else if(rs1_raddr_i == `RegNumLog2'h0) begin
            rs1_rdata_o = `ZeroWord;
        end
        else if((rs1_raddr_i == rd_addr_i) && (rd_we_i == `WriteEnable) && (rs1_re_i == `ReadEnable)) begin
            rs1_rdata_o = rd_wdata_i;
        end
        else if(rs1_re_i == `ReadEnable) begin
            rs1_rdata_o = regs[rs1_raddr_i];
        end
        else begin
            rs1_rdata_o = `ZeroWord;
        end
    end

    always @ (*) begin
        if(n_rst_i == `RstEnable) begin
            rs2_rdata_o = `ZeroWord;
        end
        else if(rs2_raddr_i == `RegNumLog2'h0) begin
            rs2_rdata_o = `ZeroWord;
        end
        else if((rs2_raddr_i == rd_addr_i) && (rd_we_i == `WriteEnable) && (rs2_re_i == `ReadEnable)) begin
            rs2_rdata_o = rd_wdata_i;
        end
        else if(rs2_re_i == `ReadEnable) begin
            rs2_rdata_o = regs[rs2_raddr_i];
        end
        else begin
            rs2_rdata_o = `ZeroWord;
        end
    end
endmodule
