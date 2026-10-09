// =============================================================================
// Testbench : tb_cpu
// Project   : RISC-V 32-bit Single-Cycle CPU
// Desc      : Top-level CPU testbench
//             Loads a program from .mem file and runs for N cycles
//             Dumps VCD waveform for GTKWave
// Run       : iverilog -g2012 -o out/sim.vvp src/*.sv tb/tb_cpu.sv
//             vvp out/sim.vvp
//             gtkwave out/waveform.vcd
// =============================================================================

`timescale 1ns/1ps

module tb_cpu;

    // Clock & Reset
    logic clk = 0;
    logic rst = 1;

    // Clock: 10ns period (100 MHz)
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // DUT Instantiation
    // -------------------------------------------------------------------------
    cpu_top dut (
        .clk (clk),
        .rst (rst)
    );

    // -------------------------------------------------------------------------
    // VCD Waveform Dump
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("out/waveform.vcd");
        $dumpvars(0, tb_cpu);
    end

    // -------------------------------------------------------------------------
    // Simulation Control
    // -------------------------------------------------------------------------
    initial begin
        $display("================================================");
        $display("   CPU TESTBENCH — RISC-V 32-bit Single-Cycle");
        $display("================================================");

        // Apply reset for 3 cycles
        rst = 1;
        repeat(3) @(posedge clk);
        rst = 0;
        $display("[%0t] Reset released — CPU running...", $time);

        // Run for 100 cycles then stop
        repeat(100) @(posedge clk);

        $display("[%0t] Simulation complete (100 cycles)", $time);
        $display("================================================\n");
        $finish;
    end

    // -------------------------------------------------------------------------
    // Monitor: print PC and instruction each cycle
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst) begin
            $display("[%0t] PC=%08h | INSTR=%08h",
                $time,
                dut.u_datapath.pc_current,
                dut.u_datapath.instr
            );
        end
    end

endmodule
