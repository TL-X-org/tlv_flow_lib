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



\TLV arb(/_top_in1, /_top_in2, |_in1, |_in2, |_arb_out, /_trans)
   m4_pushdef(['m4_trans_ind'], m4_ifelse(/_trans, [''], [''], ['   ']))
   |arb_out
      @0
         // bypass if pipe1 does not have a valid transaction and FIFO does
         // and packet's destination is same as ring_stop
         $bypass = !(/_top_in1|_in1>>1$trans_valid) &&
                   /_top_in2|_in2>>1$trans_valid &&
                   /_top_in2|_in2/_trans>>1$dest == ring_stop;
         $trans_valid = $bypass ||
                        /_top_in1|_in1>>1$trans_valid;
         ?$trans_valid
            /_trans
         m4_trans_ind   $ANY = |arb_out$bypass ? /ring_stop/stall_pipe|_in2/_trans>>1$ANY :
                                        /_top_in1|_in1/_trans>>1$ANY;
   m4_popdef(['m4_trans_ind'])

\SV
   bit n_clk;
   assign n_clk = ! clk;
\TLV

   // testbench
   /tb
      |count
         @0
            $CycCount[15:0] <= /top|default>>1$reset ? 16'b0 :
                                                       $CycCount + 1;
            \SV_plus
               always_ff @(posedge clk) begin
                  \$display("Cycle: %0d", $CycCount);
               end
      /M4_RING_STOP_HIER
         // STIMULUS
         |send
            @0
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
            @0
               $reset = /top|default>>1$reset;
               $trans_valid = /top/ring_stop/pipe2|fifo2_out>>1$trans_valid;
               $request = $trans_valid && /trans$sender != ring_stop;
               $received = $trans_valid && /trans$sender == ring_stop;
               $NumPackets[PACKET_SIZE-1:0] <= $reset                      ? '0 :
                                               /ring_stop|send<>0$valid_in ? $NumPackets + 1 :
                                               $request                    ? $NumPackets :
                                               $received                   ? $NumPackets - 1 :
                                                                             $NumPackets;
               ?$trans_valid
                  /trans
                     $ANY = /top/ring_stop/pipe2|fifo2_out/trans>>1$ANY;
                     $dest[M4_RING_STOP_INDEX_RANGE] = |receive$request ? $sender : $dest;
      |pass
         @0
            $reset = /top|default>>1$reset;
            $packets[M4_RING_STOP_CNT * PACKET_SIZE - 1 : 0] = /tb/ring_stop[*]|receive<>0$NumPackets;
            *passed = !$reset && ($packets == '0) && (/tb|count<>0$CycCount > 3);
   
   // Reset as a pipesignal.
   |default
      @0
         $reset = *reset;

   // Ring
   /ring_stop[M4_RING_STOP_RANGE]
      |ring_in
         @0
            $reset = /top|default>>1$reset;
            // transaction available if not reset and FIFO has valid transaction
            // and packet's destination is not the same as ring_stop
            $avail = ! $reset && /ring_stop/stall_pipe|bp_out>>1$accepted &&
                           /ring_stop/stall_pipe|bp_out/trans>>1$dest != ring_stop;
            $trans_valid = $avail && ! $blocked;
            ?$trans_valid
               /trans
                  $ANY = /ring_stop/stall_pipe|bp_out/trans>>1$ANY;
   //            (  hop,    in_pipe, in_stage, out_pipe, out_stage, reset_scope,  reset_stage, reset_sig)
   m4+simple_ring(/ring_stop, |ring_in,    @0,     |ring_out,     @0,     /top|default,      @1,       $reset, |rg, /trans)
   
   /ring_stop[*]
      // Stall Pipeline
      /stall_pipe
         |stall0
            @1
               $reset = /top|default<>0$reset;
               $trans_avail = ! $reset && /top/tb/ring_stop|send<>0$trans_valid;
               $trans_valid = $trans_avail && ! $blocked;
               ?$trans_valid
                  /trans
                     $ANY = /top/tb/ring_stop|send/trans_out<>0$ANY;
      
      // The input transaction.
      /stall_pipe
         //               (   top,     name,  first_cycle, last_cycle, trans)
         m4+stall_pipeline(/stall_pipe, |stall,      0,          3, /trans)
         |stall3
            @1
               $trans_valid = $accepted;
         // FIFO
         //             (   top,     in_pipe, in_stage, out_pipe, out_stage, depth, trans_hier)
         m4+flop_fifo_v2(/stall_pipe, |stall3,     @1,     |fifo_out,    @0,        4,     /trans)        
         // Phase-based logic isn't fully ironed-out yet.
         // Clock enables are required a full cycle prior to their use by SandPiper.
         // The condition on |fifo_out$ANY causes problems.
         // So we create an unconditioned version in it's own pipeline, and we
         // Hook the pipelines together @0 in both directions.
         |fifo_out
            @0
               $blocked = /stall_pipe|fifo_out_unconditioned<>0$blocked;
               //$accepted = /stall_pipe|fifo_out_unconditioned<>0$accepted;
         |fifo_out_unconditioned
            @0
               $avail = /stall_pipe|fifo_out<>0$trans_avail;
               /trans
                  $ANY = /stall_pipe|fifo_out/trans<>0$ANY;
         m4+bp_stage(/stall_pipe, |fifo_out_unconditioned, @0, |bp_out, @0, /trans, 0, 1)
         
         // Steer bp_out to arb or ring. Make this a flow component.
         // "opportunistic_path"
         |bp_out
            @0
               // blocked if destination is same as ring_stop
               $blocked = 1'b0; // >fifo_head>trans$dest == ring_stop;
               $accepted = $avail && ! $blocked;

      m4+arb(/ring_stop, /ring_stop/stall_pipe, |ring_out, |fifo_out, |arb_out, /trans);

      // Free-Flow Pipeline after Arb
      /pipe2
         |pipe2
            @0
               $reset = /top|default>>1$reset;
               $trans_avail = ! $reset && /ring_stop|arb_out>>1$trans_valid;
               $trans_valid = $trans_avail && ! $blocked;
               ?$trans_valid
                  /trans
                     $ANY = /ring_stop|arb_out/trans>>1$ANY;
         
         // FIFO2
         //             ( top,  in_pipe, in_stage, out_pipe,  out_stage, depth, trans_hier)
         m4+flop_fifo_v2(/pipe2, |pipe2,     @0,     |fifo2_out,    @0,        4,     /trans)        
         |fifo2_out
            @0
               $blocked = 1'b0;
   
   // Print
   /ring_stop[*]
      /stall_pipe
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
         |bp_out
            @0
               /trans
                  \SV_plus
                     always_ff @(posedge clk) begin
                        \$display("\|bp_out[%0d]", ring_stop);
                        \$display("Destination: %0d", $dest);
                     end
      |ring_in
         @0
            /trans
               \SV_plus
                  always_ff @(posedge clk) begin
                     \$display("\|ring_in[%0d]", ring_stop);
                     \$display("Destination: %0d", $dest);
                  end
      |ring_out
         @1
            /trans
               \SV_plus
                  always_ff @(posedge clk) begin
                     \$display("\|ring_out[%0d]", ring_stop);
                     \$display("Destination: %0d", $dest);
                  end

      |arb_out
         @0
            /trans
               \SV_plus
                  always_ff @(posedge clk) begin
                     \$display("\|arb_out[%0d]", ring_stop);
                     \$display("Destination: %0d", $dest);
                  end
      /pipe2
         |pipe2
            @0
               /trans
                  \SV_plus
                     always_ff @(posedge clk) begin
                        \$display("\|pipe2[%0d]", ring_stop);
                        \$display("Destination: %0d", $dest);
                     end
         |fifo2_out
            @0
               /trans
                  \SV_plus
                     always_ff @(posedge clk) begin
                        \$display("\|fifo2_out[%0d]", ring_stop);
                        \$display("Destination: %0d", $dest);
                     end

\SV
endmodule 
