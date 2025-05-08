import random 

scale = 8  # Fixed-point scale

def convert_to_fixed_point(value, scale=scale):
    return int(value * (1 << scale))

def fixed_point_product(a, b, scale=scale):
    # Correctly multiply two fixed-point numbers (already scaled)
    return int((a * b) >> scale)

def fixed_point_division(a, b, scale=scale):
    if b == 0:
        raise ValueError("Division by zero")
    return int((a << scale) / b)

def jacobi(a, b, x, n, max_iter, threshold):
    for _ in range(max_iter):
        x_new = [0] * n
        for j in range(n):
            sum_ax = sum(fixed_point_product(a[j][k], x[k]) for k in range(n) if k != j)
            numerator = b[j] - sum_ax
            x_new[j] = fixed_point_division(numerator, a[j][j])
        if all(abs(x_new[k] - x[k]) < threshold for k in range(n)):
            return x_new
        x = x_new
        # print(x)
    return x_new

# Remaining functions (check_diagonal_dominance, main) remain unchanged

def check_diagonal_dominance(a, n):
    for i in range(n):
        diag = abs(a[i][i])
        sum_row = sum(abs(a[i][j]) for j in range(n) if j != i)
        if diag < sum_row:
            return False
    return True

def main():
    with open("test_cases.txt", "w") as f:
        num_cases_success = 30
        total_cases = 40
        count_success = 0

        for case in range(total_cases):
            print(f"Generating test case {case + 1} of {total_cases}...")
            n = random.randint(1, 10)
            # n = 2
            max_iter = random.randint(1, 1000)
            threshold = random.uniform(0.01, 0.1)
            failed = False

            a = [[random.uniform(-100, 100) for _ in range(n)] for _ in range(n)]
            b = [random.uniform(-100, 100) for _ in range(n)]

            if not check_diagonal_dominance(a, n):
                # Make the matrix diagonally dominant
                if count_success < num_cases_success:
                    print(count_success)
                    for i in range(n):
                        a[i][i] = sum(abs(a[i][j]) for j in range(n) if j != i) + random.uniform(1, 10)
                    count_success += 1
                    failed = False
                else:
                    failed = True

            # print("Matrix A:")
            # for row in a:
            #     print(row)
            # print("Vector B:")
            # print(b)

            # Convert a and b to fixed-point
            a_fixed = [[convert_to_fixed_point(val) for val in row] for row in a]
            b_fixed = [convert_to_fixed_point(val) for val in b]
            threshold_fixed = convert_to_fixed_point(threshold)

            # Initial x is zeros (fixed-point)
            x = [0] * n

            # Run Jacobi with fixed-point values
            x_solution = jacobi(a_fixed, b_fixed, x, n, max_iter, threshold_fixed)

            # Convert solution back to float
            # x_float = [val / (1 << 8) for val in x_solution]

            # Write to file and print as before
            # print("Solution X:")
            # print(x_float)

            f.write(f"{n} {max_iter} {convert_to_fixed_point(threshold)}\n")
            if failed:
                f.write("1\n")
            else:
                f.write("0\n")
            f.write(" ".join(str(i) for i in x_solution) + "\n")
            f.write(" ".join(str(i) for i in b_fixed) + "\n")
            f.write(" ".join(" ".join(str(a_fixed[i][j]) for j in range(n)) for i in range(n)) + "\n")

main()