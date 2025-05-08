module jacobi_iter(
    input wire clk,
    input wire rst,
    input wire load_A,
    input wire load_B,
    input wire go,
    input wire signed [26:0] A_next,
    input wire signed [26:0] B_next,
    input wire [7:0] N,
    input wire [26:0] threshold,
    input wire [15:0] max_iter,
    output reg drdy,
    output reg signed [26:0] dout,
    output reg fail
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam LOAD_B = 3'b001;
    localparam LOAD_A = 3'b010;
    localparam VERIFY = 3'b011;
    localparam CALC = 3'b100;
    localparam DIVIDE = 3'b101;
    localparam DIVIDE_2 = 3'b110;
    localparam END_ROW = 3'b111;
    localparam ITERATE = 4'b1000;
    localparam DONE = 4'b1001;
    localparam FAIL = 4'b1111;

    localparam FIXED_POINT_WIDTH = 8;

    reg [3:0] state;
    reg [15:0] iter_count;
    reg signed [26:0] A [0:39999];
    reg signed [26:0] B [0:199];
    reg signed [26:0] X [0:199];
    reg signed [26:0] X_next [0:199];
    reg signed [26:0] A_row_sum;
    reg signed [26:0] max_diff;
    reg [7:0] i, i_row, j;
    reg signed [26:0] B_i, A_i;
    reg signed [27:0] division;
    reg signed [26:0] diff;
    wire load_A_posedge, load_B_posedge, go_posedge;
    integer initializer;

    // Edge detectors
    posedge_detect uA(.clk(clk), .signal(load_A), .posedge_signal(load_A_posedge));
    posedge_detect uB(.clk(clk), .signal(load_B), .posedge_signal(load_B_posedge));
    posedge_detect uG(.clk(clk), .signal(go), .posedge_signal(go_posedge));

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            iter_count <= 0;
            drdy <= 0;
            dout <= 0;
            fail <= 0;
            i <= 0;
            i_row <= 0;
            j <= 0;
            A_row_sum <= 0;
            max_diff <= 0;
            for (initializer = 0; initializer < 200; initializer = initializer + 1) begin
                X[initializer] <= 0;
                X_next[initializer] <= 0;
            end
        end

        else begin
        case (state)
            IDLE: begin
                // Wait for go signal to start loading data
                if (go_posedge) begin
                    state <= LOAD_B;
                    i <= 0;
                end
            end

            LOAD_B: begin
                // Load B matrix
                if (i >= N) begin
                    state <= LOAD_A;
                    i <= 0;
                end else if (load_B_posedge) begin
                    B[i] <= B_next;
                    i <= i + 1;
                end
            end

            LOAD_A: begin
                // Load A matrix
                if (i >= N*N) begin
                    state <= VERIFY;
                    i <= 0;
                end else if (load_A_posedge) begin
                    A[i] <= A_next;
                    i <= i + 1;
                end
            end

            VERIFY: begin
                // Verify the loaded data here.
                // If verification fails, go to FAIL state.
                // If successful, proceed to CALC state.
                if (i_row < N && i < N) begin
                    if (i_row != i) begin
                        A_row_sum <= A_row_sum + abs_fn(A[i * N + i_row]);
                    end
                    i_row <= i_row + 1;
                end else if (abs_fn(A[i * N + i]) < A_row_sum) begin
                    state <= FAIL;
                end else if (i >= N) begin
                    state <= CALC;
                    i <= 0;
                    i_row <= 0;
                end else begin
                    i <= i + 1;
                    i_row <= 0;
                    A_row_sum <= 0;
                end
            end

            CALC: begin
                // Jacobi iteration
                // Accumulate row sum
                if (i_row < N && i < N) begin
                    if (i_row != i) begin
                        A_row_sum <= A_row_sum + ((A[i * N + i_row] * X[i_row]) >>> FIXED_POINT_WIDTH);
                    end
                    i_row <= i_row + 1;
                end else if (i < N) begin
                    state <= DIVIDE;
                end else begin
                    state <= ITERATE;
                end
            end

            DIVIDE: begin
				// Seperate the memory fetch and division to improve clock period
                A_i <= A[i * N + i];
                B_i <= B[i];
                state <= DIVIDE_2;
            end

            DIVIDE_2: begin
				// Division after memory fetch
                division <= ((B_i - A_row_sum) <<< FIXED_POINT_WIDTH) / A_i;
                state <= END_ROW;
            end

            END_ROW: begin
                X_next[i] <= division;

                if (abs_fn(division - X[i]) > max_diff) begin
                    max_diff <= abs_fn(division - X[i]);
                end

                // next row
                i <= i + 1;
                i_row <= 0;
                A_row_sum <= 0;
                if (i + 1 >= N) begin
                    state <= ITERATE;
                end else begin
                    state <= CALC;
                end
            end

            ITERATE: begin
            // Iteration done
                if (j < N) begin
                    X[j] <= X_next[j];
                    j <= j + 1;
                end else begin
                    iter_count <= iter_count + 1;
                    i <= 0;
                    j <= 0;
                    A_row_sum <= 0;
                    max_diff <= 0;
                    if (max_diff < threshold || iter_count + 1 >= max_iter) begin
                        i <= 0;
                        state <= DONE;
                    end else begin
                        state <= CALC;
                    end
                end
            end

            DONE: begin
                drdy <= 1;
                dout <= X[i];
                if (i >= N-1) begin
                    i <= 0;
                end else begin
                    i <= i + 1;
                end
            end

            FAIL: begin
                fail <= 1;
                drdy <= 1;
            end

            default: state <= IDLE;
        endcase
        end
    end

    // Simple absolute value function
    function signed [26:0] abs_fn;
        input signed [26:0] value;
    begin
        if (value < 0)
            abs_fn = -value;
        else
            abs_fn = value;
    end
    endfunction

endmodule


module posedge_detect(
    input wire clk,
    input wire signal,
    output posedge_signal
);
    reg signal_prev;
    assign posedge_signal = signal & ~signal_prev;
    always @(posedge clk) begin
        signal_prev <= signal;
    end
endmodule
