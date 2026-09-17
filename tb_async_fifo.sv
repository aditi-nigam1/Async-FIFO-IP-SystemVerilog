// tb_async_fifo.sv
// Pure Procedural SystemVerilog Verification Environment for Asynchronous FIFO

module tb_async_fifo;

    // 1. Configuration Parameters matching our hardware specs
    localparam DATA_WIDTH = 8;
    localparam FIFO_DEPTH = 16;
    
    // 2. Testbench Simulation Driving Nets (Inputs to DUT)
    logic                  w_clk;
    logic                  w_rst_n;
    logic                  w_en;
    logic [DATA_WIDTH-1:0] w_data;
    
    logic                  r_clk;
    logic                  r_rst_n;
    logic                  r_en;
    
    // 3. Output Observation Nets (Outputs from DUT)
    logic [DATA_WIDTH-1:0] r_data;
    logic                  w_full;
    logic                  w_almost_full;
    logic                  r_empty;
    logic                  r_almost_empty;

    // -------------------------------------------------------------------------
    // ASYNCHRONOUS CLOCK OSCILLATORS
    // -------------------------------------------------------------------------
    // Initialize clocks to zero to prevent initialization locking states
    initial begin
        w_clk = 0;
        r_clk = 0;
    end

    // Fast Write Domain Clock: 100 MHz (Period = 10ns -> Toggle every 5ns)
    always #5 w_clk = ~w_clk;
    
    // Slower Read Domain Clock: 40 MHz (Period = 25ns -> Toggle every 12.5ns)
    always #12.5 r_clk = ~r_clk;

    // -------------------------------------------------------------------------
    // DEVICE UNDER TEST (DUT) INSTANTIATION
    // -------------------------------------------------------------------------
    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) DUT (
        .w_clk          (w_clk),
        .w_rst_n        (w_rst_n),
        .w_en           (w_en),
        .w_data         (w_data),
        .w_full         (w_full),
        .w_almost_full  (w_almost_full),
        
        .r_clk          (r_clk),
        .r_rst_n        (r_rst_n),
        .r_en           (r_en),
        .r_data         (r_data),
        .r_empty        (r_empty),
        .r_almost_empty (r_almost_empty)
    );

    // -------------------------------------------------------------------------
    // CENTRAL TEST STIMULUS GENERATION LOGIC
    // -------------------------------------------------------------------------
    initial begin
        $display("======= STARTING ASYNCHRONOUS FIFO SIMULATION =======");
        
        // Step 1: Initialize Driving Lines to clear High-Impedance (Z) States
        w_en   = 1'b0;
        w_data = '0;
        r_en   = 1'b0;
        
        // Step 2: Apply System-Wide Asynchronous Reset
        w_rst_n = 1'b0;
        r_rst_n = 1'b0;
        #40; // Hold reset active across multiple clock transitions
        
        // Release resets on a falling edge to prevent setup violation timing anomalies
        @(negedge w_clk);
        w_rst_n = 1'b1;
        @(negedge r_clk);
        r_rst_n = 1'b1;
        $display("[STATUS] Resets Deasserted. System Ready for Operations.");
        #20;

        // ---------------------------------------------------------------------
        // TEST CASE 1: BURST WRITE SECTOR (Filling up the FIFO)
        // ---------------------------------------------------------------------
        $display("[TEST] Starting Burst Write Operations...");
        for (int i = 0; i < FIFO_DEPTH + 2; i++) begin
            @(posedge w_clk);
            if (!w_full) begin
                w_en   = 1'b1;
                w_data = i + 8'hA0; // Send distinct hex marker patterns (A0, A1, A2...)
                $display("[WRITE] Time=%0t | Data Written=0x%h", $time, w_data);
            end else begin
                w_en   = 1'b0;
                $display("[WRITE BLOCK] Time=%0t | Write Prevented. FIFO is FULL!", $time);
            end
        end
        
        // Stop writing data loops
        @(posedge w_clk);
        w_en   = 1'b0;
        w_data = '0;
        #100; // Allow cross-domain pointers to synchronize across CDC stages

        // ---------------------------------------------------------------------
        // TEST CASE 2: BURST READ SECTOR (Emptying the FIFO)
        // ---------------------------------------------------------------------
        $display("[TEST] Starting Burst Read Operations...");
        for (int j = 0; j < FIFO_DEPTH + 2; j++) begin
            @(posedge r_clk);
            if (!r_empty) begin
                r_en = 1'b1;
                // Capture data on the subsequent clock cycle when memory outputs settle
                #1; 
                $display("[READ]  Time=%0t | Data Extracted=0x%h", $time, r_data);
            end else begin
                r_en = 1'b0;
                $display("[READ BLOCK]  Time=%0t | Read Prevented. FIFO is EMPTY!", $time);
            end
        end

        // Stop reading data loops
        @(posedge r_clk);
        r_en = 1'b0;
        #100;

        // ---------------------------------------------------------------------
        // TEST CASE 3: SIMULTANEOUS CONCURRENT TRANSACTIONS
        // ---------------------------------------------------------------------
        $display("[TEST] Starting Simultaneous Read and Write Data Flow...");
        fork
            // Write Thread Execution
            begin
                repeat(10) begin
                    @(posedge w_clk);
                    if (!w_full) begin
                        w_en   = 1'b1;
                        w_data = $urandom_range(8'h01, 8'hFF); // Generate random data
                    end else begin
                        w_en   = 1'b0;
                    end
                end
                @(posedge w_clk); w_en = 1'b0;
            end
            
            // Read Thread Execution
            begin
                repeat(10) begin
                    @(posedge r_clk);
                    if (!r_empty) begin
                        r_en = 1'b1;
                    end else begin
                        r_en = 1'b0;
                    end
                end
                @(posedge r_clk); r_en = 1'b0;
            end
        join

        #200;
        $display("======= SIMULATION RUN SUCCESS: TESTING ROUND COMPLETED =======");
        $finish;
    end

endmodule
