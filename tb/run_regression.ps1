param(
    [string]$Iverilog = "",
    [string]$Vvp = ""
)

# Tu tim iverilog/vvp: uu tien tham so truyen vao, roi PATH, roi cac cho cai thuong gap.
function Find-IcarusTool {
    param([string]$Name, [string]$Given)
    if ($Given -ne "" -and (Test-Path -LiteralPath $Given)) { return $Given }
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($root in @("C:\MIP201\MIP201_SU26\iverilog\bin", "E:\down\iverilog\bin", "C:\iverilog\bin")) {
        $p = Join-Path $root $Name
        if (Test-Path -LiteralPath $p) { return $p }
    }
    return $null
}

$ErrorActionPreference = "Continue"
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
    $Iverilog = Find-IcarusTool "iverilog.exe" $Iverilog
    $Vvp = Find-IcarusTool "vvp.exe" $Vvp
    if (-not $Iverilog) { throw "Icarus compiler not found: cai Icarus Verilog hoac them thu muc bin vao PATH" }
    if (-not $Vvp) { throw "Icarus runtime not found: cai Icarus Verilog hoac them thu muc bin vao PATH" }
    New-Item -ItemType Directory -Force -Path "out" | Out-Null

    $core = @(
        "src/alu.v", "src/register_file.v", "src/pc.v",
        "src/instruction_memory.v", "src/data_memory.v",
        "src/immediate_gen.v", "src/control_unit.v", "src/datapath.v", "src/cpu_top.v"
    )
    $tests = @(
        @{ Top="tb_alu"; Out="tb_alu"; Src=@("src/alu.v", "tb/tb_alu.v"); Pass="ALL TESTS PASSED" },
        @{ Top="tb_control_unit"; Out="tb_control_unit"; Src=@("src/control_unit.v", "tb/tb_control_unit.v"); Pass="tb_control_unit: PASS" },
        @{ Top="tb_immediate_gen"; Out="tb_immediate_gen"; Src=@("src/immediate_gen.v", "tb/tb_immediate_gen.v"); Pass="tb_immediate_gen: PASS" },
        @{ Top="tb_memory"; Out="tb_memory"; Src=@("src/instruction_memory.v", "src/data_memory.v", "tb/tb_memory.v"); Pass="tb_memory: PASS" },
        @{ Top="tb_instruction_memory"; Out="tb_instruction_memory"; Src=@("src/instruction_memory.v", "tb/tb_instruction_memory.v"); Pass="tb_instruction_memory: PASS" },
        @{ Top="tb_data_memory"; Out="tb_data_memory"; Src=@("src/data_memory.v", "tb/tb_data_memory.v"); Pass="tb_data_memory: PASS" },
        @{ Top="tb_pc"; Out="tb_pc"; Src=@("src/pc.v", "tb/tb_pc.v"); Pass="tb_pc: PASS" },
        @{ Top="tb_register_file"; Out="tb_register_file"; Src=@("src/register_file.v", "tb/tb_register_file.v"); Pass="tb_register_file: PASS" },
        @{ Top="tb_datapath"; Out="tb_datapath"; Src=@("src/alu.v", "src/register_file.v", "src/pc.v", "src/instruction_memory.v", "src/data_memory.v", "src/immediate_gen.v", "src/datapath.v", "tb/tb_datapath.v"); Pass="tb_datapath: PASS" },
        @{ Top="tb_result_capture"; Out="tb_result_capture"; Src=@("src/result_capture.v", "tb/tb_result_capture.v"); Pass="tb_result_capture: PASS" },
        @{ Top="tb_cpu_wb_probe"; Out="tb_cpu_wb_probe"; Src=@("src/cpu_wb_probe.v", "tb/tb_cpu_wb_probe.v"); Pass="tb_cpu_wb_probe: PASS" },
        @{ Top="tb_test_all_20"; Out="tb_test_all_20"; Src=@($core + @("tb/tb_test_all_20.v")); Pass="tb_test_all_20: PASS" },
        @{ Top="tb_test_fault"; Out="tb_test_fault"; Src=@($core + @("tb/tb_test_fault.v")); Pass="tb_test_fault: PASS" },
        @{ Top="tb_cpu"; Out="tb_cpu"; Src=@($core + @("tb/tb_cpu.v")); Pass="tb_cpu: PASS" },
        @{ Top="tb_demo_sum"; Out="tb_demo_sum"; Src=@($core + @("tb/tb_demo_sum.v")); Pass="tb_demo_sum: PASS" },
        @{ Top="tb_fpga_debug_wrapper"; Out="tb_fpga_debug_wrapper"; Src=@($core + @("src/fpga_debug_wrapper.v", "tb/tb_fpga_debug_wrapper.v")); Pass="tb_fpga_debug_wrapper: PASS" }
    )

    foreach ($test in $tests) {
        Write-Host "=== $($test.Top) ==="
        $compileArgs = @("-g2001", "-Wall", "-s", $test.Top, "-o", "out/$($test.Out).vvp") + $test.Src
        $compileOutput = & $Iverilog @compileArgs 2>&1
        $compileOutput | ForEach-Object { Write-Host $_ }
        if ($LASTEXITCODE -ne 0) { throw "Compile failed for $($test.Top) (exit $LASTEXITCODE)" }

        $runOutput = & $Vvp "out/$($test.Out).vvp" 2>&1
        $runText = ($runOutput | Out-String)
        $runOutput | ForEach-Object { Write-Host $_ }
        if ($LASTEXITCODE -ne 0 -or $runText -match '(?m)^FAIL\b|: FAIL\b' -or $runText -notmatch [regex]::Escape($test.Pass)) {
            throw "Simulation did not report PASS for $($test.Top)"
        }
    }
    Write-Host "ALL REGRESSION TESTS PASSED"
}
finally {
    Pop-Location
}
