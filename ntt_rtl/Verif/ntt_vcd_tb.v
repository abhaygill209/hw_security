`include "DesignParam.vh"

module ntt_vcd_tb (
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   valid_i,
    input  wire                   stall_i,
    input  wire [`DATA_WIDTH-1:0] a_i,
    input  wire [`DATA_WIDTH-1:0] b_i,
    output wire [`DATA_WIDTH-1:0] a_o,
    output wire [`DATA_WIDTH-1:0] b_o,
    output wire                   valid_o
);
    NTT_engine dut (
        .clk(clk),
        .rst(rst),
        .valid_i(valid_i),
        .stall_i(stall_i),
        .a_i(a_i),
        .b_i(b_i),
        .a_o(a_o),
        .b_o(b_o),
        .valid_o(valid_o)
    );

    initial begin
        $dumpfile("ntt.vcd");
        $dumpvars(0, ntt_vcd_tb);
    end
endmodule
