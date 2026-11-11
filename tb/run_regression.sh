#!/usr/bin/env bash
# run_regression.sh - Chay tat ca testbench bang Icarus Verilog (Linux / WSL).
# Ban Windows tuong duong: tb/run_regression.ps1
#
# Cach dung (tu thu muc Code/):
#   bash tb/run_regression.sh
#   # hoac, sau khi chmod +x:
#   ./tb/run_regression.sh
#
# Yeu cau: iverilog va vvp co trong PATH.
#   WSL Ubuntu: sudo apt install -y iverilog
# Quy uoc: moi testbench phai in dong PASS cua no, neu co FAIL
# hoac thieu dong PASS thi script dung ngay va tra exit code != 0.
set -u
cd "$(dirname "$0")/.." || exit 1

IVERILOG="${IVERILOG:-iverilog}"
VVP="${VVP:-vvp}"
mkdir -p out

CORE="src/alu.v src/register_file.v src/pc.v src/instruction_memory.v \
src/data_memory.v src/immediate_gen.v src/control_unit.v src/datapath.v \
src/cpu_top.v"

# Moi dong: TenTop|ChuoiPASS|Danh sach file nguon
# (Chuoi PASS phai khop dong tom tat cuoi moi testbench.)
run_one() {
    local top="$1" pass="$2"; shift 2
    echo "=== $top ==="
    "$IVERILOG" -g2001 -Wall -s "$top" -o "out/$top.vvp" "$@" || {
        echo "Compile failed for $top"; return 1; }
    local output
    output="$("$VVP" "out/$top.vvp" 2>&1)"
    echo "$output"
    if echo "$output" | grep -Eq '(^FAIL|: FAIL)'; then
        echo "Simulation reported FAIL for $top"; return 1;
    fi
    if ! echo "$output" | grep -Fq "$pass"; then
        echo "Simulation did not report PASS for $top (thieu: $pass)"; return 1;
    fi
}

run_one tb_alu               "ALL TESTS PASSED"        src/alu.v tb/tb_alu.v || exit 1
run_one tb_control_unit      "tb_control_unit: PASS"   src/control_unit.v tb/tb_control_unit.v || exit 1
run_one tb_immediate_gen     "tb_immediate_gen: PASS"  src/immediate_gen.v tb/tb_immediate_gen.v || exit 1
run_one tb_memory            "tb_memory: PASS"         src/instruction_memory.v src/data_memory.v tb/tb_memory.v || exit 1
run_one tb_instruction_memory "tb_instruction_memory: PASS" src/instruction_memory.v tb/tb_instruction_memory.v || exit 1
run_one tb_data_memory       "tb_data_memory: PASS"    src/data_memory.v tb/tb_data_memory.v || exit 1
run_one tb_pc                "tb_pc: PASS"             src/pc.v tb/tb_pc.v || exit 1
run_one tb_register_file     "tb_register_file: PASS"  src/register_file.v tb/tb_register_file.v || exit 1
run_one tb_datapath          "tb_datapath: PASS"       src/alu.v src/register_file.v src/pc.v src/instruction_memory.v src/data_memory.v src/immediate_gen.v src/datapath.v tb/tb_datapath.v || exit 1
run_one tb_result_capture    "tb_result_capture: PASS" src/result_capture.v tb/tb_result_capture.v || exit 1
run_one tb_cpu_wb_probe      "tb_cpu_wb_probe: PASS"   src/cpu_wb_probe.v tb/tb_cpu_wb_probe.v || exit 1
run_one tb_test_all_20       "tb_test_all_20: PASS"    $CORE tb/tb_test_all_20.v || exit 1
run_one tb_test_fault        "tb_test_fault: PASS"     $CORE tb/tb_test_fault.v || exit 1
run_one tb_cpu               "tb_cpu: PASS"            $CORE tb/tb_cpu.v || exit 1
run_one tb_demo_sum          "tb_demo_sum: PASS"       $CORE tb/tb_demo_sum.v || exit 1
run_one tb_fpga_debug_wrapper "tb_fpga_debug_wrapper: PASS" $CORE src/fpga_debug_wrapper.v tb/tb_fpga_debug_wrapper.v || exit 1

echo "ALL REGRESSION TESTS PASSED"
