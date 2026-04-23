// Copyright (c) 2026 Vyges Inc. All rights reserved.
// Licensed under the Apache License, Version 2.0. See LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// tlul_slave_rsp_intg_wrap
//
// Drop-in signing wrapper for baseline TL-UL slaves attached to a signed
// TL-UL bus. Instantiate this between a baseline slave (one that drives
// tl_o.d_user='0) and a signed crossbar (one whose upstream host runs
// tlul_rsp_intg_chk, e.g. opentitan-rv-core-ibex via tlul_adapter_host).
//
// Without this wrap, the baseline slave's all-zero d_user.rsp_intg fails
// the always-on response-integrity decoder at the host side and the CPU
// traps silently on first access — the "bus security domain mismatch"
// class of bug.
//
// Request path (h2d) is a pass-through; the xbar has already driven the
// a_user fields that downstream slaves either ignore (baseline) or check
// (signed). Response path (d2h) is rewritten with correct rsp_intg and
// data_intg via tlul_rsp_intg_gen configured for baseline input.
//
// Companion module: tlul_master_cmd_intg_wrap (for baseline masters on
// a signed bus).
//
// See vyges-additions/README.md for when to instantiate which wrap, and
// the Vyges bus-security-domain contract in the Vyges SoC Generator docs
// for how generator-time enforcement works.

`include "prim_assert.sv"

module tlul_slave_rsp_intg_wrap import tlul_pkg::*; (
  // xbar-side (upstream, signed domain)
  input  tl_h2d_t tl_host_i,   // request from xbar to the wrapped slave
  output tl_d2h_t tl_host_o,   // signed response back to xbar

  // baseline-slave-side (downstream)
  output tl_h2d_t tl_slave_o,  // request forwarded to the baseline slave
  input  tl_d2h_t tl_slave_i   // unsigned response from the baseline slave
);

  // Request pass-through. Baseline slaves either ignore a_user integrity
  // fields or check them themselves; the xbar already put integrity in place.
  assign tl_slave_o = tl_host_i;

  // Regenerate rsp_intg + data_intg from the baseline slave's response.
  // UserInIsZero=1 tells the generator the slave's d_user fields are all
  // zeros (the baseline convention); EnableRspIntgGen/EnableDataIntgGen
  // default to 1 so both fields get freshly computed SECDED codes.
  tlul_rsp_intg_gen #(
    .EnableRspIntgGen  (1'b1),
    .EnableDataIntgGen (1'b1),
    .UserInIsZero      (1'b1)
  ) u_rsp_gen (
    .tl_i (tl_slave_i),
    .tl_o (tl_host_o)
  );

endmodule
