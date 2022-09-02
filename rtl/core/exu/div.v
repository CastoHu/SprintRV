`include "defines.v"

module div(

        input wire                    clk_i,
        input wire                    n_rst_i,
        /* ------- signals from the exe unit --------*/
        input wire                    div_signed_i,
        input wire[31:0]              dividend_i,
        input wire[31:0]              divisor_i,
        input wire                    start_i,
        input wire                    annul_i,
        /* ------- signals to the exe unit --------*/
        output reg[63:0]              result_o,
        output reg                    ready_o
    );

    wire[32:0] div_temp;
    reg[5:0]   cnt;
    reg[64:0] dividend;
    reg[1:0]  state;
    reg[31:0] divisor;
    reg[31:0] temp_op1;
    reg[31:0] temp_op2;
    assign div_temp = {1'b0,dividend[63:32]} - {1'b0,divisor};
    always @ (posedge clk_i) begin
        if (n_rst_i == `RstEnable) begin
            state <= `DivFree;
            ready_o <= `DivResultNotReady;
            result_o <= {`ZeroWord,`ZeroWord};
        end
        else begin
            case (state)
                `DivFree: begin
                    if(start_i == `DivStart && annul_i == 1'b0) begin
                        if(divisor_i == `ZeroWord) begin
                            state <= `DivByZero;
                        end
                        else begin
                            state <= `DivOn;
                            cnt <= 6'b000000;
                            if(div_signed_i == 1'b1 && dividend_i[31] == 1'b1 ) begin
                                temp_op1 = ~dividend_i + 1;
                            end
                            else begin
                                temp_op1 = dividend_i;
                            end
                            if(div_signed_i == 1'b1 && divisor_i[31] == 1'b1 ) begin
                                temp_op2 = ~divisor_i + 1;
                            end
                            else begin
                                temp_op2 = divisor_i;
                            end
                            dividend <= {1'b0, `ZeroWord,`ZeroWord};
                            dividend[32:1] <= temp_op1;
                            divisor <= temp_op2;
                        end
                    end
                    else begin
                        ready_o <= `DivResultNotReady;
                        result_o <= {`ZeroWord,`ZeroWord};
                    end
                end

                `DivByZero: begin
                    // need to update the csr?
                    dividend <= {dividend_i, 1'b0, 32'hffffffff};
                    state <= `DivEnd;
                end

                `DivOn: begin
                    if(annul_i == 1'b0) begin
                        if(cnt != 6'b100000) begin
                            if(div_temp[32] == 1'b1) begin
                                dividend <= {dividend[63:0] , 1'b0};
                            end
                            else begin
                                dividend <= {div_temp[31:0] , dividend[31:0] , 1'b1};
                            end
                            cnt <= cnt + 1;
                        end
                        else begin
                            if((div_signed_i == 1'b1) && ((dividend_i[31] ^ divisor_i[31]) == 1'b1)) begin
                                dividend[31:0] <= (~dividend[31:0] + 1);
                            end
                            if((div_signed_i == 1'b1) && ((dividend_i[31] ^ dividend[64]) == 1'b1)) begin
                                dividend[64:33] <= (~dividend[64:33] + 1);
                            end
                            state <= `DivEnd;
                            cnt <= 6'b000000;
                        end
                    end
                    else begin
                        state <= `DivFree;
                    end
                end

                `DivEnd: begin
                    result_o <= {dividend[64:33], dividend[31:0]};
                    ready_o <= `DivResultReady;
                    if(start_i == `DivStop) begin
                        state <= `DivFree;
                        ready_o <= `DivResultNotReady;
                        result_o <= {`ZeroWord,`ZeroWord};
                    end
                end
            endcase
        end 
    end
endmodule
