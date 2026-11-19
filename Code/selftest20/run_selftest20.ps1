$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
New-Item -ItemType Directory -Force -Path 'build\sim' | Out-Null
Write-Host '== Assemble SELFTEST20 =='
python .\selftest20\build_selftest20.py
if ($LASTEXITCODE -ne 0) { throw 'Assembly failed' }
$lines = @(Get-Content .\selftest20\SELFTEST20.mem)
if ($lines.Count -gt 256) { throw 'SELFTEST20 exceeds 256 instruction ROM words' }
Write-Host '== Compile HDL testbench =='
$sourceFiles = @(Get-ChildItem -Path src -Filter '*.v' | ForEach-Object { $_.FullName })
iverilog -g2012 -s tb_selftest20_mmio -o build\sim\tb_selftest20_mmio.vvp selftest20\tb_selftest20_mmio.v @sourceFiles
if ($LASTEXITCODE -ne 0) { throw 'Icarus compilation failed' }
Write-Host '== Run HDL testbench =='
vvp build\sim\tb_selftest20_mmio.vvp
if ($LASTEXITCODE -ne 0) { throw 'SELFTEST20 simulation FAILED' }
Write-Host '== Negative control: intentionally change SLL to SRL in simulation ROM =='
vvp build\sim\tb_selftest20_mmio.vvp +INJECT_SLL
if ($LASTEXITCODE -ne 0) { throw 'Negative control simulation FAILED' }
Write-Host 'SELFTEST20 and negative-control simulations passed.' 
