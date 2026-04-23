# tlul_slave_rsp_intg_wrap — cocotb + Verilator unit test.
#
# Usage:
#   make                    # run with default LOCAL_IPS (see below)
#   make LOCAL_IPS=<path>   # override path to vendored opentitan-prim[-generic]
#   make clean
#
# The DUT (vyges-additions/tlul_slave_rsp_intg_wrap.sv) pulls in
# tlul_rsp_intg_gen → prim_secded_inv_64_57_enc, and the oracles use
# tlul_rsp_intg_chk → prim_secded_inv_64_57_dec. Both live in
# opentitan-prim-generic. Rather than duplicate them into this IP, the
# Makefile references them via LOCAL_IPS — a directory containing
# opentitan-prim, opentitan-prim-generic (and any other vendored Vyges
# IP trees). Defaults to a path that works on the Vyges Ubuntu build
# box; override on other hosts.

SIM            := verilator
TOPLEVEL_LANG  := verilog
TOPLEVEL       := tb_slave_rsp_wrap
MODULE         := test_slave_rsp_wrap

# ── Paths ─────────────────────────────────────────────────────────────
THIS_DIR       := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
TLUL_ROOT      := $(abspath $(THIS_DIR)/../../..)

# LOCAL_IPS must contain opentitan-prim/ and opentitan-prim-generic/ trees.
# Default: the vendored local-ips/ directory of a co-located test SoC on
# the Ubuntu build box. Override via environment or make argument.
LOCAL_IPS      ?= $(abspath $(TLUL_ROOT)/../test-dbg-edgesensor-soc/local-ips)

PRIM          := $(LOCAL_IPS)/opentitan-prim

# ── RTL file list ─────────────────────────────────────────────────────
# Order matters for Verilator: packages before consumers.
# prim_secded_{pkg,enc,dec} all live under opentitan-prim/rtl/ (the vendored
# tree), not opentitan-prim-generic/ — opentitan-prim-generic ships cell-
# level primitives (flops, clock gaters) rather than data-integrity codes.
VERILOG_SOURCES += \
    $(PRIM)/rtl/prim_util_pkg.sv \
    $(PRIM)/rtl/prim_mubi_pkg.sv \
    $(PRIM)/rtl/prim_secded_pkg.sv \
    $(PRIM)/rtl/prim_secded_inv_39_32_enc.sv \
    $(PRIM)/rtl/prim_secded_inv_64_57_enc.sv \
    $(PRIM)/rtl/prim_secded_inv_64_57_dec.sv \
    $(THIS_DIR)/top_pkg.sv \
    $(TLUL_ROOT)/rtl/tlul_pkg.sv \
    $(TLUL_ROOT)/rtl/tlul_data_integ_enc.sv \
    $(TLUL_ROOT)/rtl/tlul_rsp_intg_gen.sv \
    $(TLUL_ROOT)/rtl/tlul_rsp_intg_chk.sv \
    $(TLUL_ROOT)/vyges-additions/tlul_slave_rsp_intg_wrap.sv \
    $(THIS_DIR)/tb_slave_rsp_wrap.sv

# ── Include search paths for `include "prim_assert.sv"` ───────────────
EXTRA_ARGS += +incdir+$(PRIM)/rtl
EXTRA_ARGS += +define+SYNTHESIS

# Verilator: treat assertions non-fatally for clean CI runs, and
# tolerate the unused-net warning pattern the OT assertion macros emit.
EXTRA_ARGS += --Wno-UNUSEDSIGNAL --Wno-UNUSEDPARAM --Wno-PINMISSING \
              --Wno-DECLFILENAME --Wno-WIDTHEXPAND --Wno-WIDTHTRUNC

WAVES ?=
ifeq ($(WAVES),vcd)
    EXTRA_ARGS += --trace
endif

include $(shell cocotb-config --makefiles)/Makefile.sim

print-files:
	@printf '%s\n' $(VERILOG_SOURCES)

.PHONY: print-files
