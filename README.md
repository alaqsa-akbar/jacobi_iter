# Jacobi Iterative Method
A verilog module that solves the equation $AX=B$ where $A$ is a matrix of size $n\times n$, $X$ is of size $n\times1$ and $B$ is of size $n\times1$. $A$ and $B$ are inputted serially and then are verified to be diagonally dominant otherwise the module will output a fail signal. Then the matrix $X$ is calculated and serially outputted setting `drdy` to high. The module operates using fixed point arithmetic with a width of $27$ bits and scale of $8$ bits. $n$ can be a maximum of $200$. You can read about how Jacobi's Iterative method works here: [Jacobi Method](https://en.wikipedia.org/wiki/Jacobi_method).

# Inputs
```verilog 
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
```

- `clk`: Clock signal.
    - When synthesized, the max clock came out to be around 15 MHz. As such, it is advised to use and internally generated clock if deployed on an FPGA
- `rst`: Synchronous reset signal
- `load_A`: Load A signal
    - On the positive edge of `load_A`, the next value of $A$ is loaded
    - This only ever matters when in the `LOAD_A` state which happens after the `LOAD_B` state
    - `LOAD_A` finishes and goes to the `VERIFY` state after $n\times n$ positive edges of `load_A`
- `load_B`: Load B signal
    - On the positive edge of `load_B`, the next value of $B$ is loaded
    - This only ever matters when in the `LOAD_B` state which happens after the positive edge of `go`
    - `LOAD_B` finishes and goes to the `LOAD_A` state after $n$ positive edges of `load_A`
- `go`: Start signal
    - On positive edge of `go`, we exist state `IDLE` and start with `LOAD_B`
    - If we are not in `IDLE`, `go` does nothing
- `A_next`: The next value of $A$ to be loaded during positive edge of $load_A$ and state $LOAD_A$
    - Signed fixed point with width of $27$ and scale of $8$
- `B_next`: The next value of $B$ to be loaded during positive edge of $load_B$ and state $LOAD_B$
    - Signed fixed point with width of $27$ and scale of $8$
- `N`: The value of $n$
    - Unsigned integer of size $8$ bits, can be of maximum size $200$
- `threshold`: Maximum difference of $X_t$ and $X_{t-1}$ where $t$ is the iteration count
    - Unsigned fixed point with width of $27$ and scale of $8$
- `max_iter`: Maximum number of iterations
    - Unsigned integer of size $16$ bits

# Outputs
```verilog
output reg drdy,
output reg signed [26:0] dout,
output reg fail
```

- `drdy`: Signal indicating output is ready
- `dout`: Serial output of the computed value of $X$
    - Signed fixed point with width of $27$ and scale of $8$
- `fail`: Signal indicating if $A$ failed the diagonal dominance test

# Generate Test Cases
The file `generate_test_cases.txt` generates the golden outputs for the testbench into the file `test_cases.txt`. It follows this format:
```
n max_iter threshold
fail
expected_x
"Values of B"
"Values of A"
```
The file generates $40$ test cases randomly with $30$ guaranteed to be diagnoally dominant. You can change these values in the python file.

# Test Bench
The test bench will read from the `test_cases.txt` generated from the python file and run the module to test it. This is an example output of `tb.v`:
```
# Match: Computed =        -40, Expected =        -40
# Match: Computed =       -102, Expected =       -102
# Match: Computed =        -57, Expected =        -57
# Latency:         217 clock cycles
# Match: Computed =        -35, Expected =        -35
# Latency:          26 clock cycles
# Fail Matched.
# Latency:         158 clock cycles
# Fail Matched.
# Latency:          50 clock cycles
# Fail Matched.
# Latency:          33 clock cycles
# Average Latency: 398.20 clock cycles
# Maximum Latency:         940 clock cycles
# Test completed. Total mismatches:           0
```
It indicates if expected values are matched or not and whether failure cases are caught (matched) or not. Ideal solution is $0$ mismatches. It also computes the clock cycles spent on each test case and the average total latency in clock cycles.
