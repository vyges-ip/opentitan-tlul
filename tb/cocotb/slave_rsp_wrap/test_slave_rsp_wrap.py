"""
tlul_slave_rsp_intg_wrap — cocotb unit regression.

Verifies that the wrap module regenerates d_user.rsp_intg / data_intg
correctly so that a downstream tlul_rsp_intg_chk accepts the response
on a range of baseline-slave stimuli.

Each test drives a different (d_opcode, d_source, d_data, d_error)
tuple. For each:

  - err_signed_o   MUST stay 0  (DUT signed the response, oracle accepts)
  - err_baseline_o MUST be 1    (same payload, unsigned — oracle rejects,
                                 proving the oracle is actually checking)

The negative-control assertion is the important one: without it, a
wrap that just passes `d_user` through unchanged would also make
err_signed stay 0 (the checker would also see rsp_intg=0 in both
paths and raise err_o on both). Requiring err_baseline=1 forces the
oracle to distinguish signed from unsigned.
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


# TL-UL d_opcode encoding (tlul_pkg::tl_d_op_e)
ACCESS_ACK      = 0
ACCESS_ACK_DATA = 1


async def _reset(dut):
    """The DUT is combinational, but we run a clock for cocotb cadence."""
    cocotb.start_soon(Clock(dut.clk_i, 10, units="ns").start())
    dut.rst_ni.value = 0
    dut.d_valid_i.value = 0
    dut.d_opcode_i.value = 0
    dut.d_source_i.value = 0
    dut.d_data_i.value = 0
    dut.d_error_i.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk_i)
    dut.rst_ni.value = 1
    await RisingEdge(dut.clk_i)


async def _drive_and_check(dut, opcode, source, data, error, label):
    """Drive one baseline response, assert both oracles."""
    dut.d_valid_i.value  = 1
    dut.d_opcode_i.value = opcode
    dut.d_source_i.value = source
    dut.d_data_i.value   = data
    dut.d_error_i.value  = error
    # Combinational path — settle, then sample.
    await Timer(1, units="ns")
    err_signed   = int(dut.err_signed_o.value)
    err_baseline = int(dut.err_baseline_o.value)
    dut._log.info(
        f"[{label}] opcode={opcode} source=0x{source:02x} data=0x{data:08x} "
        f"error={error} → err_signed={err_signed} err_baseline={err_baseline}"
    )
    assert err_signed == 0, (
        f"[{label}] DUT output FAILED the signed oracle (err_signed=1). "
        "The wrap is not regenerating d_user.rsp_intg/data_intg correctly."
    )
    assert err_baseline == 1, (
        f"[{label}] baseline oracle did NOT flag the unsigned input "
        "(err_baseline=0). Either d_valid_i didn't propagate, or the "
        "baseline response accidentally has non-zero d_user — the test "
        "is not actually exercising the unsigned path."
    )
    # Deassert and settle so the quiet-state check below is clean.
    dut.d_valid_i.value = 0
    await Timer(1, units="ns")


@cocotb.test()
async def test_wrap_signs_read_responses(dut):
    """AccessAckData with varying data patterns — the common read-response case."""
    await _reset(dut)
    for data in (0x00000000, 0xFFFFFFFF, 0xDEADBEEF, 0xA5A5A5A5, 0x12345678):
        await _drive_and_check(
            dut,
            opcode=ACCESS_ACK_DATA,
            source=0x10,
            data=data,
            error=0,
            label=f"read data=0x{data:08x}",
        )


@cocotb.test()
async def test_wrap_signs_write_acks(dut):
    """AccessAck (write ack) — d_data is don't-care but must still sign."""
    await _reset(dut)
    for source in (0x00, 0x01, 0x7F, 0xFF):
        await _drive_and_check(
            dut,
            opcode=ACCESS_ACK,
            source=source,
            data=0,
            error=0,
            label=f"write ack source=0x{source:02x}",
        )


@cocotb.test()
async def test_wrap_signs_error_responses(dut):
    """d_error=1 — rsp_intg must cover d_error, so the signed payload changes."""
    await _reset(dut)
    await _drive_and_check(
        dut,
        opcode=ACCESS_ACK,
        source=0x42,
        data=0,
        error=1,
        label="error response",
    )


@cocotb.test()
async def test_wrap_quiet_when_not_valid(dut):
    """With d_valid=0 both oracles must stay quiet — rsp_intg_chk gates on d_valid."""
    await _reset(dut)
    dut.d_valid_i.value = 0
    dut.d_opcode_i.value = ACCESS_ACK_DATA
    dut.d_data_i.value   = 0xDEADBEEF
    await Timer(1, units="ns")
    assert int(dut.err_signed_o.value)   == 0, "err_signed asserted with d_valid=0"
    assert int(dut.err_baseline_o.value) == 0, "err_baseline asserted with d_valid=0"
