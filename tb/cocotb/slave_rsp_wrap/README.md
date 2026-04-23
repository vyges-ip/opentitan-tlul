# tlul_slave_rsp_intg_wrap — cocotb unit regression

Self-contained cocotb + Verilator regression for
`vyges-additions/tlul_slave_rsp_intg_wrap`.

## What it tests

The wrap module sits between a baseline TL-UL slave (drives `d_user = '0`)
and a signed host. It must regenerate `d_user.rsp_intg` + `data_intg` so
that a downstream `tlul_rsp_intg_chk` accepts the response.

For each stimulus (read data response, write ack, error response, idle),
the harness wires two oracles:

- **Signed path**: `tlul_rsp_intg_chk` consumes the DUT's `tl_host_o`.
  Must report `err_o == 0`.
- **Negative control**: a second `tlul_rsp_intg_chk` consumes the
  baseline input directly (bypassing the DUT). Must report `err_o == 1`
  on any `d_valid` cycle — this proves the oracle actually checks, so
  the signed-path assertion above is meaningful.

## Prerequisites

- Verilator ≥ 5.000
- Python ≥ 3.9, cocotb 1.9.2
- A sibling directory containing vendored `opentitan-prim` +
  `opentitan-prim-generic` (for `prim_secded_inv_64_57_{enc,dec}` and
  friends). Point the Makefile at it via `LOCAL_IPS=<path>` if the
  default doesn't apply to your host.

## Run

```bash
make
```

or, if your vendored IPs live elsewhere:

```bash
make LOCAL_IPS=/path/to/local-ips
```

Wave dump (FST is more compact than VCD; both open in gtkwave):

```bash
make WAVES=vcd
```

## Pass criteria

All four cocotb tests pass:

- `test_wrap_signs_read_responses` — 5 read-data patterns
- `test_wrap_signs_write_acks`     — 4 source IDs
- `test_wrap_signs_error_responses` — d_error=1 case
- `test_wrap_quiet_when_not_valid` — d_valid=0 leaves both oracles quiet

## Related

- `vyges-additions/tlul_slave_rsp_intg_wrap.sv` — the DUT
- `vyges-additions/README.md` — when to instantiate which wrap
- Vyges SoC Generator `_bus_security_default` + `_slave_needs_wrap`
  decide when to emit this wrap at SoC composition time.
