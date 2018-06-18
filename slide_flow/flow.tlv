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

m4_makerchip_module()

m4_define_hier(M4_RING_STOP, 4, 0)

//\SV
//   bit n_clk;
//   assign n_clk = ! clk;


\TLV
   // DUT
   $reset = *reset;
   
   // Testbench
   m4+router_tb(/top, /ring_stop, |stall0, @1, |fifo2_out, @1, /trans, /top<>0$reset)
   
   // Ring
   /M4_RING_STOP_HIER
      |stall0
         @0
            $reset = /top<>0$reset;
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
   m4+simple_ring(/ring_stop, |ring_in, @1, |ring_out, @1, /top<>0$reset, |rg, /trans)
   
   /ring_stop[*]
      m4+arb2(/ring_stop, |ring_out, @4, |bypass, @1, |arb_out, @1, /trans)

      // Free-Flow Pipeline after Arb

      // FIFO2
      // TODO: should be |arb_out@5
      m4+flop_fifo_v2(/ring_stop, |arb_out, @1, |fifo2_out, @1, 4, /trans)        
   
   
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
