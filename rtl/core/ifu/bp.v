`include "defines.v"

module branch_prediction #( parameter NUM_RAS_ENTRIES  = 8,
                                parameter NUM_BTB_ENTRIES  = 64,
                                parameter NUM_BHT_ENTRIES  = 64)
    (
        input wire                 clk_i,
        input wire                 n_rst_i,
        input wire[`InstAddrBus]   branch_source_i,
        input wire                 branch_request_i,
        input wire                 branch_is_taken_i,
        input wire                 branch_is_call_i,
        input wire                 branch_is_ret_i,
        input wire                 branch_is_jmp_i,
        input wire[`InstAddrBus]   branch_target_i,
        input wire                 branch_mispredict_i,
        input wire[`InstAddrBus]   pc_i,
        input wire                 stall_i,
        output reg[`InstAddrBus]   next_pc_o,
        output reg                 next_branch_o
    );

    localparam BHT_ENTRIES_WIDTH = $clog2(NUM_BHT_ENTRIES);
    localparam BTB_ENTRIES_WIDTH = $clog2(NUM_BTB_ENTRIES);
    localparam RAS_ENTRIES_WIDTH = $clog2(NUM_RAS_ENTRIES);
    reg [1:0] bht_bim_list[NUM_BHT_ENTRIES-1:0];
    wire[BHT_ENTRIES_WIDTH-1:0] bht_write_entry = branch_source_i[2+BHT_ENTRIES_WIDTH-1:2];

    integer i4;
    always @ (posedge clk_i or negedge  n_rst_i) begin
        if (n_rst_i == `RstEnable) begin
            for (i4 = 0; i4 < NUM_BHT_ENTRIES; i4 = i4 + 1) begin
                bht_bim_list[i4] <= 2'b11;
            end
        end
        else begin
            if ( branch_request_i ) begin
                if( (branch_is_taken_i == 1'b1) && (bht_bim_list[bht_write_entry] < 2'd3) ) begin
                    bht_bim_list[bht_write_entry] <= bht_bim_list[bht_write_entry] + 2'd1;
                end
                else if ( (branch_is_taken_i  == 1'b0) && (bht_bim_list[bht_write_entry] > 2'd0) ) begin
                    bht_bim_list[bht_write_entry] <= bht_bim_list[bht_write_entry] - 2'd1;
                end
            end
        end
    end

    wire[BHT_ENTRIES_WIDTH-1:0] bht_read_entry = pc_i[2+BHT_ENTRIES_WIDTH-1:2];
    wire bht_predict_taken = (bht_bim_list[bht_read_entry] >= 2'd2);
    reg                 btb_is_valid_list[NUM_BTB_ENTRIES-1:0];
    reg [`InstAddrBus]  btb_source_pc_list[NUM_BTB_ENTRIES-1:0];
    reg                 btb_is_call_list[NUM_BTB_ENTRIES-1:0];
    reg                 btb_is_ret_list[NUM_BTB_ENTRIES-1:0];
    reg                 btb_is_jmp_list[NUM_BTB_ENTRIES-1:0];
    reg [`InstAddrBus]  btb_target_pc_list[NUM_BTB_ENTRIES-1:0];
    reg                 btb_is_matched;
    reg                 btb_is_call;
    reg                 btb_is_ret;
    reg                 btb_is_jmp;
    reg [`InstAddrBus]  btb_target_pc;
    reg[BTB_ENTRIES_WIDTH-1:0] btb_rd_entry;
    integer i0;

    always @ ( * ) begin
        btb_is_matched = 1'b0;
        btb_is_call = 1'b0;
        btb_is_ret = 1'b0;
        btb_is_jmp = 1'b0;
        btb_target_pc = pc_i + 32'd4;
        btb_rd_entry = {BTB_ENTRIES_WIDTH{1'b0}};

        for (i0 = 0; i0 < NUM_BTB_ENTRIES; i0 = i0 + 1) begin
            if ( btb_source_pc_list[i0] == pc_i && btb_is_valid_list[i0] ) begin
                btb_is_matched   = 1'b1;
                btb_is_call = btb_is_call_list[i0];
                btb_is_ret  = btb_is_ret_list[i0];
                btb_is_jmp  = btb_is_jmp_list[i0];
                btb_target_pc = btb_target_pc_list[i0];
                btb_rd_entry   = i0;
            end 
        end
    end

    wire  ras_call_matched =  (btb_is_matched & btb_is_call);
    wire  ras_ret_matched  =  (btb_is_matched & btb_is_ret);
    reg[BTB_ENTRIES_WIDTH-1:0]  btb_write_entry;
    wire[BTB_ENTRIES_WIDTH-1:0] btb_alloc_entry;
    reg  btb_hit;
    reg  btb_alloc_req;
    integer  i1;
	
    always @ ( * ) begin
        btb_write_entry = {BTB_ENTRIES_WIDTH{1'b0}};
        btb_hit = 1'b0;
        btb_alloc_req  = 1'b0;
        if (branch_request_i && branch_is_taken_i) begin
            for (i1 = 0; i1 < NUM_BTB_ENTRIES; i1 = i1 + 1) begin
                if ( btb_source_pc_list[i1] == branch_source_i && btb_is_valid_list[i1] ) begin
                    btb_hit      = 1'b1;
                    btb_write_entry = i1;
                end 
            end
            btb_alloc_req = ~btb_hit;
        end
    end

    integer i2;
    always @ (posedge clk_i or negedge  n_rst_i) begin
        if (n_rst_i == `RstEnable) begin
            for (i2 = 0; i2 < NUM_BTB_ENTRIES; i2 = i2 + 1) begin
                btb_is_valid_list[i2] <= 1'b0;
                btb_source_pc_list[i2] <= 32'b0;
                btb_target_pc_list[i2] <= 32'b0;
                btb_is_call_list[i2] <= 1'b0;
                btb_is_ret_list[i2] <= 1'b0;
                btb_is_jmp_list[i2] <= 1'b0;
            end
        end
        else begin
            if (branch_request_i && branch_is_taken_i) begin
                if(btb_hit == 1'b1) begin
                    btb_source_pc_list[btb_write_entry] <= branch_source_i;
                    btb_target_pc_list[btb_write_entry] <= branch_target_i;
                    btb_is_call_list[btb_write_entry] <= branch_is_call_i;
                    btb_is_ret_list[btb_write_entry] <= branch_is_ret_i;
                    btb_is_jmp_list[btb_write_entry] <= branch_is_jmp_i;
                end
                else begin
                    btb_is_valid_list[btb_alloc_entry] <= 1'b1;
                    btb_source_pc_list[btb_alloc_entry] <= branch_source_i;
                    btb_target_pc_list[btb_alloc_entry] <= branch_target_i;
                    btb_is_call_list[btb_alloc_entry]<= branch_is_call_i;
                    btb_is_ret_list[btb_alloc_entry] <= branch_is_ret_i;
                    btb_is_jmp_list[btb_alloc_entry] <= branch_is_jmp_i;
                end
            end
        end
    end

    reg[31:0] ras_list[NUM_RAS_ENTRIES-1:0];
    reg [RAS_ENTRIES_WIDTH-1:0] ras_proven_curr_index;
    reg [RAS_ENTRIES_WIDTH-1:0] ras_proven_next_index;

    always @ ( * ) begin
        ras_proven_next_index = ras_proven_curr_index;
        if (branch_request_i & branch_is_call_i)
            ras_proven_next_index = ras_proven_curr_index + 1;
        else if (branch_request_i & branch_is_ret_i)
            ras_proven_next_index = ras_proven_curr_index - 1;
    end

    always @ (posedge clk_i) begin
        if (n_rst_i == `RstEnable)
            ras_proven_curr_index <= {RAS_ENTRIES_WIDTH{1'b0}};
        else
            ras_proven_curr_index <= ras_proven_next_index;
    end


    reg[RAS_ENTRIES_WIDTH-1:0] ras_speculative_curr_index;
    reg[RAS_ENTRIES_WIDTH-1:0] ras_speculative_next_index;
    wire [31:0] ras_pred_pc = ras_list[ras_speculative_curr_index];

    always @ ( * ) begin
        ras_speculative_next_index = ras_speculative_curr_index;
        if (branch_mispredict_i & branch_request_i & branch_is_call_i) begin
            ras_speculative_next_index = ras_proven_curr_index + 1;
        end
        else if (branch_mispredict_i & branch_request_i & branch_is_ret_i) begin
            ras_speculative_next_index = ras_proven_curr_index - 1;
        end
        else if (ras_call_matched && stall_i == 1'b0) begin
            ras_speculative_next_index = ras_speculative_curr_index + 1;
        end
        else if (ras_ret_matched && stall_i == 1'b0) begin
            ras_speculative_next_index = ras_speculative_curr_index - 1;
        end
    end


    integer i3;
    always @ (posedge clk_i) begin
        if (n_rst_i == `RstEnable) begin
            for (i3 = 0; i3 < NUM_RAS_ENTRIES; i3 = i3 + 1) begin
                ras_list[i3] <= 32'h0;
            end
            ras_speculative_curr_index <= {RAS_ENTRIES_WIDTH{1'b0}};
        end
        else begin
            if (branch_mispredict_i & branch_request_i & branch_is_call_i) begin
                ras_list[ras_speculative_next_index] <= branch_source_i + 4;
                ras_speculative_curr_index <= ras_speculative_next_index;
            end
            else if (ras_call_matched && stall_i == 1'b0) begin
                ras_list[ras_speculative_next_index] <= pc_i + 4;
                ras_speculative_curr_index <= ras_speculative_next_index;
            end
            else if(branch_mispredict_i & branch_request_i & branch_is_ret_i) begin
                ras_speculative_curr_index <= ras_speculative_next_index;
            end
            else if (ras_ret_matched && stall_i == 1'b0) begin
                ras_speculative_curr_index <= ras_speculative_next_index;
            end
        end
    end

    bp_allocate_entry
        #(
            .DEPTH(NUM_BTB_ENTRIES)
        )
        u_lru
        (
            .clk_i(clk_i),
            .n_rst_i(n_rst_i),
            .alloc_i(btb_alloc_req),
            .alloc_entry_o(btb_alloc_entry)
        );

    assign next_pc_o = ras_ret_matched ? ras_pred_pc : ( btb_is_matched & (bht_predict_taken | btb_is_jmp | btb_is_call) ) ? btb_target_pc : pc_i + 4;
    assign next_branch_o = (btb_is_matched & (btb_is_call | btb_is_ret | bht_predict_taken | btb_is_jmp)) ? 1'b1 : 1'b0;

endmodule


module bp_allocate_entry #( parameter DEPTH = 32 )
    (
        input                     clk_i,
        input                     n_rst_i,
        input                     alloc_i,
        output[$clog2(DEPTH)-1:0] alloc_entry_o
    );
    localparam ADDR_W = $clog2(DEPTH);

    reg [ADDR_W-1:0] lfsr_q;

    always @ (posedge clk_i or negedge  n_rst_i) begin
        if (n_rst_i == `RstEnable)
            lfsr_q <= {ADDR_W{1'b0}};
        else if (alloc_i) begin
            if (lfsr_q == {ADDR_W{1'b1}}) begin
                lfsr_q <= {ADDR_W{1'b0}};
            end
            else begin
                lfsr_q <= lfsr_q + 1;
            end
        end
    end
	
    assign alloc_entry_o = lfsr_q[ADDR_W-1:0];

endmodule
