module TwiddleROM #(
    parameter DATA_WIDTH = 32,
    parameter STAGE      = 1,
    parameter DEPTH      = (STAGE == 0) ? 1 : (1 << STAGE),
    parameter ADDR_WIDTH = (DEPTH <= 1) ? 1 : $clog2(DEPTH),
    parameter INIT_FILE  = ""
)(
    input  wire                   clk,
    input  wire                   stall_i,
    input  wire [ADDR_WIDTH-1:0]  addr,
    output reg  [DATA_WIDTH-1:0]  dout
);

    // ============================================================
    // ROM Memory
    // ============================================================

    (* ram_style = "block", rom_style = "block" *)
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // ============================================================
    // Memory Initialization
    // ============================================================

    initial begin
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, mem);
    end

    // ============================================================
    // Synchronous Read
    // ============================================================

    always @(posedge clk) begin

        if (!stall_i) begin

            dout <= mem[addr];

        end

    end

endmodule
