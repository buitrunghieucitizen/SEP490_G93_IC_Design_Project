$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $root
New-Item -ItemType Directory -Path 'build\v2' -Force | Out-Null
$hdl = @(Get-ChildItem -Path 'src' -Filter '*.v' | ForEach-Object { $_.FullName })
foreach ($top in @('tb_command_parser_v2','tb_multi_cpu_v2','tb_uart_multi_v2')) {
    Write-Host "=== $top ==="
    $vvpFile = "build/v2/$top.vvp"
    $argsList = @('-g2012','-s', $top,'-o',$vvpFile) + $hdl + @("v2/sim/$top.v")
    & iverilog @argsList
    if ($LASTEXITCODE -ne 0) { throw "IVERILOG COMPILE FAILED: $top" }
    $out = & vvp $vvpFile 2>&1
    $out | ForEach-Object { Write-Host "$_" }
    if ($LASTEXITCODE -ne 0 -or !($out -match "PASS $top")) {
        throw "HDL SIMULATION FAILED: $top"
    }
}
Write-Host "ALL V2 HDL TESTS PASSED" -ForegroundColor Green
