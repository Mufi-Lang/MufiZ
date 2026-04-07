#!/usr/bin/env python3
"""
MufiZ Matrix/Tensor Performance Benchmark Suite
Phase 5: Performance Optimization Profiling
"""

import subprocess
import time
import sys
import os
import json
from pathlib import Path

class MatrixBenchmark:
    def __init__(self):
        self.mufiz_bin = "./zig-out/bin/mufiz"
        self.results = {}
        
    def create_identity_bench(self, n):
        """Benchmark identity matrix creation"""
        return f"""
import "matrix"
import "tensor"

fn main() {{
    var m = matrix_eye({n})
    print("Created {n}x{n} identity matrix")
}}
"""

    def create_matmul_bench(self, n):
        """Benchmark matrix multiplication"""
        return f"""
import "matrix"
import "tensor"

fn main() {{
    var m1 = matrix_eye({n})
    var m2 = matrix_eye({n})
    var result = matrix_matmul(m1, m2)
    print("Matrix multiply {n}x{n} complete")
}}
"""

    def create_tensor_matmul_bench(self, n):
        """Benchmark tensor matrix multiplication"""
        return f"""
import "tensor"

fn main() {{
    var t1 = tensor_eye({n})
    var t2 = tensor_eye({n})
    var result = tensor_matmul(t1, t2)
    print("Tensor matmul {n}x{n} complete")
}}
"""

    def create_elementwise_bench(self, n):
        """Benchmark element-wise operations"""
        return f"""
import "matrix"

fn main() {{
    var m1 = matrix_eye({n})
    var m2 = matrix_eye({n})
    var result = m1 .* m2
    print("Element-wise multiply {n}x{n} complete")
}}
"""

    def run_benchmark(self, name, code, size):
        """Run a single benchmark and measure time"""
        temp_file = f"/tmp/bench_{name}_{size}.mufi"
        
        # Write test file
        with open(temp_file, 'w') as f:
            f.write(code)
        
        # Run and measure time
        try:
            start = time.time()
            result = subprocess.run(
                [self.mufiz_bin, "--full-stdlib", "-r", temp_file],
                capture_output=True,
                timeout=30,
                text=True
            )
            elapsed = time.time() - start
            
            if result.returncode != 0:
                return None, f"Error: {result.stderr}"
            
            return elapsed, result.stdout
        except subprocess.TimeoutExpired:
            return None, "Timeout"
        except Exception as e:
            return None, str(e)
        finally:
            if os.path.exists(temp_file):
                os.remove(temp_file)

    def run_suite(self):
        """Run complete benchmark suite"""
        print("=" * 60)
        print("MufiZ Matrix/Tensor Performance Benchmark Suite")
        print("=" * 60)
        print()
        
        # Test sizes
        sizes = [10, 50, 100, 200]
        
        benchmarks = [
            ("identity_creation", self.create_identity_bench),
            ("matrix_matmul", self.create_matmul_bench),
            ("tensor_matmul", self.create_tensor_matmul_bench),
            ("elementwise_op", self.create_elementwise_bench),
        ]
        
        all_results = {}
        
        for bench_name, bench_func in benchmarks:
            print(f"\nBenchmark: {bench_name}")
            print("-" * 60)
            all_results[bench_name] = {}
            
            for size in sizes:
                code = bench_func(size)
                elapsed, output = self.run_benchmark(bench_name, code, size)
                
                if elapsed is None:
                    print(f"  {size:4d}x{size:<4d}: ERROR - {output}")
                    all_results[bench_name][size] = None
                else:
                    print(f"  {size:4d}x{size:<4d}: {elapsed*1000:8.2f} ms")
                    all_results[bench_name][size] = elapsed
        
        return all_results

    def save_results(self, results, filename="benchmark_results.json"):
        """Save results to JSON"""
        with open(filename, 'w') as f:
            json.dump(results, f, indent=2)
        print(f"\nResults saved to {filename}")

def main():
    benchmark = MatrixBenchmark()
    
    # Verify binary exists
    if not os.path.exists(benchmark.mufiz_bin):
        print(f"Error: MufiZ binary not found at {benchmark.mufiz_bin}")
        print("Please run: zig build")
        sys.exit(1)
    
    # Run benchmarks
    results = benchmark.run_suite()
    
    # Save results
    benchmark.save_results(results)
    
    print("\n" + "=" * 60)
    print("Benchmark complete!")
    print("=" * 60)

if __name__ == "__main__":
    main()
