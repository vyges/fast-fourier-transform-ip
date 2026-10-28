#!/usr/bin/env python3
"""FFT golden-model regression: the RTL against a bit-exact fixed-point reference.

    tb/golden/run_golden.py            build tb_fft_golden with Verilator, run every case
    tb/golden/run_golden.py CASE ...   run only the named cases
    tb/golden/run_golden.py --netlist  run against Yosys's synthesized netlist of fft_top instead
                                       of the RTL (checks that Yosys reads the RTL as intended)

For each case the reference model below computes the engine's documented arithmetic
(radix-2 DIF in place, Q1.15 butterflies, per-stage rescaling, natural-order output), the
testbench runs the same configuration through fft_top over APB, and the two are compared
word for word, together with the scale factor and overflow count. The model is itself
checked against a floating-point FFT: when no butterfly overflowed, its result divided by
the scale factor must match numpy's FFT to within fixed-point rounding.

Exit status: 0 when every case matches, 1 otherwise.
"""
import math
import random
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
BUILD = HERE / "build"
RTL = ["fft_fft_top.sv", "fft_fft_engine.sv", "fft_fft_control.sv",
       "fft_memory_interface.sv", "fft_bin_streamer.sv"]


def s16(v):
    v &= 0xFFFF
    return v - 0x10000 if v & 0x8000 else v


def near_full(v):
    """Outside [-2^13, 2^13): could grow past 16 bits in one stage."""
    return not (-8192 <= v < 8192)


def shift(v, k, rounding):
    return (v + ((1 << (k - 1)) if rounding and k > 0 else 0)) >> k


def fit(v, saturate):
    over = v > 32767 or v < -32768
    if saturate:
        return max(-32768, min(32767, v)), over
    return s16(v), over


def twiddles(n):
    """W_N^k = cos(2 pi k/N) - j sin(2 pi k/N) in Q1.15, as firmware loads them."""
    out = []
    for k in range(n // 2):
        c = round(math.cos(2 * math.pi * k / n) * 32767)
        s = round(math.sin(2 * math.pi * k / n) * 32767)
        out.append((c, -s))
    return out


def model(x, tw, log2n, rescale_on, divide_by_n, rounding, saturate, track, detect):
    """The engine's arithmetic. x: list of (re, im). Returns (bins, scale, overflows)."""
    n = 1 << log2n
    d = list(x)
    if rescale_on and divide_by_n:
        scaled = True
    elif rescale_on:
        scaled = any(near_full(c) for v in d for c in v)
    else:
        scaled = False
    scale = overflows = 0
    for s in range(log2n):
        half = n >> (s + 1)
        sh = 1 if scaled else 0
        guard = False
        for base in range(0, n, 2 * half):
            for j in range(half):
                ia, ib = base + j, base + j + half
                (ar, ai), (br, bi) = d[ia], d[ib]
                wr, wi = tw[j << s]
                dr, di = ar - br, ai - bi
                vals = [shift(ar + br, sh, rounding), shift(ai + bi, sh, rounding),
                        shift(dr * wr - di * wi, 15 + sh, rounding),
                        shift(dr * wi + di * wr, 15 + sh, rounding)]
                fitted = [fit(v, saturate) for v in vals]
                out = [f[0] for f in fitted]
                if detect and any(f[1] for f in fitted):
                    overflows = min(255, overflows + 1)
                guard |= any(near_full(v) for v in out)
                d[ia] = (out[0], out[1])
                d[ib] = (out[2], out[3])
        if scaled and track:
            scale += 1
        scaled = rescale_on and (divide_by_n or guard)
    rev = [int(format(i, f"0{log2n}b")[::-1], 2) for i in range(n)]
    return [d[rev[i]] for i in range(n)], scale, overflows


# name: (log2n, input kind, amplitude, rescale_en, mode1, rounding, saturate, detect, track)
CASES = {
    "n8_small_plain":        (3,  "complex", 1000,  0, 0, 0, 0, 0, 0),
    "n16_impulse":           (4,  "impulse", 20000, 0, 0, 0, 1, 1, 0),
    "n256_small_round_sat":  (8,  "complex", 1000,  0, 0, 1, 1, 1, 0),
    "n256_full_rescale":     (8,  "complex", 32767, 1, 0, 0, 1, 1, 1),
    "n512_mid_rescale_rnd":  (9,  "complex", 6000,  1, 0, 1, 1, 1, 1),
    "n1024_firmware_sine":   (10, "sine",    20000, 1, 0, 0, 1, 1, 1),
    "n1024_divide_by_n":     (10, "complex", 32767, 1, 1, 1, 1, 1, 1),
    "n1024_wrap_overflow":   (10, "complex", 32767, 0, 0, 0, 0, 1, 0),
}


def inputs(kind, n, amp, rng):
    if kind == "impulse":
        return [(amp, 0)] + [(0, 0)] * (n - 1)
    if kind == "sine":  # real-valued, imag = 0, as the firmware loads ADC samples
        return [(int(amp * math.sin(2 * math.pi * 37 * i / n)) + rng.randint(-200, 200), 0)
                for i in range(n)]
    return [(rng.randint(-amp, amp), rng.randint(-amp, amp)) for _ in range(n)]


DEFINES = ["FFT_USE_APB_DATA", "FFT_USE_STREAM_OUT"]


def synthesize():
    """fft_top through Yosys, flattened to generic gates, as a Verilog netlist."""
    out = BUILD / "fft_top.netlist.v"
    defs = " ".join(f"-D{d}" for d in DEFINES)
    files = " ".join(str(ROOT / "rtl" / f) for f in RTL)
    script = (f"read_verilog -sv -DYOSYS_SYNTHESIS {defs} -I{ROOT / 'rtl'} {files}; "
              f"chparam -set FFT_MAX_LENGTH_LOG2 10 fft_top; synth -top fft_top -flatten; "
              f"write_verilog -noattr {out}")
    r = subprocess.run(["yosys", "-q", "-p", script], capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f"yosys failed:\n{r.stdout[-3000:]}\n{r.stderr[-3000:]}")
    return [str(out)]


def build(netlist):
    exe = BUILD / "obj" / "Vtb_fft_golden"
    BUILD.mkdir(parents=True, exist_ok=True)
    dut = synthesize() if netlist else [str(ROOT / "rtl" / f) for f in RTL]
    cmd = ["verilator", "--binary", "--timing", "-Wno-fatal", "-Wno-lint", "-Wno-style",
           f"-I{ROOT / 'rtl'}", "+define+" + "+".join(DEFINES + (["GOLDEN_NETLIST"] if netlist else [])),
           "--top-module", "tb_fft_golden", "-Mdir", str(BUILD / "obj"),
           str(HERE / "tb_fft_golden.sv")] + dut
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f"verilator build failed:\n{r.stdout[-3000:]}\n{r.stderr[-3000:]}")
    return exe


