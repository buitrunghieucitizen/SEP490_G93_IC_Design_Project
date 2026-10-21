param(
    [string]$Iverilog = "E:\down\iverilog\bin\iverilog.exe",
    [string]$Vvp = "E:\down\iverilog\bin\vvp.exe"
)

$ErrorActionPreference = "Continue"
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
    if (-not (Test-Path -LiteralPath $Iverilog)) { throw "Icarus compiler not found: $Iverilog" }
    if (-not (Test-Path -LiteralPath $Vvp)) { throw "Icarus runtime not found: $Vvp" }
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
