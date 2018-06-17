\m4_TLV_version 1d: tl-x.org
\SV
/*
Copyright (c) 2018, Steve Hoover
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

* Neither the name of the copyright holder nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

m4_include_url(['https:/']['/raw.githubusercontent.com/stevehoover/tlv_flow_lib/master/fundamentals_lib.tlv'])
m4_include_url(['https:/']['/raw.githubusercontent.com/stevehoover/tlv_flow_lib/master/pipeflow_lib.tlv'])

//m4_top_module_def(top)
m4_makerchip_module()

m4_define_hier(M4_RING_STOP, 4, 0)
//parameter RING_STOPS = 4;
//m4_define(M4_RING_STOPS_WIDTH, 2)
//parameter RING_STOPS_WIDTH = M4_RING_STOPS_WIDTH;  //$clog2(RING_STOPS); // roundup(log2(RING_STOPS))
m4_define(M4_PACKET_SIZE, 16)
parameter PACKET_SIZE = M4_PACKET_SIZE;


                                                                          
\SV
   bit n_clk;
   assign n_clk = ! clk;


// Testbench
\TLV
   /tb
      |count
         @1
            $CycCount[15:0] <= /top|default>>1$reset ? 16'b0 :
                                                       $CycCount + 1;
            \SV_plus
               always_ff @(posedge clk) begin
                  \$display("Cycle: %0d", $CycCount);
               end
      /M4_RING_STOP_HIER
         // STIMULUS
         |send
            @1
               $valid_in = /tb|count<>0$CycCount == 3;
               ?$valid_in
                  /gen_trans
                     $sender[M4_RING_STOP_INDEX_RANGE] = ring_stop;
                     //m4_rand($size, M4_PACKET_SIZE-1, 0, ring_stop) // unused
                     m4_rand($dest_tmp, M4_RING_STOP_INDEX_MAX, 0, ring_stop)
                     $dest[M4_RING_STOP_INDEX_RANGE] = $dest_tmp % M4_RING_STOP_CNT;
                     //$dest[M4_RING_STOP_INDEX_RANGE] = ring_stop;
                     //$packet_valid = ring_stop == 0 ? 1'b1 : 1'b0; // valid for only first ring_stop - unused
               $trans_valid = $valid_in || /ring_stop|receive<>0$request;
               ?$trans_valid
                  /trans_out
                     $ANY = /ring_stop|receive<>0$request ? /ring_stop|receive/trans<>0$ANY :
                                                            |send/gen_trans$ANY;
                     
                     \SV_plus
                        always_ff @(posedge clk) begin
                           \$display("\|send[%0d]", ring_stop);
                           \$display("Sender: %0d, Destination: %0d", $sender, $dest);
                        end
                     
         |receive
            @1
               $reset = /top|default>>1$reset;
               $trans_valid = /top/ring_stop|fifo2_out>>1$trans_valid;
               $request = $trans_valid && /trans$sender != ring_stop;
               $received = $trans_valid && /trans$sender == ring_stop;
               $NumPackets[PACKET_SIZE-1:0] <= $reset                      ? '0 :
                                               /ring_stop|send<>0$valid_in ? $NumPackets + 1 :
                                               $request                    ? $NumPackets :
                                               $received                   ? $NumPackets - 1 :
                                                                             $NumPackets;
               ?$trans_valid
                  /trans
                     $ANY = /top/ring_stop|fifo2_out/trans<>0$ANY;
                     $dest[M4_RING_STOP_INDEX_RANGE] = |receive$request ? $sender : $dest;
      |pass
         @1
            $reset = /top|default>>1$reset;
            $packets[M4_RING_STOP_CNT * PACKET_SIZE - 1 : 0] = /tb/ring_stop[*]|receive<>0$NumPackets;
            *passed = !$reset && ($packets == '0) && (/tb|count<>0$CycCount > 3);
   
// DUT
\TLV
   
   // Reset as a pipesignal.
   |default
      @0
         $reset = *reset;

   // Ring
   /ring_stop[M4_RING_STOP_RANGE]
      // Stall Pipeline
      |stall0
         @1
            $reset = /top|default<>0$reset;
            $avail = ! $reset && /top/tb/ring_stop|send<>0$trans_valid;
            $trans_valid = $avail && ! $blocked;
            ?$trans_valid
               /trans
                  $ANY = /top/tb/ring_stop|send/trans_out<>0$ANY;

      // The input transaction.
      //               (   top,     name,  first_cycle, last_cycle, trans)
      m4+stall_pipeline(/ring_stop, |stall,      0,          3, /trans)
      m4+flop_fifo_v2(/ring_stop, |stall3,     @1,     |bp0,    @1,        4,     /trans)
      m4+bp_pipeline(/ring_stop, |bp, 0, 3, /trans)
      |bp3
         @1
            $local = /trans$dest != #ring_stop;
      m4+opportunistic_flow(/ring_stop, |bp3, @1, |bypass, @1, $local, |ring_in, @1, /trans)
   //            (  hop,    in_pipe, in_stage, out_pipe, out_stage, reset, ring_pipe_name, trans)
   m4+simple_ring(/ring_stop, |ring_in, @1, |ring_out, @1, /top|default<>0$reset, |rg, /trans)
   
   /ring_stop[*]
      m4+arb2(/ring_stop, |ring_out, @4, |bypass, @1, |arb_out, @1, /trans)

      // Free-Flow Pipeline after Arb

      // FIFO2
      // TODO: should be |arb_out@5
      m4+flop_fifo_v2(/ring_stop, |arb_out, @1, |fifo2_out, @1, 4, /trans)        
      |fifo2_out
         @0
            $blocked = 1'b0;
   
   
// Print
\TLV
   /ring_stop[*]
      |stall0
         @1
            /trans
               \SV_plus
                  always_ff @(posedge clk) begin
                     \$display("\|stall0[%0d]", ring_stop);
                     \$display("Destination: %0d", $dest);
                  end
      |stall1
         @1
            /trans
               \SV_plus
                  always_ff @(posedge clk) begin
                     \$display("\|stall1[%0d]", ring_stop);
                     \$display("Destination: %0d", $dest);
                  end
      |stall2
         @1
            /trans
               \SV_plus
                  always_ff @(posedge clk) begin
                     \$display("\|stall2[%0d]", ring_stop);
                     \$display("Destination: %0d", $dest);
                  end
      |stall3
         @1
            /trans
               \SV_plus
                  always_ff @(posedge clk) begin
                     \$display("\|stall3[%0d]", ring_stop);
                     \$display("Destination: %0d", $dest);
                  end
      |bp3
         @1
            /trans
               \SV_plus
                  always_ff @(posedge clk) begin
                     \$display("\|bp3[%0d]", ring_stop);
                     \$display("Destination: %0d", $dest);
                  end
      |ring_in
         @1
            /trans
               \SV_plus
                  always_ff @(posedge clk) begin
                     \$display("\|ring_in[%0d]", ring_stop);
                     \$display("Destination: %0d", $dest);
                  end
      |ring_out
         @2
            /trans
               \SV_plus
                  always_ff @(posedge clk) begin
                     \$display("\|ring_out[%0d]", ring_stop);
                     \$display("Destination: %0d", $dest);
                  end

      |arb_out
         @1
            /trans
               \SV_plus
                  always_ff @(posedge clk) begin
                     \$display("\|arb_out[%0d]", ring_stop);
                     \$display("Destination: %0d", $dest);
                  end
      |fifo2_out
         @1
            /trans
               \SV_plus
                  always_ff @(posedge clk) begin
                     \$display("\|fifo2_out[%0d]", ring_stop);
                     \$display("Destination: %0d", $dest);
                  end

\SV
endmodule 
