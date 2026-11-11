// 2.3 Synchronous FIFO: parameterized width/depth (depth must be a power of two, >= 2)
// Pointers carry one extra wrap bit -> full/empty without a separate counter.
// Read data is registered: rdata is valid in the cycle after an accepted read (rvalid=1).
module sync_fifo #(parameter DATA_W = 8, parameter DEPTH = 16) (
    input  wire                  clk, rst,
    input  wire                  wr_en,
    input  wire [DATA_W-1:0]     wdata,
    input  wire                  rd_en,
    output reg  [DATA_W-1:0]     rdata,
    output reg                   rvalid,
    output wire                  full, empty,
    output wire [$clog2(DEPTH):0] count,
    output reg                   overflow, underflow   // 1-cycle pulses on rejected write / read
);
    localparam AW = $clog2(DEPTH);
    reg [DATA_W-1:0] mem [0:DEPTH-1];
    reg [AW:0] wptr, rptr;
    assign count = wptr - rptr;
    assign empty = (wptr == rptr);
    assign full  = (wptr[AW] != rptr[AW]) && (wptr[AW-1:0] == rptr[AW-1:0]);
    wire do_wr = wr_en && !full;     // write rejected when full (even if a read happens this cycle)
    wire do_rd = rd_en && !empty;    // read rejected when empty
    always @(posedge clk) begin
        if (rst) begin
            wptr <= 0; rptr <= 0; rvalid <= 0; rdata <= 0; overflow <= 0; underflow <= 0;
        end else begin
            overflow  <= wr_en && full;
            underflow <= rd_en && empty;
            rvalid    <= do_rd;
            if (do_wr) begin mem[wptr[AW-1:0]] <= wdata; wptr <= wptr + 1'b1; end
            if (do_rd) begin rdata <= mem[rptr[AW-1:0]]; rptr <= rptr + 1'b1; end
        end
    end
endmodule
