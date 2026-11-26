// Reorder final CT butterfly pairs from bit-reversed group order to
// consecutive coefficient order. Two banks allow one frame to be written
// while the preceding frame is read.
module PairReorder #(
    parameter DATA_WIDTH = 32,
    parameter N          = 256
)(
    input                       clk_i,
    input                       rst_i,
    input                       valid_i,
    input                       stall_i,
    input      [DATA_WIDTH-1:0] a_i,
    input      [DATA_WIDTH-1:0] b_i,
    output reg                  valid_o,
    output reg [DATA_WIDTH-1:0] a_o,
    output reg [DATA_WIDTH-1:0] b_o
);

    localparam PAIRS = N / 2;
    localparam INDEX_BITS = $clog2(PAIRS);
    localparam [INDEX_BITS-1:0] LAST_PAIR = PAIRS[INDEX_BITS-1:0] - 1'b1;

    reg [DATA_WIDTH-1:0] bank_a [0:1][0:PAIRS-1];
    reg [DATA_WIDTH-1:0] bank_b [0:1][0:PAIRS-1];

    reg write_bank, read_bank;
    reg [INDEX_BITS-1:0] write_pair, read_pair;
    reg [1:0] frames_ready;

    function [INDEX_BITS-1:0] reverse_pair_index;
        input [INDEX_BITS-1:0] index;
        integer bit_index;
        begin
            for (bit_index = 0; bit_index < INDEX_BITS; bit_index = bit_index + 1)
                reverse_pair_index[bit_index] = index[INDEX_BITS - 1 - bit_index];
        end
    endfunction

    wire write_accept = valid_i && !stall_i;
    wire read_enable = (frames_ready != 0) && !stall_i;
    wire write_complete = write_accept && (write_pair == LAST_PAIR);
    wire read_complete = read_enable && (read_pair == LAST_PAIR);

    always @(posedge clk_i) begin
        if (rst_i) begin
            write_bank <= 1'b0;
            read_bank <= 1'b0;
            write_pair <= 0;
            read_pair <= 0;
            frames_ready <= 0;
            valid_o <= 1'b0;
            a_o <= 0;
            b_o <= 0;
        end else if (!stall_i) begin
            if (write_accept) begin
                bank_a[write_bank][reverse_pair_index(write_pair)] <= a_i;
                bank_b[write_bank][reverse_pair_index(write_pair)] <= b_i;
                if (write_complete) begin
                    write_pair <= 0;
                    write_bank <= ~write_bank;
                end else begin
                    write_pair <= write_pair + 1'b1;
                end
            end

            valid_o <= read_enable;
            if (read_enable) begin
                a_o <= bank_a[read_bank][read_pair];
                b_o <= bank_b[read_bank][read_pair];
                if (read_complete) begin
                    read_pair <= 0;
                    read_bank <= ~read_bank;
                end else begin
                    read_pair <= read_pair + 1'b1;
                end
            end

            case ({write_complete, read_complete})
                2'b10: frames_ready <= frames_ready + 1'b1;
                2'b01: frames_ready <= frames_ready - 1'b1;
                default: frames_ready <= frames_ready;
            endcase
        end
    end
endmodule
