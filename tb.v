`timescale 1ns/1ns

module tb;
    // Testbench signals
    reg clk;
    reg reset;
    reg go;
    reg signed [26:0] din;
    wire signed [26:0] dout;
    wire drdy;
    wire [2:0] state;
    reg [7:0] address; // used in the Avalon MM interface
    reg [7:0] N_; // number of elements
    reg [26:0] max_thresh_; // maximum threshold
    reg [15:0] max_iteration;
    reg signed [26:0] A_next; // next value of A
    reg signed [26:0] B_next; // next value of B
    reg load_A; // load A signal
    reg load_B; // load B signal
    reg [13:0] N_squared; // N squared value
    
    integer datafile, status, mismatch_count, latency, cycle_count, i, n;
    integer total_latency, max_latency, test_count;
    reg signed [26:0] expected_var [199:0]; // expected output variable
    reg signed [26:0] expected_var_i; // expected output variable
    reg measuring_latency;
    wire fail;
    reg fail_flag;

    // Instantiate the DUT
    // input wire clk,
    // input wire rst,
    // input load_A,
    // input load_B,
    // input go,
    // input signed [26:0] A_next,
    // input signed [26:0] B_next,
    // input [7:0] N,
    // input [7:0] max_iter,
    // input [7:0] threshold,
    // output drdy,
    // output signed [26:0] dout,
    // output fail
    jacobi_iter uut (
        .clk(clk),
        .rst(reset),
        .load_A(load_A),
        .load_B(load_B),
        .go(go),
        .A_next(A_next),
        .B_next(B_next),
        .N(N_),
        .max_iter(max_iteration),
        .threshold(max_thresh_),
        .drdy(drdy),
        .dout(dout),
        .fail(fail)
    );

    // Clock generation
    always #10 clk = ~clk;

    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
        // Open data file
        datafile = $fopen("test_cases.txt", "r");

        if (datafile == 0) begin
            $display("Error opening data file.");
            $finish;
        end

        // Initialize signals
        clk = 0;
        go = 0;
        load_A = 0;
        load_B = 0;
        mismatch_count = 0;
        measuring_latency = 0;
        latency = 0;
        cycle_count = 0;
        total_latency = 0;
        max_latency = 0;
        test_count = 0;

        while (!$feof(datafile)) begin
            @(posedge clk);
            @(negedge clk) reset = 1;
            @(negedge clk) reset = 0;
            @(negedge clk) go = 0;

            // Read n (number of elements) and max_iteration and max_thresh_ from the file
            status = $fscanf(datafile, "%d %d %d", N_, max_iteration, max_thresh_);
            if (status != 3) begin
                $fclose(datafile);
                if (test_count > 0) begin
                    $display("Average Latency: %0.2f clock cycles", total_latency * 1.0 / test_count);
                end
                $display("Maximum Latency: %d clock cycles", max_latency);
                $display("Test completed. Total mismatches: %d", mismatch_count);
                $finish;
            end
            N_squared = N_ * N_;

            // $display("Read n=%d, status=%d, go=%d", din, status, go);
            @(negedge clk);
            go = 1;
            @(negedge clk);
            go = 0;

            measuring_latency = 1;
            cycle_count = 0;
            test_count = test_count + 1;

            status = $fscanf(datafile, "%d", fail_flag);

            // Now read the remaining N_-1 numbers
            for (i = 0; i < N_; i = i + 1) begin
                status = $fscanf(datafile, "%d", expected_var_i);
                expected_var[i] = expected_var_i;
            end

            // Read B
            for (i = 0; i < N_; i = i + 1) begin
                @(negedge clk) load_B = 0;
                status = $fscanf(datafile, "%d", B_next);
                @(negedge clk) load_B = 1;
            end

            @(negedge clk) load_B = 0;
            @(negedge clk) load_B = 1;

            // Read A
            for (i = 0; i < N_squared; i = i + 1) begin
                @(negedge clk) load_A = 0;
                status = $fscanf(datafile, "%d", A_next);
                @(negedge clk) load_A = 1;
            end

            @(negedge clk) load_A = 0;
            @(negedge clk) load_A = 1;

            // Wait for output
            wait (drdy);
            measuring_latency = 0;
            latency = cycle_count;
           
            // Compare results
            if (fail_flag) begin
                if (fail) begin
                    $display("Fail Matched.");
                end else begin
                    $display("Fail Mismatched.");
                    mismatch_count = mismatch_count + 1;
                end
            end else if (fail) begin
                if (fail_flag) begin
                    $display("Fail Matched.");
                end else begin
                    $display("Fail Mismatched.");
                    mismatch_count = mismatch_count + 1;
                end
            end else begin
                for (i = 0; i < N_; i = i + 1) begin
                    @(posedge clk);
                    if (dout !== expected_var[i]) begin
                        $display("Mismatch: Computed = %d, Expected = %d", dout, expected_var[i]);
                        mismatch_count = mismatch_count + 1;
                    end else begin
                        $display("Match: Computed = %d, Expected = %d", dout, expected_var[i]);
                    end
                end
            end


            // Update total and maximum latency
            total_latency = total_latency + latency;
            if (latency > max_latency) max_latency = latency;

            $display("Latency: %d clock cycles", latency);

            // $display("Read x_value=%d, expected=%d, status=%d, go=%d", n, expected_var, status, go);
        end

        // Report final results
        $fclose(datafile);
        if (test_count > 0) begin
            $display("Average Latency: %0.2f clock cycles", total_latency * 1.0 / test_count);
        end
        $display("Maximum Latency: %d clock cycles", max_latency);
        $display("Test completed. Total mismatches: %d", mismatch_count);
        $finish;
    end

    always @(posedge clk) begin
        if (measuring_latency) begin
            cycle_count = cycle_count + 1;
        end
    end

endmodule


