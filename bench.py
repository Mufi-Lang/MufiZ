import os
import subprocess
import time

def run_benchmark(executable, file_path):
    try:
        start_time = time.perf_counter()
        result = subprocess.run([executable, "-r", file_path], capture_output=True, text=True, timeout=30)
        end_time = time.perf_counter()
        
        if result.returncode != 0:
            return None
        
        return end_time - start_time
    except Exception:
        return None

def main():
    installed_mufiz = "mufiz"
    experimental_mufiz = "./zig-out/bin/mufiz"
    programs_dir = "Epoch1/programs"
    
    if not os.path.exists(experimental_mufiz):
        print(f"Error: Experimental binary not found at {experimental_mufiz}")
        return

    mufi_files = []
    for root, _, files in os.walk(programs_dir):
        for file in files:
            if file.endswith(".mufi"):
                mufi_files.append(os.path.join(root, file))
                if len(mufi_files) >= 100:
                    break
        if len(mufi_files) >= 100:
            break
    
    if not mufi_files:
        print("No .mufi files found in Epoch1/programs")
        return

    results = []
    print(f"🚀 Starting benchmark on {len(mufi_files)} programs...")
    
    installed_total = 0
    experimental_total = 0
    valid_count = 0

    for file in mufi_files:
        t_inst = run_benchmark(installed_mufiz, file)
        t_exp = run_benchmark(experimental_mufiz, file)
        
        if t_inst is not None and t_exp is not None:
            results.append({
                "file": os.path.basename(file),
                "installed": t_inst,
                "experimental": t_exp,
                "diff": (t_exp - t_inst) / t_inst * 100
            })
            installed_total += t_inst
            experimental_total += t_exp
            valid_count += 1

    results.sort(key=lambda x: x["file"])

    print("\n## Benchmark Results\n")
    print("| Program | Installed (s) | Experimental (s) | Improvement (%) |")
    print("| :--- | :---: | :---: | :---: |")
    
    for r in results:
        improvement = -r["diff"]
        print(f"| {r['file']} | {r['installed']:.4f} | {r['experimental']:.4f} | {improvement:+.2f}% |")

    print("\n### Final Scores (Total Execution Time)")
    print(f"**Installed Score:** {installed_total:.4f}")
    print(f"**Experimental Score:** {experimental_total:.4f}")
    
    overall_diff = (experimental_total - installed_total) / installed_total * 100
    if overall_diff < 0:
        print(f"\n✅ Experimental is faster by {abs(overall_diff):.2f}%")
    else:
        print(f"\n⚠️  Experimental is slower by {overall_diff:.2f}%")

    with open("benchmark_results.md", "w") as f:
        f.write("# MufiZ Benchmark Suite Results\n\n")
        f.write(f"Run Date: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"Total Programs Run: {valid_count}\n\n")
        f.write("| Program | Installed (s) | Experimental (s) | Improvement (%) |\n")
        f.write("| :--- | :---: | :---: | :---: |\n")
        for r in results:
            improvement = -r["diff"]
            f.write(f"| {r['file']} | {r['installed']:.4f} | {r['experimental']:.4f} | {improvement:+.2f}% |\n")
        f.write(f"\n### Summary\n")
        f.write(f"- **Installed Total Time (Score):** {installed_total:.4f}\n")
        f.write(f"- **Experimental Total Time (Score):** {experimental_total:.4f}\n")
        f.write(f"- **Overall Change:** {overall_diff:+.2f}%\n")

if __name__ == "__main__":
    main()