`include "DesignParam.vh"

module NTT_engine(
    input  clk, rst,
    input  valid_i,
    input  stall_i,
    input  [`DATA_WIDTH-1:0] a_i, b_i,
    output [`DATA_WIDTH-1:0] a_o, b_o,
    output valid_o
);

    localparam integer STAGES = $clog2(`N);

    // Binary input
    always @(*) begin
        DU_BU_bus_a_D[0] = a_i;
        DU_BU_bus_b_D[0] = b_i;
        DU_BU_valid_D[0] = valid_i;
    end

    wire [`DATA_WIDTH-1:0] BU_DU_bus_a   [0:STAGES-1];
    wire [`DATA_WIDTH-1:0] BU_DU_bus_b   [0:STAGES-1];

    wire [`DATA_WIDTH-1:0] DU_BU_bus_a   [1:STAGES-1];
    wire [`DATA_WIDTH-1:0] DU_BU_bus_b   [1:STAGES-1];

    wire [`DATA_WIDTH-1:0] tf_data_0;
    wire [`DATA_WIDTH-1:0] tf_data_1;
    wire [`DATA_WIDTH-1:0] tf_data_2;
    wire [`DATA_WIDTH-1:0] tf_data_3;
    wire [`DATA_WIDTH-1:0] tf_data_4;
    wire [`DATA_WIDTH-1:0] tf_data_5;
    wire [`DATA_WIDTH-1:0] tf_data_6;
    wire [`DATA_WIDTH-1:0] tf_data_7;

    wire BU_DU_valid   [0:STAGES-1];
    wire DU_BU_valid   [1:STAGES-1];

    reg                   DU_BU_valid_D [0:STAGES-1];
    reg [`DATA_WIDTH-1:0] DU_BU_bus_a_D [0:STAGES-1];
    reg [`DATA_WIDTH-1:0] DU_BU_bus_b_D [0:STAGES-1];

    genvar i;
    generate
        for (i = 0; i < STAGES; i = i + 1) begin : butterfly_gen
            ButterflyUnitCT #(
                .DATA_WIDTH(`DATA_WIDTH),
                .Q(`Q),
                .Q_WIDTH(`Q_WIDTH),
                .Q_INV(`Q_INV)
            ) butterfly_inst (
                .clk(clk),
                .rst(rst),
                .stall(stall_i),
                .valid_i(DU_BU_valid_D[i]),
                .valid_out(BU_DU_valid[i]),
                .a_i(DU_BU_bus_a_D[i]),
                .b_i(DU_BU_bus_b_D[i]),
                .w(
                    (i==0) ? tf_data_0 :
                    (i==1) ? tf_data_1 :
                    (i==2) ? tf_data_2 :
                    (i==3) ? tf_data_3 :
                    (i==4) ? tf_data_4 :
                    (i==5) ? tf_data_5 :
                    (i==6) ? tf_data_6 :
                    tf_data_7
                ),
                .a_o(BU_DU_bus_a[i]),
                .b_o(BU_DU_bus_b[i])
            );
        end
    endgenerate

    // The last CT stage emits correct pairs in bit-reversed group order.
    PairReorder #(
        .DATA_WIDTH(`DATA_WIDTH),
        .N(`N)
    ) output_reorder (
        .clk_i(clk),
        .rst_i(rst),
        .stall_i(stall_i),
        .valid_i(BU_DU_valid[STAGES-1]),
        .valid_o(valid_o),
        .a_i(BU_DU_bus_a[STAGES-1]),
        .b_i(BU_DU_bus_b[STAGES-1]),
        .a_o(a_o),
        .b_o(b_o)
    );

    genvar g;
    generate
        for(g = 1; g < STAGES; g = g + 1) begin : delay
            always @(posedge clk) begin
                if (rst) begin
                    DU_BU_valid_D[g] <= 1'b0;
                    DU_BU_bus_a_D[g] <= 0;
                    DU_BU_bus_b_D[g] <= 0;
                end else begin
                    if (!stall_i) begin
                        DU_BU_valid_D[g] <= DU_BU_valid[g];
                        DU_BU_bus_a_D[g] <= DU_BU_bus_a[g];
                        DU_BU_bus_b_D[g] <= DU_BU_bus_b[g];
                    end
                end
            end
        end
    endgenerate

    Delay_Unit #(
        .DATA_WIDTH(`DATA_WIDTH),
        .STAGE(1),
        .DEPTH(6)
    ) Delay_inst_1 (
        .clk_i(clk),
        .rst_i(rst),
        .stall_i(stall_i),
        .valid_i(BU_DU_valid[0]),
        .valid_o(DU_BU_valid[1]),
        .a_i(BU_DU_bus_a[0]),
        .b_i(BU_DU_bus_b[0]),
        .a_o(DU_BU_bus_a[1]),
        .b_o(DU_BU_bus_b[1])
    );

    Delay_Unit #(
        .DATA_WIDTH(`DATA_WIDTH),
        .STAGE(2),
        .DEPTH(8)
    ) Delay_inst_2 (
        .clk_i(clk),
        .rst_i(rst),
        .stall_i(stall_i),
        .valid_i(BU_DU_valid[1]),
        .valid_o(DU_BU_valid[2]),
        .a_i(BU_DU_bus_a[1]),
        .b_i(BU_DU_bus_b[1]),
        .a_o(DU_BU_bus_a[2]),
        .b_o(DU_BU_bus_b[2])
    );

    Delay_Unit #(
        .DATA_WIDTH(`DATA_WIDTH),
        .STAGE(3),
        .DEPTH(14)
    ) Delay_inst_3 (
        .clk_i(clk),
        .rst_i(rst),
        .stall_i(stall_i),
        .valid_i(BU_DU_valid[2]),
        .valid_o(DU_BU_valid[3]),
        .a_i(BU_DU_bus_a[2]),
        .b_i(BU_DU_bus_b[2]),
        .a_o(DU_BU_bus_a[3]),
        .b_o(DU_BU_bus_b[3])
    );

    Delay_Unit #(
        .DATA_WIDTH(`DATA_WIDTH),
        .STAGE(4),
        .DEPTH(26)
    ) Delay_inst_4 (
        .clk_i(clk),
        .rst_i(rst),
        .stall_i(stall_i),
        .valid_i(BU_DU_valid[3]),
        .valid_o(DU_BU_valid[4]),
        .a_i(BU_DU_bus_a[3]),
        .b_i(BU_DU_bus_b[3]),
        .a_o(DU_BU_bus_a[4]),
        .b_o(DU_BU_bus_b[4])
    );

    Delay_Unit #(
        .DATA_WIDTH(`DATA_WIDTH),
        .STAGE(5),
        .DEPTH(50)
    ) Delay_inst_5 (
        .clk_i(clk),
        .rst_i(rst),
        .stall_i(stall_i),
        .valid_i(BU_DU_valid[4]),
        .valid_o(DU_BU_valid[5]),
        .a_i(BU_DU_bus_a[4]),
        .b_i(BU_DU_bus_b[4]),
        .a_o(DU_BU_bus_a[5]),
        .b_o(DU_BU_bus_b[5])
    );

    Delay_Unit #(
        .DATA_WIDTH(`DATA_WIDTH),
        .STAGE(6),
        .DEPTH(98)
    ) Delay_inst_6 (
        .clk_i(clk),
        .rst_i(rst),
        .stall_i(stall_i),
        .valid_i(BU_DU_valid[5]),
        .valid_o(DU_BU_valid[6]),
        .a_i(BU_DU_bus_a[5]),
        .b_i(BU_DU_bus_b[5]),
        .a_o(DU_BU_bus_a[6]),
        .b_o(DU_BU_bus_b[6])
    );

    Delay_Unit #(
        .DATA_WIDTH(`DATA_WIDTH),
        .STAGE(7),
        .DEPTH(128)
    ) Delay_inst_7 (
        .clk_i(clk),
        .rst_i(rst),
        .stall_i(stall_i),
        .valid_i(BU_DU_valid[6]),
        .valid_o(DU_BU_valid[7]),
        .a_i(BU_DU_bus_a[6]),
        .b_i(BU_DU_bus_b[6]),
        .a_o(DU_BU_bus_a[7]),
        .b_o(DU_BU_bus_b[7])
    );

    // Each stage only needs enough counter and ROM address bits for its depth.
    genvar k, bit_index;
    generate
        for (k = 1; k < STAGES; k = k + 1) begin : tf_rom_ctrl_gen
            reg [k-1:0] tf_addr;
            wire [k-1:0] reversed_addr;

            for (bit_index = 0; bit_index < k; bit_index = bit_index + 1) begin : reverse_bits
                assign reversed_addr[bit_index] = tf_addr[k - 1 - bit_index];
            end

            always @(posedge clk) begin
                if (rst)
                    tf_addr <= 0;
                else if (DU_BU_valid[k] && !stall_i)
                    tf_addr <= tf_addr + 1'b1;
            end
        end
    endgenerate

    TwiddleROM #(
        .STAGE(1),
        .DATA_WIDTH(`DATA_WIDTH),
        .ADDR_WIDTH(1),
        .INIT_FILE("../TwiddleFactors/stage_2.mem")
    ) t_rom_1 (
        .clk(clk),
        .stall_i(stall_i),
        .dout(tf_data_1),
        .addr(tf_rom_ctrl_gen[1].reversed_addr)
    );

    TwiddleROM #(
        .STAGE(2),
        .DATA_WIDTH(`DATA_WIDTH),
        .ADDR_WIDTH(2),
        .INIT_FILE("../TwiddleFactors/stage_3.mem")
    ) t_rom_2 (
        .clk(clk),
        .stall_i(stall_i),
        .dout(tf_data_2),
        .addr(tf_rom_ctrl_gen[2].reversed_addr)
    );

    TwiddleROM #(
        .STAGE(3),
        .DATA_WIDTH(`DATA_WIDTH),
        .ADDR_WIDTH(3),
        .INIT_FILE("../TwiddleFactors/stage_4.mem")
    ) t_rom_3 (
        .clk(clk),
        .stall_i(stall_i),
        .dout(tf_data_3),
        .addr(tf_rom_ctrl_gen[3].reversed_addr)
    );

    TwiddleROM #(
        .STAGE(4),
        .DATA_WIDTH(`DATA_WIDTH),
        .ADDR_WIDTH(4),
        .INIT_FILE("../TwiddleFactors/stage_5.mem")
    ) t_rom_4 (
        .clk(clk),
        .stall_i(stall_i),
        .dout(tf_data_4),
        .addr(tf_rom_ctrl_gen[4].reversed_addr)
    );

    TwiddleROM #(
        .STAGE(5),
        .DATA_WIDTH(`DATA_WIDTH),
        .ADDR_WIDTH(5),
        .INIT_FILE("../TwiddleFactors/stage_6.mem")
    ) t_rom_5 (
        .clk(clk),
        .stall_i(stall_i),
        .dout(tf_data_5),
        .addr(tf_rom_ctrl_gen[5].reversed_addr)
    );

    TwiddleROM #(
        .STAGE(6),
        .DATA_WIDTH(`DATA_WIDTH),
        .ADDR_WIDTH(6),
        .INIT_FILE("../TwiddleFactors/stage_7.mem")
    ) t_rom_6 (
        .clk(clk),
        .stall_i(stall_i),
        .dout(tf_data_6),
        .addr(tf_rom_ctrl_gen[6].reversed_addr)
    );

    TwiddleROM #(
        .STAGE(7),
        .DATA_WIDTH(`DATA_WIDTH),
        .ADDR_WIDTH(7),
        .INIT_FILE("../TwiddleFactors/stage_8.mem")
    ) t_rom_7 (
        .clk(clk),
        .stall_i(stall_i),
        .dout(tf_data_7),
        .addr(tf_rom_ctrl_gen[7].reversed_addr)
    );

    assign tf_data_0 = `DATA_WIDTH'd25847;

endmodule
