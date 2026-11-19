$ErrorActionPreference = 'Stop'
$project = (Get-Location).Path
if (!(Test-Path 'src\uart_command_parser_v2.v')) {
    throw 'Run from root SEP490_G93_Upgrade_v1, which contains src and v2 folders.'
}
New-Item -ItemType Directory -Force -Path 'build\sim' | Out-Null
iverilog -g2012 -s tb_command_parser_v2 -o 'build\sim\tb_parser_v2.out' 'v2\sim\tb_command_parser_v2.v' 'src\uart_command_parser_v2.v'
if ($LASTEXITCODE -ne 0) { throw 'Compile original parser test failed' }
vvp 'build\sim\tb_parser_v2.out'
if ($LASTEXITCODE -ne 0) { throw 'Original parser test failed' }
iverilog -g2012 -s tb_test20_parser_patch -o 'build\sim\tb_parser_patch.out' 'test20_parser_patch\test\tb_test20_parser_patch.v' 'src\uart_command_parser_v2.v'
if ($LASTEXITCODE -ne 0) { throw 'Compile patch test failed' }
vvp 'build\sim\tb_parser_patch.out'
if ($LASTEXITCODE -ne 0) { throw 'Patch test failed' }
Write-Host 'PARSER PATCH TESTS PASSED'
