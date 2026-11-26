"""End-to-end check against the Dilithium C NTT output in vectors.csv."""

import csv
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer

N = 256
Q = 8380417
PAIRS = N // 2
INDEX_BITS = N.bit_length() - 1
MAX_WAIT_CYCLES = 3000
CSV_PATH = Path(__file__).resolve().parent / "vectors.csv"


def bit_reverse(index):
    result = 0
    for _ in range(INDEX_BITS):
        result = (result << 1) | (index & 1)
        index >>= 1
    return result


def load_vectors():
    vectors = {0: {"input": [], "expected": []}, 1: {"input": [], "expected": []}}
    with CSV_PATH.open(newline="", encoding="utf-8") as file:
        for row in csv.DictReader(file):
            vector = int(row["vector"])
            index = int(row["index"])
            assert vector in vectors and index == len(vectors[vector]["input"]), row
            vectors[vector]["input"].append(int(row["input"]))
            vectors[vector]["expected"].append(int(row["expected"]))
    assert all(len(v["input"]) == N for v in vectors.values())
    return vectors


async def tick(dut):
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")  # Let registered RTL outputs settle.


async def reset(dut):
    dut.valid_i.value = 0
    dut.stall_i.value = 0
    dut.a_i.value = 0
    dut.b_i.value = 0
    dut.rst.value = 1
    for _ in range(4):
        await tick(dut)
    await FallingEdge(dut.clk)
    dut.rst.value = 0


async def run_vector(dut, number, vector):
    inputs = vector["input"]
    expected = vector["expected"]
    observed = []
    started = False

    # Feed the bit-reversed input stream in consecutive lane pairs:
    # (x_0, x_128), (x_64, x_192), (x_32, x_160), ...
    for cycle in range(MAX_WAIT_CYCLES):
        await FallingEdge(dut.clk)
        if cycle < PAIRS:
            dut.valid_i.value = 1
            dut.a_i.value = inputs[bit_reverse(2 * cycle)]
            dut.b_i.value = inputs[bit_reverse(2 * cycle + 1)]
        else:
            dut.valid_i.value = 0
            dut.a_i.value = 0
            dut.b_i.value = 0

        await tick(dut)
        if int(dut.valid_o.value):
            started = True
            if len(observed) >= N:
                return f"vector {number}: extra valid output pair"
            for lane in (dut.a_o, dut.b_o):
                try:
                    observed.append(int(lane.value))
                except ValueError:
                    observed.append(None)
        elif started and len(observed) == N:
            break

    if len(observed) != N:
        return (
            f"vector {number}: received {len(observed)}/{N} coefficients "
            f"before the {MAX_WAIT_CYCLES}-cycle timeout"
        )

    # The C NTT uses lazy signed reduction. Compare canonical field residues.
    # Output pairs are consecutive: (y_0, y_1), (y_2, y_3), ...
    # The C reference array is already in its NTT output order.
    mismatches = [
        (i, observed[i], expected[i] % Q)
        for i in range(N)
        if observed[i] is None or observed[i] % Q != expected[i] % Q
    ]
    if mismatches:
        examples = ", ".join(
            f"index {i}: RTL={actual}, C mod Q={wanted}"
            for i, actual, wanted in mismatches[:8]
        )
        return (
            f"vector {number}: {len(mismatches)}/{N} mismatches; {examples}. "
            "An RTL value of None means an unresolved output bit."
        )
    return None


@cocotb.test()
async def compare_c_reference(dut):
    vectors = load_vectors()
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    failures = []
    for number, vector in vectors.items():
        await reset(dut)
        failure = await run_vector(dut, number, vector)
        if failure:
            failures.append(failure)
    assert not failures, "\n".join(failures)


async def run_consecutive_frames(dut, with_gaps_and_stalls):
    vectors = load_vectors()
    inputs = [
        (vector["input"][bit_reverse(2 * pair)],
         vector["input"][bit_reverse(2 * pair + 1)])
        for vector in vectors.values()
        for pair in range(PAIRS)
    ]
    expected = [
        value % Q
        for vector in vectors.values()
        for value in vector["expected"]
    ]

    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)
    sent = 0
    observed = []
    for cycle in range(6000):
        await FallingEdge(dut.clk)
        stall = with_gaps_and_stalls and cycle % 29 in (11, 12, 13)
        gap = with_gaps_and_stalls and cycle % 17 == 5
        send = sent < len(inputs) and not stall and not gap
        dut.stall_i.value = int(stall)
        dut.valid_i.value = int(send)
        if send:
            dut.a_i.value, dut.b_i.value = inputs[sent]
            sent += 1
        await tick(dut)
        if not stall and int(dut.valid_o.value):
            observed.extend((int(dut.a_o.value), int(dut.b_o.value)))
            assert len(observed) <= len(expected), "extra output pair"
            assert observed[-2:] == expected[len(observed)-2:len(observed)], (
                cycle, len(observed), observed[-2:],
                expected[len(observed)-2:len(observed)]
            )
        if sent == len(inputs) and len(observed) == len(expected):
            for _ in range(20):
                await FallingEdge(dut.clk)
                dut.valid_i.value = 0
                dut.stall_i.value = 0
                await tick(dut)
                assert not int(dut.valid_o.value), "extra output after both frames"
            return
    assert False, f"received {len(observed)}/{len(expected)} coefficients"


@cocotb.test()
async def consecutive_frames(dut):
    await run_consecutive_frames(dut, with_gaps_and_stalls=False)


@cocotb.test()
async def consecutive_frames_with_gaps_and_stalls(dut):
    await run_consecutive_frames(dut, with_gaps_and_stalls=True)
