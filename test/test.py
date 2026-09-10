# SPDX-FileCopyrightText: (c) 2026 Vinutha S T
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


def make_ui_in(request, index, tag):
    # ui_in[0]=request, ui_in[2:1]=index, ui_in[6:3]=tag
    return (request & 0x1) | ((index & 0x3) << 1) | ((tag & 0xF) << 3)


async def do_access(dut, index, tag, mem_data):
    # Drive the address/data, pulse request for one cycle, then wait for done
    dut.ui_in.value = make_ui_in(1, index, tag)
    dut.uio_in.value = mem_data & 0x7F  # 7-bit data (top bit unused in this wrapper)
    await ClockCycles(dut.clk, 1)
    dut.ui_in.value = make_ui_in(0, index, tag)  # deassert request

    # Poll for done (uio_out bit 7) to go high, with a safety timeout
    for _ in range(20):
        await ClockCycles(dut.clk, 1)
        if (int(dut.uio_out.value) >> 7) & 0x1:
            break

    return int(dut.uo_out.value)


@cocotb.test()
async def test_cache_controller(dut):
    dut._log.info("Start")

    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)

    # Test 1: first access to a new address -> miss -> fetch -> store
    dut._log.info("Test 1: miss on new address")
    result = await do_access(dut, index=1, tag=3, mem_data=42)
    assert result == 42, f"Test 1 failed: expected 42, got {result}"

    # Test 2: repeat access to the same address -> hit
    dut._log.info("Test 2: hit on repeat access")
    result = await do_access(dut, index=1, tag=3, mem_data=42)
    assert result == 42, f"Test 2 failed: expected 42, got {result}"

    # Test 3: access a different address -> fresh miss, independent slot
    dut._log.info("Test 3: miss on different address")
    result = await do_access(dut, index=2, tag=5, mem_data=55)
    assert result == 55, f"Test 3 failed: expected 55, got {result}"

    # Test 4: same index as test 1, different tag -> must be a miss (index collision)
    dut._log.info("Test 4: miss despite index match (different tag)")
    result = await do_access(dut, index=1, tag=7, mem_data=76)
    assert result == 76, f"Test 4 failed: expected 76, got {result}"

    # Test 5: return to the original address (index=1, tag=3) after eviction -> miss again
    dut._log.info("Test 5: miss again after eviction, re-fetch original data")
    result = await do_access(dut, index=1, tag=3, mem_data=42)
    assert result == 42, f"Test 5 failed: expected 42, got {result}"

    dut._log.info("All 5 tests passed")
