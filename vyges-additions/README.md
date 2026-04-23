# Vyges additions — opentitan-tlul

This directory contains **Vyges-authored** modules that are *not* part of
the upstream `lowRISC/opentitan` mirror. They are:

- Net-new files (no path collision with `rtl/`).
- Excluded from upstream-sync pulls.
- Declared in `vyges-metadata.json` under `vyges_additions[]` so the
  Vyges SoC Generator picks them up alongside the upstream `rtl/` files.

The separate `rtl/` tree is a pristine mirror of upstream and is never
modified here — upstream divergence is captured in a different
directory (`vyges-overlays/`, when present).

## When to use these modules

The Vyges catalog composes IPs from multiple upstreams onto a single
TL-UL bus. OpenTitan-heritage slaves (e.g. `uart_reg_top`) generate
their own response integrity via internal `tlul_rsp_intg_gen`
instances; Vyges "lite" IPs (`vyges-spi-host-lite`,
`vyges-rv-plic-lite`, etc.) and several non-OpenTitan upstreams do
not. We call these two protocol levels **signed** and **baseline**
respectively.

A signed crossbar (one whose upstream host runs the always-on
`tlul_rsp_intg_chk` — which is the case for `opentitan-rv-core-ibex`
and every TL-UL IP that inherits from `tlul_adapter_host`) traps on
the first response it receives from a baseline slave whose
`d_user.rsp_intg` is all zero. The same rule applies in reverse:
every master on a signed bus must sign its requests, or the slaves'
`tlul_cmd_intg_chk` traps.

The wrappers in this directory make signing a single-line integration
decision at the SoC composition layer, not a per-IP RTL change:

| Direction | Wrap module | When to instantiate |
|---|---|---|
| Baseline slave → signed xbar | `tlul_slave_rsp_intg_wrap` | A baseline TL-UL slave is attached to a crossbar whose upstream host runs `tlul_rsp_intg_chk`. Instantiate between the xbar's slave port and the baseline slave. |
| Baseline master → signed xbar | `tlul_master_cmd_intg_wrap` | A baseline TL-UL master (e.g. debug-module SBA port) is attached to a crossbar whose downstream slaves run `tlul_cmd_intg_chk`. Instantiate between the baseline master and the xbar's host port. |

## Example wiring — baseline slave on a signed xbar

```systemverilog
// Baseline slave: vyges-spi-host-lite drives tl_o.d_user = '0
tl_h2d_t xbar_to_spi_h2d;    // from xbar's slave port
tl_d2h_t spi_baseline_d2h;   // unsigned response from spi_host_lite

tl_h2d_t spi_inner_h2d;      // request forwarded into the spi_host_lite core
tl_d2h_t spi_signed_d2h;     // signed response back to the xbar

tlul_slave_rsp_intg_wrap u_spi_sig (
  .tl_host_i  (xbar_to_spi_h2d),
  .tl_host_o  (spi_signed_d2h),
  .tl_slave_o (spi_inner_h2d),
  .tl_slave_i (spi_baseline_d2h)
);

spi_host_lite u_spi (
  .tl_i (spi_inner_h2d),
  .tl_o (spi_baseline_d2h),
  // ...
);

// xbar connects to xbar_to_spi_h2d / spi_signed_d2h
```

## Upgrade path

When a baseline IP adopts native signing (adds its own
`tlul_rsp_intg_gen` internally), its vyges-metadata.json flips the
interface's `protocol_level` from `baseline` to `signed` and the
Vyges SoC Generator drops the wrap at the next regen. The SoC-level
RTL sees no other change.

## Why additions, not overlays

These files are **new** — they do not modify any upstream file. They
live in `vyges-additions/` so that:

- Upstream pulls never touch them.
- A reviewer can tell at a glance which RTL came from upstream and
  which from Vyges.
- The Vyges SoC Generator resolves them through the catalog metadata
  (`vyges_additions[]`) rather than a parallel patches directory.

Upstream-sync policy: pulls from `lowRISC/opentitan` proceed normally.
Any upstream change to a path that is also listed in
`vyges_overlays[].replaces` (when overlays exist in a given repo) is
flagged in the sync report for human review — upstream may have fixed
the original issue natively, making the overlay obsolete. This policy
is documented in `upstream.yaml`.

## Related Vyges documentation

The broader architectural contract — "buses are signed or baseline,
IPs declare `protocol_level` per interface, the generator enforces
matching at SoC composition time" — is documented in the Vyges SoC
Generator's bus-security-domain work item. These wraps are the
primitive building blocks that generator-time enforcement emits.
