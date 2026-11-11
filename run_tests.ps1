# =============================================================================
# Quy trinh chay test + waveform bang Icarus Verilog (iverilog / vvp)
# Du an: RISC-V 32-bit Single-Cycle CPU
# Ket qua (bang + file .vcd) duoc luot vao thu muc Result\
# =============================================================================
$ErrorActionPreference = "Continue"

$root   = Resolve-Path "."
$outDir = Join-Path $root "out"          # file trung gian: .vvp, .log
$resDir = Join-Path $root "Result"       # ket qua cuoi cung: bang + .vcd
New-Item -ItemType Directory -Force -Path $outDir  | Out-Null
New-Item -ItemType Directory -Force -Path $resDir  | Out-Null

# Danh sach testbench: ten, nguon (gach phay cach), ten file VCD (duoc $dumpfile sinh trong testbench)
$tests = @(
    @{ name="tb_alu";                       srcs="src/alu.v,tb/tb_alu.v";                                 vcd="waveform_alu.vcd" },
    @{ name="tb_immediate_gen";             srcs="src/immediate_gen.v,tb/tb_immediate_gen.v";             vcd="waveform_immediate_gen.vcd" },
    @{ name="tb_control_unit";              srcs="src/control_unit.v,tb/tb_control_unit.v";               vcd="waveform_control_unit.vcd" },
    @{ name="tb_memory";                    srcs="src/data_memory.v,src/instruction_memory.v,tb/tb_memory.v"; vcd="waveform_memory.vcd" },
    @{ name="tb_cpu";                       srcs="src/alu.v,src/control_unit.v,src/register_file.v,src/pc.v,src/instruction_memory.v,src/data_memory.v,src/datapath.v,src/cpu_top.v,src/immediate_gen.v,tb/tb_cpu.v"; vcd="waveform_cpu.vcd" },
    @{ name="tb_demo_sum";                  srcs="src/alu.v,src/control_unit.v,src/register_file.v,src/pc.v,src/instruction_memory.v,src/data_memory.v,src/datapath.v,src/cpu_top.v,src/immediate_gen.v,tb/tb_demo_sum.v"; vcd="waveform_demo_sum.vcd" },
    @{ name="tb_fpga_debug_wrapper";        srcs="src/alu.v,src/control_unit.v,src/register_file.v,src/pc.v,src/instruction_memory.v,src/data_memory.v,src/datapath.v,src/cpu_top.v,src/fpga_debug_wrapper.v,src/immediate_gen.v,tb/tb_fpga_debug_wrapper.v"; vcd="waveform_fpga_debug_wrapper.vcd" }
)

$results = @()
$nPass = 0; $nFail = 0; $nOther = 0

foreach ($t in $tests) {
    $srcArray = $t.srcs -split ","
    $vvp  = Join-Path $outDir ($t.name + ".vvp")
    $log  = Join-Path $outDir ($t.name + ".log")

    Write-Host ("============================================================")
    Write-Host ("[COMPILE] " + $t.name)
    $comp = iverilog -o $vvp $srcArray 2>&1
    $LASTEXITCODE
    if ($LASTEXITCODE -ne 0) {
        $comp | Out-File $log
        $results += [pscustomobject]@{ STT=($results.Count+1); Testbench=$t.name; KetQua="COMPILE ERROR"; Waveform="N/A"; ChiTiet="Loi trinh bien dien. Xem $log" }
        $nOther++
        continue
    }

    Write-Host ("[RUN]     " + $t.name)
    $run = vvp $vvp 2>&1
    $runOut = ($run | Out-String)
    $runOut | Out-File $log

    # Xac dinh trang thai cuoi cung tu output
    $summary = ""
    foreach ($line in ($runOut -split "`n")) {
        if ($line -match "ALL TESTS PASSED|SOME TESTS FAILED") { $summary = $line.Trim() }
        if ($line -match ([regex]::Escape($t.name) + ":\s*(PASS|FAIL)")) { $summary = $line.Trim() }
    }
    if      ($summary -match "ALL TESTS PASSED") { $status = "PASS" }
    elseif  ($summary -match "SOME TESTS FAILED") { $status = "FAIL" }
    elseif  ($summary -match ": PASS\b") { $status = "PASS" }
    elseif  ($summary -match ": FAIL\b") { $status = "FAIL" }
    else { $status = "UNKNOWN" }

    switch ($status) {
        "PASS" { $nPass++ }
        "FAIL" { $nFail++ }
        default { $nOther++ }
    }

    # Sao chep file VCD vao Result
    $srcVcd = Join-Path $outDir $t.vcd
    $dstVcd = Join-Path $resDir $t.vcd
    $vcdStatus = if (Test-Path $srcVcd) { Copy-Item $srcVcd $dstVcd -Force; "co" } else { "khong co" }

    $results += [pscustomobject]@{
        STT         = ($results.Count + 1)
        Testbench   = $t.name
        KetQua      = $status
        Waveform    = $t.vcd + " (" + $vcdStatus + ")"
        ChiTiet     = $summary
    }
}

# ===== Ghi bang ket qua vao Result/testbench_results.md =====
$mdPath = Join-Path $resDir "testbench_results.md"
$total = $results.Count
& {
    "# Bang ket qua testbench (Icarus Verilog)"
    ""
    "Du an: RISC-V 32-bit Single-Cycle CPU  |  Trinh bien dien: iverilog  |  Chay: vvp  |  Duong dan ket qua: Result\"
    ""
    "## Tom tat"
    ""
    "- Tong so testbench : $total"
    "- PASS              : $nPass"
    "- FAIL              : $nFail"
    "- Khac / Loi        : $nOther"
    ""
    "## Chi tiet tung testbench"
    ""
    "| STT | Testbench | Ket qua | File waveform (.vcd) | Chi tiet |"
    "|-----|-----------|---------|----------------------|----------|"
} | Out-File -Encoding utf8 $mdPath

foreach ($r in $results) {
    $badge = if ($r.KetQua -eq "PASS") { ":white_check_mark: PASS" } elseif ($r.KetQua -eq "FAIL") { ":x: FAIL" } else { ":warning: $($r.KetQua)" }
    "| $($r.STT) | $($r.Testbench) | $badge | $($r.Waveform) | $($r.ChiTiet) |" | Out-File -Encoding utf8 -Append $mdPath
}

& {
    ""
    "## Tap tin dien tu kem theo"
    ""
    "Cac file `.vcd` duoc luu trong thu muc `Result\` va co the mo bang GTKWave de quan sat waveform."
    ""
    "---"
    "*Duoc tao boi script run_tests.ps1. Chay lai bao gio cung duoc: .\run_tests.ps1 tai goc du an.*"
} | Out-File -Encoding utf8 -Append $mdPath

# In bang ra man hinh
$results | Format-Table -AutoSize
Write-Host ""
Write-Host ("Ket qua da luu vao: " + $mdPath)
Write-Host ("File waveform (.vcd) da luu vao: " + $resDir)
