"""Standalone forward butterfly checks against field arithmetic."""

import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer

Q = 8380417
R = 1 << 32


async def tick(dut):
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")


async def check_case(dut, a, b, zeta, stall_after_input):
    # ROM words contain the Montgomery representation of zeta.
    w = zeta * R % Q
    product = b * zeta % Q
    expected = ((a + product) % Q, (a - product) % Q)

    await FallingEdge(dut.clk)
    dut.rst.value = 1
    dut.valid_i.value = 0
    dut.stall.value = 0
    await tick(dut)

    await FallingEdge(dut.clk)
    dut.rst.value = 0
    dut.valid_i.value = 1
    dut.a_i.value = a
    dut.b_i.value = b
    dut.w.value = w
    await tick(dut)

    await FallingEdge(dut.clk)
    dut.valid_i.value = 0
    if stall_after_input:
        dut.stall.value = 1
        before = (int(dut.valid_out.value), int(dut.a_o.value), int(dut.b_o.value))
        for _ in range(3):
            await tick(dut)
            assert (int(dut.valid_out.value), int(dut.a_o.value), int(dut.b_o.value)) == before
        await FallingEdge(dut.clk)
        dut.stall.value = 0

    for _ in range(8):
        await tick(dut)
        if int(dut.valid_out.value):
            actual = (int(dut.a_o.value), int(dut.b_o.value))
            assert actual == expected, (a, b, zeta, actual, expected)
            return
        await FallingEdge(dut.clk)
    assert False, f"butterfly output timed out for {a=}, {b=}, {zeta=}"


@cocotb.test()
async def forward_butterfly(dut):
    dut.rst.value = 1
    dut.valid_i.value = 0
    dut.stall.value = 0
    dut.a_i.value = 0
    dut.b_i.value = 0
    dut.w.value = 0
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    cases = [
        (0, 0, 0),
        (Q - 1, Q - 1, 1),  # Addition carry and reduction.
        (0, Q - 1, 1),      # Subtraction borrow.
        (Q - 1, Q - 1, Q - 1),
        (1234567, 7654321, 1753),
    ]
    rng = random.Random(0x4E5454)
    cases.extend((rng.randrange(Q), rng.randrange(Q), rng.randrange(Q)) for _ in range(64))
    for index, (a, b, zeta) in enumerate(cases):
        await check_case(dut, a, b, zeta, stall_after_input=index % 7 == 0)


@cocotb.test()
async def consecutive_inputs(dut):
    dut.rst.value = 1
    dut.valid_i.value = 0
    dut.stall.value = 0
    dut.a_i.value = 0
    dut.b_i.value = 0
    dut.w.value = 0
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await tick(dut)

    rng = random.Random(0xB0773)
    inputs = [
        (rng.randrange(Q), rng.randrange(Q), rng.randrange(Q))
        if index % 9 != 7 else None
        for index in range(36)
    ]
    expected = []
    observed = 0
    for case in inputs + [None] * 6:
        await FallingEdge(dut.clk)
        dut.rst.value = 0
        dut.valid_i.value = case is not None
        if case is not None:
            a, b, zeta = case
            dut.a_i.value = a
            dut.b_i.value = b
            dut.w.value = zeta * R % Q
            product = b * zeta % Q
            expected.append(((a + product) % Q, (a - product) % Q))
        await tick(dut)
        if int(dut.valid_out.value):
            actual = (int(dut.a_o.value), int(dut.b_o.value))
            assert actual == expected[observed], (observed, actual, expected[observed])
            observed += 1
    assert observed == len(expected)
