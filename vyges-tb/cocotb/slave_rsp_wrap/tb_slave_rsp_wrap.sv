// SPDX-License-Identifier: Apache-2.0
//
// tb_slave_rsp_wrap
//
// Unit testbench for vyges-additions/tlul_slave_rsp_intg_wrap.
//
// The DUT sits between a baseline TL-UL slave (drives d_user = '0) and a
// signed crossbar / host. Its job is to regenerate d_user.rsp_intg +
// data_intg so that a downstream tlul_rsp_intg_chk accepts the response.
//
// This TB composes:
//
//                     ┌──────────────────┐
//   baseline          │                  │        signed
//   response ────────►│ tlul_slave_rsp_  ├────────► tl_host_o
//   (d_user='0)       │   intg_wrap      │
//                     │     (DUT)        │
//                     └──────────────────┘
//                                   │
//                                   ▼
//                        ┌───────────────────┐
//                        │ tlul_rsp_intg_chk │  (signed path oracle)
//                        └─────────┬─────────┘
//                                  ▼ err_signed_o
//
// Negative control: a second tlul_rsp_intg_chk fed the baseline response
// directly, bypassing the DUT. It should trip `err_baseline_o` on the same
// stimulus — proving the checker actually checks and the DUT's signing is
// what flips it off.
//
// Cocotb drives the flat response fields (d_valid, d_opcode, d_data,
// d_source, d_error) and observes the two err_o flags.

`timescale 1ns/1ps

module tb_slave_rsp_wrap
  import tlul_pkg::*;
(
  input  logic        clk_i,       // cocotb needs a clock for await RisingEdge()
  input  logic        rst_ni,      // unused (DUT + checkers are combinational)

  // Baseline-slave response — driven unsigned by cocotb
  input  logic        d_valid_i,
  input  logic [2:0]  d_opcode_i,  // AccessAck=0, AccessAckData=1
  input  logic [7:0]  d_source_i,
  input  logic [31:0] d_data_i,
  input  logic        d_error_i,

  // Oracle outputs — observed by cocotb
  output logic        err_signed_o,    // 0 when wrap signs correctly
  output logic        err_baseline_o   // 1 when baseline-unsigned d_valid asserted (proof oracle works)
);

  // ── Host-side request (tied off; DUT passes through combinationally) ──
  tl_h2d_t tl_host_i;
  tl_d2h_t tl_host_o;
  tl_h2d_t tl_slave_o;
  tl_d2h_t tl_slave_i;

  assign tl_host_i = TL_H2D_DEFAULT;

  // ── Baseline response: explicitly zero d_user fields ────────────────
  // TL_D2H_DEFAULT has d_user=TL_D_USER_DEFAULT (all-1s), but a real baseline
  // slave drives all-0s. We construct the baseline case explicitly.
  always_comb begin
    tl_slave_i           = TL_D2H_DEFAULT;
    tl_slave_i.d_valid   = d_valid_i;
    tl_slave_i.d_opcode  = tl_d_op_e'(d_opcode_i);
    tl_slave_i.d_source  = d_source_i;
    tl_slave_i.d_data    = d_data_i;
    tl_slave_i.d_error   = d_error_i;
    tl_slave_i.a_ready   = 1'b1;
    // Baseline convention: integrity fields are zero on the way in.
    tl_slave_i.d_user.rsp_intg  = '0;
    tl_slave_i.d_user.data_intg = '0;
  end

  // ── DUT ─────────────────────────────────────────────────────────────
  tlul_slave_rsp_intg_wrap u_dut (
    .tl_host_i  (tl_host_i),
    .tl_host_o  (tl_host_o),
    .tl_slave_o (tl_slave_o),
    .tl_slave_i (tl_slave_i)
  );

  // ── Oracle 1: signed path — re-check the DUT output ──────────────────
  tlul_rsp_intg_chk u_chk_signed (
    .tl_i  (tl_host_o),
    .err_o (err_signed_o)
  );

  // ── Oracle 2: negative control — check the baseline input directly ───
  tlul_rsp_intg_chk u_chk_baseline (
    .tl_i  (tl_slave_i),
    .err_o (err_baseline_o)
  );

  // Silence unused-signal warnings
  wire _unused = &{1'b0, tl_slave_o, clk_i, rst_ni, 1'b0};

endmodule
