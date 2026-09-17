// async_fifo.sv
// Parameterised Asynchronous FIFO for Multi-Clock Domain Data Transfer

module async_fifo #(
    parameter DATA_WIDTH = 8,   // Width of individual data words
    parameter FIFO_DEPTH = 16   // Storage depth (MUST be a power of 2)
)(
    // Write Clock Domain Interface
    input  logic                    w_clk,          // Write clock
    input  logic                    w_rst_n,        // Active-low asynchronous reset
    input  logic                    w_en,           // Write enable signal
    input  logic [DATA_WIDTH-1:0]   w_data,         // Data input bus
    output logic                    w_full,         // FIFO Full status flag
    output logic                    w_almost_full,  // Early warning flow control flag

    // Read Clock Domain Interface
    input  logic                    r_clk,          // Read clock
    input  logic                    r_rst_n,        // Active-low asynchronous reset
    input  logic                    r_en,           // Read enable signal
    output logic [DATA_WIDTH-1:0]   r_data,         // Data output bus
    output logic                    r_empty,        // FIFO Empty status flag
    output logic                    r_almost_empty  // Early warning read flag
);

    // Automatically calculate pointer width using the mathematical ceiling log2 function
    // If FIFO_DEPTH is 16, $clog2(16) evaluates to 4 bits
    localparam ADDR_WIDTH = $clog2(FIFO_DEPTH);


    // Internal address indexes derived from control logic pointers
    logic [ADDR_WIDTH-1:0] w_addr;
    logic [ADDR_WIDTH-1:0] r_addr;
    
    // Register-array layout modeling the physical memory storage matrix
    logic [DATA_WIDTH-1:0] fifo_ram [FIFO_DEPTH-1:0];

    // BLOCK 1: TRUE DUAL-PORT MEMORY ARBITRATION
    // Synchronous write access gated by strict boundary protection
    always_ff @(posedge w_clk) begin
        if (w_en && !w_full) begin
            fifo_ram[w_addr] <= w_data;
        end
    end

    // Synchronous read access gated by strict boundary protection
    always_ff @(posedge r_clk) begin
        if (r_en && !r_empty) begin
            r_data <= fifo_ram[r_addr];
        end
    end



    // Multi-bit pointer signals tracking write and read domains
    logic [ADDR_WIDTH:0] w_bin_ptr, w_gray_next, w_gray_ptr;
    logic [ADDR_WIDTH:0] r_bin_ptr, r_gray_next, r_gray_ptr;

    // --- WRITE DOMAIN POINTER SEQUENCER ---
    always_ff @(posedge w_clk or negedge w_rst_n) begin
        if (!w_rst_n) begin
            w_bin_ptr  <= '0;
            w_gray_ptr <= '0;
        end else if (w_en && !w_full) begin
            w_bin_ptr  <= w_bin_ptr + 1'b1;
            w_gray_ptr <= w_gray_next;
        end
    end

    // Lower bits route directly to register memory lookups
    assign w_addr = w_bin_ptr[ADDR_WIDTH-1:0];
    // Binary to Gray conversion logic: (Binary value) XOR (Binary value shifted right by 1)
    assign w_gray_next = (w_bin_ptr + (w_en && !w_full)) ^ ((w_bin_ptr + (w_en && !w_full)) >> 1);


    // --- READ DOMAIN POINTER SEQUENCER ---
    always_ff @(posedge r_clk or negedge r_rst_n) begin
        if (!r_rst_n) begin
            r_bin_ptr  <= '0;
            r_gray_ptr <= '0;
        end else if (r_en && !r_empty) begin
            r_bin_ptr  <= r_bin_ptr + 1'b1;
            r_gray_ptr <= r_gray_next;
        end
    end

    // Lower bits route directly to register memory lookups
    assign r_addr = r_bin_ptr[ADDR_WIDTH-1:0];
    // Binary to Gray conversion logic
    assign r_gray_next = (r_bin_ptr + (r_en && !r_empty)) ^ ((r_bin_ptr + (r_en && !r_empty)) >> 1);





    // Flip-flop pipelines used for Cross-Domain Synchronization
    logic [ADDR_WIDTH:0] w_gray_sync_1, w_gray_sync_2;
    logic [ADDR_WIDTH:0] r_gray_sync_1, r_gray_sync_2;

    // Synchronize the Write Gray Pointer into the Read Clock Domain
    always_ff @(posedge r_clk or negedge r_rst_n) begin
        if (!r_rst_n) begin
            w_gray_sync_1 <= '0;
            w_gray_sync_2 <= '0;
        end else begin
            w_gray_sync_1 <= w_gray_ptr;   // Stage 1: Captures potential metastability
            w_gray_sync_2 <= w_gray_sync_1; // Stage 2: Settled and safe output value
        end
    end

    // Synchronize the Read Gray Pointer into the Write Clock Domain
    always_ff @(posedge w_clk or negedge w_rst_n) begin
        if (!w_rst_n) begin
            r_gray_sync_1 <= '0;
            r_gray_sync_2 <= '0;
        end else begin
            r_gray_sync_1 <= r_gray_ptr;   // Stage 1
            r_gray_sync_2 <= r_gray_sync_1; // Stage 2
        end
    end




    // --- STATUS SIGNAL FLAGGING LOGIC ---
    
    // FIFO is Empty when the local Read Gray Pointer exactly matches the synchronized Write Gray Pointer
    assign r_empty = (r_gray_ptr == w_gray_sync_2);
    
    // Almost Empty fires early when 2 or fewer items remain inside the array
    assign r_almost_empty = (r_bin_ptr + 2'd2 >= w_gray_sync_2);

    // FIFO is Full when the local Write Gray Pointer matches inverted top bits of synchronized Read Gray Pointer
    assign w_full = (w_gray_ptr == {~r_gray_sync_2[ADDR_WIDTH:ADDR_WIDTH-1], r_gray_sync_2[ADDR_WIDTH-2:0]});

    // Almost Full activates early when only 2 available storage locations remain unwritten
    assign w_almost_full = (w_bin_ptr + 2'd2 >= r_gray_sync_2);

endmodule
