import os
import subprocess
import time


def run_benchmark(executable, file_path):
    try:
        start_time = time.perf_counter()
        result = subprocess.run(
            [executable, "-r", file_path], capture_output=True, text=True, timeout=30
        )
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
                # Exclude known outliers or problematic files
                # if any(x in file for x in ["prog_42672.mufi", "prog_89776.mufi", "prog_14012.mufi"]):
                #     continue
                mufi_files.append(os.path.join(root, file))

    if not mufi_files:
        print("No .mufi files found in Epoch1/programs")
        return

    mufi_files.sort()
    # Benchmark a stable sample of 100 programs
    mufi_files = mufi_files[:10000]

    results = []
    print(f"🚀 Starting benchmark on {len(mufi_files)} programs (best of 5)...")
    installed_total = 0
    experimental_total = 0
    valid_count = 0
    for file in mufi_files:
        t_inst_list = []
        for _ in range(5):
            t = run_benchmark(installed_mufiz, file)
            if t is not None:
                t_inst_list.append(t)
        t_exp_list = []
        for _ in range(5):
            t = run_benchmark(experimental_mufiz, file)
            if t is not None:
                t_exp_list.append(t)

        if t_inst_list and t_exp_list:
            t_inst = min(t_inst_list)
            t_exp = min(t_exp_list)
            results.append(
                {
                    "file": os.path.basename(file),
                    "installed": t_inst,
                    "experimental": t_exp,
                    "diff": (t_exp - t_inst) / t_inst * 100,
                }
            )
            installed_total += t_inst
            experimental_total += t_exp
            valid_count += 1

    results.sort(key=lambda x: x["file"])
    print("## Benchmark Results")
    print("| Program | Installed (s) | Experimental (s) | Improvement (%) |")
    print("| :--- | :---: | :---: | :---: |")
    for r in results:
        improvement = -r["diff"]
        print(
            f"| {r['file']} | {r['installed']:.4f} | {r['experimental']:.4f} | {improvement:+.2f}% |"
        )
    print("### Final Scores (Total Execution Time)")
    print(f"**Installed Score:** {installed_total:.4f}")
    print(f"**Experimental Score:** {experimental_total:.4f}")
    overall_diff = (experimental_total - installed_total) / installed_total * 100
    if overall_diff < 0:
        print(f"✅ Experimental is faster by {abs(overall_diff):.2f}%")
    else:
        print(f"⚠️  Experimental is slower by {overall_diff:.2f}%")


if __name__ == "__main__":
    main()