def run_case(exe, name, spec):
    log2n, kind, amp, ren, mode1, rnd, sat, det, track = spec
    n = 1 << log2n
    rng = random.Random(name)  # the same inputs whichever cases run
    cdir = BUILD / "cases" / name
    shutil.rmtree(cdir, ignore_errors=True)
    cdir.mkdir(parents=True)
    x = inputs(kind, n, amp, rng)
    tw = twiddles(n)
    cfg = log2n | (mode1 << 16) | (rnd << 17) | (sat << 18) | (det << 19)
    ctrl = (ren << 4) | (track << 5) | (1 << 8)
    (cdir / "config.hex").write_text(f"{log2n:08x}\n{cfg:08x}\n{ctrl:08x}\n")
    (cdir / "twiddle.hex").write_text("".join(f"{(c & 0xFFFF) << 16 | (s & 0xFFFF):08x}\n" for c, s in tw))
    (cdir / "input.hex").write_text("".join(f"{(i & 0xFFFF) << 16 | (r & 0xFFFF):08x}\n" for r, i in x))

    want, want_scale, want_ovf = model(x, tw, log2n, bool(ren and det), bool(mode1), bool(rnd),
                                       bool(sat), bool(track), bool(det))
    r = subprocess.run([str(exe), f"+case={cdir}"], capture_output=True, text=True, timeout=600)
    problems = []
    if r.returncode != 0:
        problems.append(f"simulation exit {r.returncode}: {r.stdout[-500:]}")
    status = dict(line.split() for line in (cdir / "status.txt").read_text().splitlines())
    got = []
    for line in (cdir / "output.hex").read_text().split():
        w = int(line, 16)
        got.append((s16(w), s16(w >> 16)))
    diffs = [i for i in range(n) if got[i] != want[i]]
    if diffs:
        i = diffs[0]
        problems.append(f"{len(diffs)} bins differ; first bin {i}: rtl {got[i]} model {want[i]}")
    if int(status["scale_factor"]) != want_scale:
        problems.append(f"scale factor rtl {status['scale_factor']} model {want_scale}")
    if int(status["overflow_count"]) != want_ovf:
        problems.append(f"overflow count rtl {status['overflow_count']} model {want_ovf}")
    if int(status["tb_errors"]):
        problems.append(f"testbench reported {status['tb_errors']} errors: {r.stdout.strip()[-800:]}")

    # The model is an FFT: compare with numpy where nothing overflowed.
    note = ""
    if want_ovf == 0:
        ref = np.fft.fft(np.array([complex(a, b) for a, b in x])) / (2 ** want_scale)
        mdl = np.array([complex(a, b) for a, b in want])
        err = np.max(np.abs(mdl - ref))
        bound = 2.0 * log2n + 2.0  # about one LSB per stage plus the twiddle quantisation
        if not want_scale:
            bound += np.max(np.abs(ref)) * log2n * 2.0 ** -15
        note = f", |model - float FFT| <= {err:.2f} LSB"
        if err > bound:
            problems.append(f"model differs from the float FFT by {err:.1f} LSB (bound {bound:.1f})")
    print(f"{'PASS' if not problems else 'FAIL'}  {name}: N={n}, scale {want_scale}, "
          f"overflows {want_ovf}, {status['cycles']} cycles{note}")
    for p in problems:
        print(f"      {p}")
    return not problems


def main():
    args = sys.argv[1:]
    netlist = "--netlist" in args
    names = [a for a in args if a != "--netlist"] or list(CASES)
    unknown = [c for c in names if c not in CASES]
    if unknown:
        sys.exit(f"unknown cases {unknown}; known: {list(CASES)}")
    exe = build(netlist)
    ok = all([run_case(exe, c, CASES[c]) for c in names])
    print("all cases match" if ok else "MISMATCH")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
