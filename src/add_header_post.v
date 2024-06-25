//=============================================================================
//               ------->  Revision History  <------
//=============================================================================
//
//   Date     Who   Ver  Changes
//=============================================================================
// 24-Jun-24  DWW     1  Initial creation
//=============================================================================

/*

    This module reads in a data-stream, and a paralell stream that carries the 
    packet lengths of the main stream.

    On the output stream, this module writes out the packets that were streamed
    in from the input, with each packet being preceded by a 1-data-cycle header
    that contains the length (in bytes) of the packet that follows.

*/
 

module add_header_post # (parameter DW = 128)
(
    input   clk, resetn, 

    // The input stream that carries packet data
    input      [DW-1:0]     axis_data_tdata,
    input      [(DW/8)-1:0] axis_data_tkeep,
    input                   axis_data_tlast,
    input                   axis_data_tvalid,
    output reg              axis_data_tready,


    // The input stream that carries packet lengths
    input      [15:0]       axis_plen_tdata,
    input                   axis_plen_tvalid,
    output reg              axis_plen_tready,


    // The output stream
    output reg [DW-1:0]     axis_out_tdata,
    output reg [(DW/8)-1:0] axis_out_tkeep,
    output reg              axis_out_tlast,
    output reg              axis_out_tvalid,
    input                   axis_out_tready

);


//=============================================================================
// This state machine waits for a single-data-cycle to be output from the
// packet-length input stream, then waits for an entire packet to be output
// from the data input stream, then repeats.
//
// This is a classic transition function for a Mealy state machine
//=============================================================================
reg fsm_state;
localparam FSM_WAIT_FOR_PLEN = 0;
localparam FSM_WRITE_PACKET  = 1;
//-----------------------------------------------------------------------------
always @(posedge clk) begin

    if (resetn == 0)
        fsm_state <= FSM_WAIT_FOR_PLEN;

    else case (fsm_state)

        // Wait for a header containing the packet-length to be output
        FSM_WAIT_FOR_PLEN:
            if (axis_out_tvalid & axis_out_tready)
                fsm_state <= FSM_WRITE_PACKET;

        // Wait for the entire data-packet to be output
        FSM_WRITE_PACKET:
            if (axis_out_tvalid & axis_out_tready & axis_out_tlast)
                fsm_state <= FSM_WAIT_FOR_PLEN;

    endcase
end
//=============================================================================


//=============================================================================
// Determine the state of our outputs in each state (including reset)
//
// This is a textbook example of a Mealy state machine
//=============================================================================
always @* begin
    
    if (resetn == 0) begin
        axis_out_tdata   = 0;
        axis_out_tkeep   = 0;
        axis_out_tlast   = 0;
        axis_out_tvalid  = 0;
        axis_data_tready = 0;
        axis_plen_tready = 0;
    end
    
    else case(fsm_state)

    // In this state, axis_out is fed from axis_plen
    FSM_WAIT_FOR_PLEN:
        begin
            axis_out_tdata   = axis_plen_tdata;
            axis_out_tkeep   = -1;
            axis_out_tlast   = 0;
            axis_out_tvalid  = axis_plen_tvalid;
            axis_data_tready = 0;
            axis_plen_tready = axis_out_tready;
        end

    // In this state, axis_out is fed from axis_data
    FSM_WRITE_PACKET:
        begin
            axis_out_tdata   = axis_data_tdata;
            axis_out_tkeep   = axis_data_tkeep;
            axis_out_tlast   = axis_data_tlast;
            axis_out_tvalid  = axis_data_tvalid;
            axis_data_tready = axis_out_tready;
            axis_plen_tready = 0;
        end

    endcase

end
//=============================================================================

endmodule