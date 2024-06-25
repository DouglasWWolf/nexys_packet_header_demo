module packet_gen # (parameter DW=128)
(
    input   clk, resetn,

    // We start generating packets when this is asserted
    input   start,

    // Our output stream
    output     [DW-1:0]    axis_out_tdata,
    output reg [DW/8-1:0]  axis_out_tkeep,
    output                 axis_out_tlast,
    output                 axis_out_tvalid,
    input                  axis_out_tready
);

// This is the number of bytes in axis_out_tdata
localparam DB = (DW/8);

// How many bits does it take to represent "DB-1" ?
localparam LOG2_DB = $clog2(DB);

// This is 'LOG2_DB' '1' bits in a row
localparam DB_MASK = (1 << LOG2_DB) - 1;

// This is the number of different packet lengths we support
// and must be a power of 2
localparam MAX_ARRAY = 8;

// This is an array of packet lengths
wire[12:0] plen[MAX_ARRAY-1:0];

// This is an index into the 'plen' array
reg[$clog2(MAX_ARRAY)-1:0] plen_idx;

assign plen[0] = 18;
assign plen[1] = 128;
assign plen[2] = 1021;
assign plen[3] = 205;
assign plen[4] = 12;
assign plen[5] = 127;
assign plen[6] = 329;
assign plen[7] = 256;

// Current data-cycle, numbered 1 thru N
reg[15:0] cycle;

// The length of the packet currently being output
reg [12:0] packet_length;

// The number of "packed full" cycles in the packet
reg [15:0] whole_data_cycles;

// The number of bytes in the (potentially) partially full last cycle
reg [15:0] partial_bytes;

// The total number of data-cycles in the packet
reg [15:0] total_data_cycles;

always @* begin

    // This is the current packet length    
    packet_length = plen[plen_idx];

    // How many 'packed full' data cycles will there be?
    whole_data_cycles = (packet_length >> LOG2_DB);

    // If there's a "partial" cycle in the packet, how many bytes will it contain?
    partial_bytes = (packet_length & DB_MASK);

    // This is the total number of data-cycle required for this packet
    total_data_cycles = whole_data_cycles + (partial_bytes != 0);

    // Fill in 'axis_out_tkeep' with either "all bits set" or the final partial value
    axis_out_tkeep = (axis_out_tlast && partial_bytes) ? (1 << partial_bytes)-1 : -1;

end

// The state of our state machine
reg fsm_state;

// This is a rolling counter that will be replicated across axis_out_tdata
reg[15:0] data;

// axis_out_tlast is asserted on the last cycle of the packet
assign axis_out_tlast = (cycle == total_data_cycles);

// Repeat 'data' across the width of axis_out_tdata
assign axis_out_tdata = {(DW/16){data}};

// We're emitting valid data any time we're in state 1
assign axis_out_tvalid = (resetn == 1) && (fsm_state == 1);

always @(posedge clk) begin

    if (resetn == 0) begin
        fsm_state <= 0;
    end

    else case(fsm_state)

        0:  if (start) begin
                data      <= 1;
                plen_idx  <= 0;
                cycle     <= 1;
                fsm_state <= 1;
            end

        1:  if (axis_out_tready & axis_out_tvalid) begin
                data  <= data  + 1;
                cycle <= cycle + 1;
                if (axis_out_tlast) begin
                    cycle    <= 1;
                    plen_idx <= plen_idx + 1;
                end

            end

    endcase

end


endmodule

