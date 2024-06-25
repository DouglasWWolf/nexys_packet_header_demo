//=============================================================================
//               ------->  Revision History  <------
//=============================================================================
//
//   Date     Who   Ver  Changes
//=============================================================================
// 24-Jun-24  DWW     1  Initial creation
//=============================================================================

/*

    This module reads in an arbitrary data stream, and passes it directly to
    the axis_out output stream, unaltered.

    While the stream is passing through, this module counts the length of the
    packets in that stream and writes that value to the axis_plen output stream

*/


module add_header_pre # (parameter DW = 128)
(
    input   clk, resetn,

    // The input stream
    input[DW-1:0]      axis_in_tdata,
    input[(DW/8)-1:0]  axis_in_tkeep,
    input              axis_in_tlast,
    input              axis_in_tvalid,
    output             axis_in_tready,

    // The main output stream
    output[DW-1:0]     axis_out_tdata,
    output[(DW/8)-1:0] axis_out_tkeep,
    output             axis_out_tlast,
    output             axis_out_tvalid,
    input              axis_out_tready,


    // The "packet length" output stream
    output[15:0]       axis_plen_tdata,
    output             axis_plen_tvalid,
    input              axis_plen_tready
);


//=============================================================================
// one_bits() - This function counts the '1' bits in a field
//=============================================================================
integer i;
function[15:0] one_bits(input[(DW/8)-1:0] field);
begin
    one_bits = 0;
    for (i=0; i<(DW/8); i=i+1) one_bits = one_bits + field[i];
end
endfunction
//=============================================================================


// The input stream passes directly to the output stream
assign axis_out_tdata  = axis_in_tdata;
assign axis_out_tkeep  = axis_in_tkeep;
assign axis_out_tlast  = axis_in_tlast;
assign axis_out_tvalid = axis_in_tvalid;
assign axis_in_tready  = axis_out_tready;

// As a packet passes through, this will accumulate the packet length thus far
reg[15:0] plen_accumulator;

// This is the length of the packet thus far.  On the last data-cycle of
// the packet, this will contain the length of the entire packet
wire [15:0] packet_length = plen_accumulator + one_bits(axis_out_tkeep);


// We write to the "packet length" stream when the last data-cycle of a
// packet is accepted on the output stream
assign axis_plen_tvalid = axis_out_tvalid & axis_out_tready & axis_out_tlast;

// The data on "axis_plen" is the length of the packet we just output
assign axis_plen_tdata  = packet_length;


//=============================================================================
// Every time a valid data-cycle is accepted on the output, accumulate the 
// length of the packet thus far.   Note that "plen_accumulator" will never
// include the length of the very last data-cycle in the packet
//=============================================================================
always @(posedge clk) begin
    if (resetn == 0)
        plen_accumulator <= 0;
    else if (axis_out_tvalid & axis_out_tready) begin
        if (axis_out_tlast)
            plen_accumulator <= 0;
        else
            plen_accumulator <= packet_length;
    end
end
//=============================================================================

endmodule
