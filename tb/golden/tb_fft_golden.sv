`ifndef TB_FFT_GOLDEN_SV
`define TB_FFT_GOLDEN_SV

`timescale 1ns/1ps

//=============================================================================
// FFT golden-model testbench
//=============================================================================
// Description: Drives fft_top the way firmware does (APB twiddle and sample
//              loads, a start pulse) and records every streamed output bin,
//              so run_golden.py can compare it word for word with the
//              fixed-point reference model. Also checks the software-visible
//              completion contract: FFT_STATUS.done stays set after the run,
//              INT_STATUS[0] stays set until written with 1, and the write
//              clears it; FFT_CTRL[2] held over many cycles toggles the
//              buffer-active status bit once.
//
//              Build with FFT_USE_APB_DATA and FFT_USE_STREAM_OUT.
//              Plusargs: +case=<dir> reading <dir>/config.hex (log2(N),
//              FFT_CONFIG, FFT_CTRL run bits), <dir>/twiddle.hex and
//              <dir>/input.hex; writes <dir>/output.hex and <dir>/status.txt.
// Author:      Vyges IP Development Team
// License:     Apache-2.0
//=============================================================================

module tb_fft_golden;

    localparam int MAX_LOG2 = 10;
    localparam int MAX_N    = 1 << MAX_LOG2;

    logic        clk = 1'b0;
    logic        rst_n = 1'b0;
    logic        psel = 1'b0, penable = 1'b0, pwrite = 1'b0;
    logic [15:0] paddr = '0;
    logic [31:0] pwdata = '0;
    logic [31:0] prdata;
    logic        pready;
    logic        done_irq, error_irq;
    logic        bin_valid, bin_last;
    logic        bin_ready = 1'b1;
    logic [MAX_LOG2-1:0] bin_index;
    logic signed [15:0]  bin_re, bin_im;

    always #5 clk = ~clk;

    // A synthesized netlist (GOLDEN_NETLIST) has the parameter already applied.
`ifdef GOLDEN_NETLIST
    fft_top dut (
`else
    fft_top #(.FFT_MAX_LENGTH_LOG2(MAX_LOG2)) dut (
`endif
        .clk_i(clk), .reset_n_i(rst_n),
        .pclk_i(clk), .preset_n_i(rst_n),
        .psel_i(psel), .penable_i(penable), .pwrite_i(pwrite),
        .paddr_i(paddr), .pwdata_i(pwdata), .prdata_o(prdata), .pready_o(pready),
        .axi_aclk_i(clk), .axi_areset_n_i(rst_n),
        .axi_awaddr_i('0), .axi_awvalid_i(1'b0), .axi_awready_o(),
        .axi_wdata_i('0), .axi_wvalid_i(1'b0), .axi_wready_o(),
        .axi_araddr_i('0), .axi_arvalid_i(1'b0), .axi_arready_o(),
        .axi_rdata_o(), .axi_rvalid_o(), .axi_rready_i(1'b0),
        .fft_done_o(done_irq), .fft_error_o(error_irq),
        .sram_clk_o(), .sram_addr_o(), .sram_wdata_o(), .sram_ben_o(),
        .sram_rwb_o(), .sram_en_o(), .sram_rdata0_i('0), .sram_rdata1_i('0),
        .bin_valid_o(bin_valid), .bin_ready_i(bin_ready), .bin_index_o(bin_index),
        .bin_last_o(bin_last), .bin_re_o(bin_re), .bin_im_o(bin_im)
    );

    // APB is driven on the falling edge, so the core samples stable inputs.
    task automatic apb_write(input logic [15:0] addr, input logic [31:0] data);
        @(negedge clk);
        psel = 1'b1; penable = 1'b0; pwrite = 1'b1; paddr = addr; pwdata = data;
        @(negedge clk);
        penable = 1'b1;
        do @(negedge clk); while (!pready);
        @(negedge clk);  // the slave completes the transfer on the edge after PREADY
        psel = 1'b0; penable = 1'b0; pwrite = 1'b0;
    endtask

    task automatic apb_read(input logic [15:0] addr, output logic [31:0] data);
        @(negedge clk);
        psel = 1'b1; penable = 1'b0; pwrite = 1'b0; paddr = addr;
        @(negedge clk);
        penable = 1'b1;
        do @(negedge clk); while (!pready);
        data = prdata;
        psel = 1'b0; penable = 1'b0;
    endtask

    logic [31:0] config_words [0:2];
    logic [31:0] twiddles [0:MAX_N/2-1];
    logic [31:0] samples [0:MAX_N-1];
    logic [31:0] out_bins [0:MAX_N-1];
    int          seen [0:MAX_N-1];

    string case_dir;
    int    n, fd, cycles, nbins, errors;
    logic [31:0] status, int_status, scale, swap_status;
    logic        swap_before;

    // Collect streamed bins.
    always @(posedge clk) begin
        if (bin_valid && bin_ready) begin
            out_bins[bin_index] <= {bin_im, bin_re};
            seen[bin_index] <= seen[bin_index] + 1;
            nbins <= nbins + 1;
        end
    end

    initial begin
        errors = 0;
        nbins = 0;
        if (!$value$plusargs("case=%s", case_dir)) $fatal(1, "missing +case=<dir>");
        $readmemh({case_dir, "/config.hex"}, config_words);
        n = 1 << config_words[0][3:0];
        $readmemh({case_dir, "/twiddle.hex"}, twiddles, 0, n/2 - 1);
        $readmemh({case_dir, "/input.hex"}, samples, 0, n - 1);
        for (int i = 0; i < MAX_N; i++) seen[i] = 0;

        repeat (4) @(posedge clk);
        @(negedge clk) rst_n = 1'b1;
        repeat (2) @(posedge clk);

        apb_write(16'h0008, config_words[1]);           // FFT_CONFIG
        apb_write(16'h000C, 32'(n));                    // FFT_LENGTH
        apb_write(16'h0014, 32'h0000_0001);             // INT_ENABLE: done
        for (int k = 0; k < n/2; k++) apb_write(16'h0800 + 16'(4*k), twiddles[k]);
        for (int i = 0; i < n; i++)   apb_write(16'h1000 + 16'(4*i), samples[i]);

        // Start pulse with the run bits held, as firmware does.
        apb_write(16'h0000, config_words[2] | 32'h1);
        apb_write(16'h0000, config_words[2]);

        cycles = 0;
        while (nbins < n && cycles < 200000) begin
            @(posedge clk);
            cycles++;
        end
        repeat (20) @(posedge clk);

        apb_read(16'h0004, status);
        apb_read(16'h0018, int_status);
        apb_read(16'h001C, scale);
        if (!status[1]) begin
            $display("ERROR: FFT_STATUS.done not held after the run (status=%h)", status);
            errors++;
        end
        if (!int_status[0]) begin
            $display("ERROR: INT_STATUS[0] not held after the run (int_status=%h)", int_status);
            errors++;
        end
        apb_write(16'h0018, 32'h0000_0001);             // write 1 to clear
        apb_read(16'h0018, int_status);
        if (int_status[0]) begin
            $display("ERROR: INT_STATUS[0] still set after write-1-to-clear");
            errors++;
        end
        // FFT_CTRL[2] held over many cycles is ONE swap: FFT_STATUS[3] toggles once per write
        // of 1, whatever the hold. Two holds of different parity catch a per-cycle toggle.
        for (int hold = 10; hold <= 11; hold++) begin
            apb_read(16'h0004, swap_status);
            swap_before = swap_status[3];
            apb_write(16'h0000, 32'h0000_0004);
            repeat (hold) @(posedge clk);
            apb_write(16'h0000, 32'h0000_0000);
            apb_read(16'h0004, swap_status);
            if (swap_status[3] == swap_before) begin
                $display("ERROR: FFT_CTRL[2] held %0d cycles did not toggle FFT_STATUS[3] once", hold);
                errors++;
            end
        end
        for (int i = 0; i < n; i++) begin
            if (seen[i] != 1) begin
                $display("ERROR: bin %0d streamed %0d times", i, seen[i]);
                errors++;
            end
        end

        fd = $fopen({case_dir, "/output.hex"}, "w");
        for (int i = 0; i < n; i++) $fdisplay(fd, "%08h", out_bins[i]);
        $fclose(fd);
        fd = $fopen({case_dir, "/status.txt"}, "w");
        $fdisplay(fd, "scale_factor %0d", scale[7:0]);
        $fdisplay(fd, "stage_count %0d", scale[15:8]);
        $fdisplay(fd, "overflow_count %0d", scale[31:24]);
        $fdisplay(fd, "status %08h", status);
        $fdisplay(fd, "cycles %0d", cycles);
        $fdisplay(fd, "tb_errors %0d", errors);
        $fclose(fd);
        $finish;
    end

endmodule

`endif // TB_FFT_GOLDEN_SV
