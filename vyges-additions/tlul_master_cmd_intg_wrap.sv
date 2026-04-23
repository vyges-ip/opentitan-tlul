// Copyright (c) 2026 Vyges Inc. All rights reserved.
// Licensed under the Apache License, Version 2.0. See LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// tlul_master_cmd_intg_wrap
//
// Drop-in signing wrapper for baseline TL-UL masters attached to a signed
// TL-UL bus. Instantiate this between a baseline master (one that drives
// tl_o.a_user.cmd_intg='0 and tl_o.a_user.data_intg='0) and a signed
// crossbar whose slaves run tlul_cmd_intg_chk on every incoming packet.
//
// Without this wrap, the baseline master's all-zero integrity fields
// fail the always-on command-integrity decoder at each slave and the
// first request traps — the dual of the slave-side wrapper. Common case:
// a debug-module system-bus-access (SBA) master originating on a signed
// xbar.
//
// Request path (h2d) is rewritten with correct cmd_intg and data_intg
// via tlul_cmd_intg_gen. Response path (d2h) is a pass-through; the
// baseline master expects the xbar's signed response to pass its own
// response-integrity check (it should — the signed slave produced it).
//
// Companion module: tlul_slave_rsp_intg_wrap (for baseline slaves on a
// signed bus).
//
// See vyges-additions/README.md for when to instantiate which wrap.

`include "prim_assert.sv"

module tlul_master_cmd_intg_wrap import tlul_pkg::*; (
  // baseline-master-side (upstream, unsigned)
  input  tl_h2d_t tl_master_i,  // request from the baseline master
  output tl_d2h_t tl_master_o,  // response passed through to the master

  // xbar-side (downstream, signed domain)
  output tl_h2d_t tl_xbar_o,    // signed request forwarded to the xbar
  input  tl_d2h_t tl_xbar_i     // signed response from the xbar
);

  // Regenerate cmd_intg + data_intg on every outgoing request.
  // EnableDataIntgGen defaults to 1 so writes carry a fresh data-integrity
  // SECDED code; reads include a code over a_data even if slaves ignore it.
  tlul_cmd_intg_gen #(
    .EnableDataIntgGen (1'b1)
  ) u_cmd_gen (
    .tl_i (tl_master_i),
    .tl_o (tl_xbar_o)
  );

  // Response pass-through. Baseline masters that don't run their own
  // rsp_intg_chk simply ignore the d_user integrity fields; masters that
  // do run one get the signed response directly and will pass.
  assign tl_master_o = tl_xbar_i;

endmodule
