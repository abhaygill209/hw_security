// Forward ML-DSA butterfly. Inputs are canonical residues; w is in
// Montgomery form. The module name is retained for existing instances.
module ButterflyUnitCT #(
    parameter DATA_WIDTH = 23,
    parameter Q          = 8380417,
    parameter Q_WIDTH    = 32,
    parameter Q_INV      = 32'd4236238847
)(
    input                           clk,
    input                           rst,
    input                           valid_i,
    input                           stall,

    input      [DATA_WIDTH-1:0]     a_i,
    input      [DATA_WIDTH-1:0]     b_i,
    input      [DATA_WIDTH-1:0]     w,

    output reg                      valid_out,
    output reg [DATA_WIDTH-1:0]     a_o,
    output reg [DATA_WIDTH-1:0]     b_o
);

    // =====================================================
    // Parameters
    // =====================================================

    localparam MULT_WIDTH = 2 * DATA_WIDTH;
    localparam MQ_WIDTH   = Q_WIDTH + DATA_WIDTH;
    localparam T_WIDTH    =
        ((MULT_WIDTH > MQ_WIDTH) ? MULT_WIDTH : MQ_WIDTH) + 1;
    localparam TDIV_WIDTH = T_WIDTH - Q_WIDTH;

    // =====================================================
    // Pipeline Registers
    // =====================================================

    reg [MULT_WIDTH-1:0] mult_s1;
    reg [DATA_WIDTH-1:0] a_s1;
    reg                  valid_s1;

    reg [Q_WIDTH-1:0]    m_s2;
    reg [MULT_WIDTH-1:0] mult_s2;
    reg [DATA_WIDTH-1:0] a_s2;
    reg                  valid_s2;

    reg [TDIV_WIDTH-1:0] t_s3;
    reg [DATA_WIDTH-1:0] a_s3;
    reg                  valid_s3;

    reg [DATA_WIDTH-1:0] diff_s4;
    reg [DATA_WIDTH-1:0] sum_s4;
    reg                  valid_s4;

    // =====================================================
    // Stage 1: Multiply the second operand by a Montgomery-form twiddle.
    // =====================================================

    wire [MULT_WIDTH-1:0] mult_next = b_i * w;

    // =====================================================
    // Stage 2: Montgomery Parameter
    //
    // m = (T * Q_INV) mod R
    // =====================================================

    wire [Q_WIDTH-1:0] m_next =
        mult_s1[Q_WIDTH-1:0] * Q_INV;

    // =====================================================
    // Stage 3: Montgomery Reduction
    //
    // t = (T + m*Q) / R
    // =====================================================

    wire [MQ_WIDTH-1:0] mq =
        m_s2 * Q[DATA_WIDTH-1:0];

    // Only the carry from the low Q_WIDTH bits reaches the quotient.
    wire low_carry = mult_s2[Q_WIDTH-1:0] > ~mq[Q_WIDTH-1:0];
    wire [TDIV_WIDTH-1:0] t_div =
        {{(TDIV_WIDTH-(MULT_WIDTH-Q_WIDTH)){1'b0}}, mult_s2[MULT_WIDTH-1:Q_WIDTH]}
        + {{(TDIV_WIDTH-(MQ_WIDTH-Q_WIDTH)){1'b0}}, mq[MQ_WIDTH-1:Q_WIDTH]}
        + {{(TDIV_WIDTH-1){1'b0}}, low_carry};

    // =====================================================
    // Stage 4: Canonicalize the product and form both outputs.
    // The extra sum bit preserves the carry from (Q-1) + (Q-1).
    // =====================================================

    wire [DATA_WIDTH-1:0] t_sub_q =
        t_s3[DATA_WIDTH-1:0] - Q[DATA_WIDTH-1:0];

    wire [DATA_WIDTH-1:0] twiddle_product =
        (t_s3 >= Q)
        ? t_sub_q
        : t_s3[DATA_WIDTH-1:0];

    wire [DATA_WIDTH:0] sum_full =
        {1'b0, a_s3} + {1'b0, twiddle_product};
    wire [DATA_WIDTH-1:0] sum_reduced =
        sum_full[DATA_WIDTH-1:0] - Q[DATA_WIDTH-1:0];
    wire [DATA_WIDTH-1:0] sum_next =
        (sum_full >= {1'b0, Q[DATA_WIDTH-1:0]})
        ? sum_reduced
        : sum_full[DATA_WIDTH-1:0];

    wire [DATA_WIDTH-1:0] diff_next =
        (a_s3 >= twiddle_product)
        ? (a_s3 - twiddle_product)
        : (a_s3 + Q[DATA_WIDTH-1:0] - twiddle_product);

    // =====================================================
    // Pipeline
    // =====================================================

    always @(posedge clk) begin

        if (rst) begin

            valid_s1  <= 1'b0;
            valid_s2  <= 1'b0;
            valid_s3  <= 1'b0;
            valid_s4  <= 1'b0;
            valid_out <= 1'b0;

            mult_s1 <= {MULT_WIDTH{1'b0}};
            mult_s2 <= {MULT_WIDTH{1'b0}};

            m_s2 <= {Q_WIDTH{1'b0}};

            t_s3 <= {TDIV_WIDTH{1'b0}};

            a_s1 <= {DATA_WIDTH{1'b0}};
            a_s2 <= {DATA_WIDTH{1'b0}};
            a_s3 <= {DATA_WIDTH{1'b0}};
            sum_s4 <= {DATA_WIDTH{1'b0}};

            diff_s4 <= {DATA_WIDTH{1'b0}};

            a_o <= {DATA_WIDTH{1'b0}};
            b_o <= {DATA_WIDTH{1'b0}};

        end

        else if (stall) begin

            // Hold all pipeline registers.

        end

        else begin

            // ---------------------------------------------
            // Stage 1: Multiplication and first operand delay
            // ---------------------------------------------

            valid_s1 <= valid_i;

            if (valid_i) begin
                mult_s1 <= mult_next;
                a_s1    <= a_i;
            end

            // ---------------------------------------------
            // Stage 2: Montgomery Parameter
            // ---------------------------------------------

            valid_s2 <= valid_s1;

            if (valid_s1) begin
                m_s2    <= m_next;
                mult_s2 <= mult_s1;
                a_s2    <= a_s1;
            end

            // ---------------------------------------------
            // Stage 3: Montgomery Reduction
            // ---------------------------------------------

            valid_s3 <= valid_s2;

            if (valid_s2) begin
                t_s3   <= t_div;
                a_s3 <= a_s2;
            end

            // ---------------------------------------------
            // Stage 4: Modular addition and subtraction
            // ---------------------------------------------

            valid_s4 <= valid_s3;

            if (valid_s3) begin
                diff_s4 <= diff_next;
                sum_s4 <= sum_next;
            end

            // ---------------------------------------------
            // Stage 5: Outputs
            // ---------------------------------------------

            valid_out <= valid_s4;

            if (valid_s4) begin
                a_o <= sum_s4;
                b_o <= diff_s4;
            end

        end

    end

endmodule
