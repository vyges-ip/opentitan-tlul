// Minimal top_pkg for standalone opentitan-tlul simulation.
// tlul_pkg references top_pkg::TL_{AW,DW,AIW,DIW,AUW,DBW,SZW} to size
// its struct members; SoCs normally provide their own top_pkg.sv with
// project-wide TL-UL widths. For unit tests we pin them to the common
// 32-bit profile used by edge_sensor / Caravel-class SoCs.

package top_pkg;
  localparam int TL_AW  = 32;
  localparam int TL_DW  = 32;
  localparam int TL_AIW = 8;
  localparam int TL_DIW = 1;
  localparam int TL_AUW = 24;
  localparam int TL_DBW = (TL_DW >> 3);
  localparam int TL_SZW = $clog2($clog2(TL_DBW) + 1);
endpackage
