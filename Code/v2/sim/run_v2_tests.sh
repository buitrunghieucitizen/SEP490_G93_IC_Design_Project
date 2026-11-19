#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p build/v2
for top in tb_command_parser_v2 tb_multi_cpu_v2 tb_uart_multi_v2; do
  echo "=== $top ==="
  iverilog -g2012 -s "$top" -o "build/v2/$top.vvp" src/*.v "v2/sim/$top.v"
  vvp "build/v2/$top.vvp" | tee "build/v2/$top.log"
  grep -q "PASS $top" "build/v2/$top.log"
done
echo 'ALL V2 HDL TESTS PASSED'
