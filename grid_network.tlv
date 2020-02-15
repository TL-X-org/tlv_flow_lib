\m4_TLV_version 1d: tl-x.org
\SV
/*
Copyright (c) 2018, Steven F. Hoover

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * The name of Steven F. Hoover
      may not be used to endorse or promote products derived from this software
      without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

// ================================================================
// BE SURE TO CHOOSE AN APPROPRIATE LIBRARY DURING DEVELOPMENT.
m4_include_url(['https://raw.githubusercontent.com/stevehoover/tlv_lib/master/fundamentals_lib.tlv'])
m4_include_url(['https://raw.githubusercontent.com/stevehoover/tlv_flow_lib/master/pipeflow_lib.tlv'])
// ================================================================

// This example implements an on-chip network, implemented as an X-Y-routed grid.
// Each network tile has five bi-directional links: four neighboring tile grid-links
// and its own endpoint link.  These are named: (X-1)-link, (X+1)-link, (Y-1)-link,
// (Y+1)-link, and E-link, each with an i (input) and o (output) direction
// (eg: (X-1)-olink is the outbound link to the X-1 tile; E-olink is out of network).
//
// Packets contain multiple flits, where a flit occupies a single-cycle on a
// link.  Idle flits may be injected at any time, between or within packets.
// They will disappear
// when queued, but will otherwise occupy slots when routed.  Packets should
// generally be injected contiguously, with idles only in exceptional circumstances.
// Packet size is determined only by a tail flit; there is no 'size' field in the
// packet header.  Packets are routed contiguously and can block other traffic,
// so large packets can introduce undesireable network characteristics.
// Packetization can be done at a higher level to address this.
//
// Network buffering is minimal.  However, when packets are blocked, the E-link can
// be used to alleviate the congestion if the packet is "unordered" and if the
// intermediate tile is able to absorb the packet (size needed?) and reinject it.
//
// Virtual channels/lanes/networks are supported for protocol deadlock
// avoidance, prioritization, and independence.  Each VC has a static
// priority assigned.
//
// Priority of traffic is as follows, highest to lowest.
// On an outgoing network(X/Y)-olink:
//   - The next flit following the previous one (non-tail, including idle).
//   - Among queued non-head flits of the highest queued-traffic priority, or if
//     none, head flits of the highest queued head flit priority, or if none,
//     heads arriving this cycle:
//     - Traffic continuing in a straight path.
//     - Traffic taking a turn (Y-links only because of X-Y routing).
//     - Traffic entering from the E-link.
// On an E-ilink:
//   - The next flit following the previous one (including idle).
//   - The flit selected based on last cycle's head info using round-robin
//     among heads waiting for this endpoint.  The head flit is dropped,
//     so no cycle is lost.
//   - 
// At each link 

m4_makerchip_module
/* verilator lint_off UNOPTFLAT */

m4_define_hier(M4_XX, 2, 0)
m4_define_hier(M4_YY, 2, 0)
m4_define_hier(M4_PRIO, 2, 0)
m4_define_hier(M4_VC, 2, 0)
m4_define_hier(M4_FLIT_CNT, 16, 0)



\TLV
   |reset
      @-1
         // Create pipesignal out of reset module input.
         $reset = *reset;

   // Stimulus
   //
   /M4_YY_HIER
      /M4_XX_HIER
         |tb_gen
            // Generate stimulus feeding the E-Link input FIFO.
            @1
               $reset = /top|reset<>0$reset;
               m4_rand($head_tail_rand, 2, 0, (yy * xx) ^ ((3 * xx) + yy))
               $head = ! $MidPacket &&              // can be head
                       (& $head_tail_rand) &&       // 1/8 probability
                       ! $reset &&                  // after reset
                       (/top|tb_gen$CycCnt < 100);  // until max cycle
               $tail = ! $reset &&
                       ($head || $MidPacket) &&   // can be tail
                       ((& $head_tail_rand) ||    // 1/8 probability
                        ($PktCnt >= M4_FLIT_CNT_MAX));  // force tail on max length
               // $MidPacket = after head through tail.
               $MidPacket <= ! $reset && (($head && ! $trans_valid) || $MidPacket) && ! ($tail && ! $trans_valid);
               
               // Packet and flit-within-packet counts.
               $reset_or_head = $reset || $head;
               ?$reset_or_head
                  $PktCnt[7:0] <= $reset ? 0 : $PktCnt + 1;
               $reset_or_trans_valid = $reset | $trans_valid;
               ?$reset_or_trans_valid
                  $FlitCnt[3:0] <= ($reset || $tail) ? 0 : $FlitCnt + 1;
               
               // verilator lint_off CMPCONST */
               m4_rand($vc_rand, M4_VC_INDEX_MAX, 0, (yy * xx) ^ ((3 * yy) + yy))
               $vc[M4_VC_INDEX_MAX:0] = ($vc_rand > M4_VC_MAX)        // out of range?
                           ? // drop the max bit in range
                             $vc_rand && ~(M4_VC_INDEX_CNT'b1 << M4_VC_INDEX_MAX)
                           : $vc_rand;
               m4_rand($rand_valid, 2, 0, (yy * xx) ^ ((3 * xx) + yy))
               $trans_valid = ($head || $MidPacket) && (| $rand_valid) && ! /xx/vc[$vc]|tb_gen$blocked;   // 1/8 probability of idle
               ?$trans_valid
                  /flit
                     // Generate a random flit.
                     // Random values from which to generate flit:
                     m4_rand($dest_x_rand, M4_XX_INDEX_MAX, 0, (yy * xx) ^ ((3 * xx) + yy))
                     m4_rand($dest_y_rand, M4_YY_INDEX_MAX, 0, (yy * xx) ^ ((3 * xx) + yy))
                     // Flit:
                     $vc[M4_VC_INDEX_RANGE] = |tb_gen$vc;
                     $head = |tb_gen$head;
                     $tail = |tb_gen$tail;
                     $pkt_cnt[7:0] = |tb_gen$PktCnt;
                     $flit_cnt[3:0] = |tb_gen$FlitCnt;
                     $src_x[M4_XX_INDEX_RANGE] = xx;
                     $src_y[M4_YY_INDEX_RANGE] = yy;
                     $dest_x[M4_XX_INDEX_RANGE] = ($dest_x_rand > M4_XX_MAX) // out of range?
                                  ? // drop the max bit in range
                                    $dest_x_rand && ~(M4_XX_INDEX_CNT'b1 << M4_XX_INDEX_MAX)
                                  : $dest_x_rand;
                     $dest_y[M4_YY_INDEX_RANGE] = ($dest_y_rand > M4_YY_MAX) // out of range?
                                  ? // drop the max bit in range
                                    $dest_y_rand && ~(M4_YY_INDEX_CNT'b1 << M4_YY_INDEX_MAX)
                                  : $dest_y_rand;
                     m4_rand($data, 7, 0, (yy * xx) ^ ((3 * xx) + yy))
               // verilator lint_on CMPCONST */
               
               
   //
   // Design
   //
   
   /yy[*]
      /xx[*]
         
         // E-Link
         //
         // Into Network

         /M4_VC_HIER
            |tb_gen
               @1
                  $vc_trans_valid = /xx|tb_gen$trans_valid && (/xx|tb_gen/flit$vc == #vc);
            |netwk_inject
               @0
                  $Prio[M4_VC_INDEX_RANGE] <= vc;  // Prioritize based on VC.
         //m4+vc_flop_fifo_v2(xx, tb_gen, 1, netwk_inject, 1, 6, >flit, M4_VC_MAX:M4_VC_MIN, M4_PRIO_MAX:M4_PRIO_MIN)
         m4+vc_flop_fifo_v2(/xx, |tb_gen, @1, |netwk_inject, @1, 6, /flit, M4_VC_RANGE, M4_PRIO_RANGE)
         /vc[*]
            |netwk_inject
               @0
                  $has_credit = ! /vc|netwk_eject>>2$full;  // Temp loopback.  (Okay if not one-entry remaining ("full") after two-transactions previous to this (one intervening).)

         /*
         // Network X/Y +1/-1 Links
         >direction[1:0]  // 1: Y, 0: X
            >sign[1:0]  // 1: +1, 0: -1
               //
               // Connect upstream grid link.
               |grid_out
               |grid_in
                  @0
                     \SV_plus
                        // Characterize connection.
                        localparam DANGLE = ((*direction == 0) ? (*xx == ((*sign == 0) ? M4_XX_MAX : 0))
                                                               : (*yy == ((*sign == 0) ? M4_YY_MAX : 0))
                                            );  // At edge.  No link.
                        localparam UPSTREAM_X = (*direction == 1) ? *xx : ((*sign == 0) ? (*xx + 1) : (*xx - 1));
                        localparam UPSTREAM_Y = (*direction == 0) ? *yy : ((*sign == 0) ? (*yy + 1) : (*yy - 1));
                        // Connect control.
                        if (DANGLE)
                           assign $$trans_valid = '0;
                        else
                           assign $trans_valid = >yy[*UPSTREAM_Y]>xx[*UPSTREAM_X]>direction>sign|grid_out$trans_valid;
                     >flit
                        // Connect transaction.
                        \SV_plus
                           if (DANGLE)
                              assign $$ANY = '0;
                           else
                              // Connect w/ upstream tile.
                              assign $ANY = >yy[*UPSTREAM_Y]>xx[*UPSTREAM_X]>direction>sign|grid_out$ANY;
               
               // Grid FIFOs.
               >M4_VC_HIER
                  |grid_fifo_out
                     @0
                        %next$Prio = >xx>vc|netwk_inject%+0$Prio;
                     >M4_PRIO_HIER
               >M4_PRIO_HIER
                  |grid_fifo_out
                     >M4_VC_HIER
               m4 +vc_flop_fifo_v2(sign, grid_in, 1, grid_fifo_out, 1, 1, >flit, M4_VC_MAX:M4_VC_MIN, M4_PRIO_MAX:M4_PRIO_MIN)
               |grid_fifo_out
                  @1
                     $blocked = ...;
                     */
               
            
         // O-Link
         //
         // Out of Network
         
         /M4_VC_HIER
            
            //+// Credit, reflecting 
            //+m4_credit_counter(['            $1'], ']m4___file__[', ']m4___line__[', ['m4_['']credit_counter(...)'], $Credit, 1, 2, $reset, $push, >vc|m4_out_pipe%m4_bypass_align$trans_valid)

         /vc[*]
            |netwk_eject
               @1
                  $vc_trans_valid = /vc|netwk_inject<>0$vc_trans_valid; /* temp loopback */
         |netwk_eject
            @1
               $reset = /top|reset<>0$reset;
               $trans_valid = /xx|netwk_inject<>0$trans_valid; /* temp loopback */
               ?$trans_valid
                  /flit
                     $ANY = /* temp loopback */ /xx|netwk_inject/flit<>0$ANY;
         //m4+vc_flop_fifo_v2(xx, netwk_eject, 1, tb_out, 1, 6, >flit, M4_VC_MAX:M4_VC_MIN, M4_PRIO_MAX:M4_PRIO_MIN, 1, 1)
         m4+vc_flop_fifo_v2(/xx, |netwk_eject, @1, |tb_out, @1, 6, /flit, M4_VC_RANGE, M4_PRIO_RANGE, @1, 1)
         /vc[*]
            |tb_out
               @0
                  $Prio[M4_VC_INDEX_RANGE] <= /vc|netwk_inject<>0$Prio;
                  m4_rand($has_credit, 0, 0, (yy * xx) ^ ((3 * xx) + yy))
         |tb_out
            @1
               ?$trans_valid
                  /flit
                     `BOGUS_USE($head $tail $data)
               
   //==========
   // Testbench
   //
   |tb_gen
      
      @-1
         // Free-running cycle count.
         $CycCnt[15:0] <= /top|reset<>0$reset ? 16'b0 : $CycCnt + 16'b1;
      
      @1
         /yy[M4_YY_RANGE]
            /xx[M4_XX_RANGE]
               // Keep track of how many flits were injected.
               $inj_cnt[M4_XX_INDEX_RANGE] = /top/yy/xx|tb_gen$trans_valid ? 1 : 0;
            m4+redux($inj_row_sum[(M4_XX_INDEX_CNT + M4_YY_INDEX_CNT)-1:0], /xx, M4_XX_MAX, 0, $inj_cnt, '0, +)
         m4+redux($inj_sum[(M4_XX_INDEX_CNT + M4_YY_INDEX_CNT)-1:0], /yy, M4_YY_MAX, 0, $inj_row_sum, '0, +)
      @1
         $inj_cnt[(M4_XX_INDEX_CNT + M4_YY_INDEX_CNT)-1:0] = /top|reset<>0$reset ? '0 : $inj_sum;
      
   |tb_out
      m4_define(['m4_gen_align'], ['0'])  // Alignment below with |tb_gen.

      @1
         $reset = /top|reset<>0$reset;
      @2
         /yy[M4_YY_RANGE]
            /xx[M4_XX_RANGE]
               // Keep track of how many flits came out.
               $eject_cnt[M4_XX_INDEX_RANGE] = /top/yy/xx|tb_out$trans_valid ? 1 : 0;
            m4+redux($eject_row_sum[(M4_XX_INDEX_CNT + M4_YY_INDEX_CNT)-1:0], /xx, M4_XX_MAX, 0, $eject_cnt, '0, +)
         m4+redux($eject_sum[(M4_XX_INDEX_CNT + M4_YY_INDEX_CNT)-1:0], /yy, M4_YY_MAX, 0, $eject_row_sum, '0, +)
         $eject_cnt[(M4_XX_INDEX_CNT + M4_YY_INDEX_CNT)-1:0] = $reset ? '0 : $eject_sum;
         $FlitsInFlight[31:0] <= $reset ? '0 : $FlitsInFlight + {{31 - (M4_XX_INDEX_CNT + M4_YY_INDEX_CNT){1'b0}}, /top|tb_gen<>0$inj_cnt - $eject_cnt};
         
      m4_define(['m4_gen_flit'], ['top/yy[y]/xx[m4_x]|tb_gen/flit>>m4_gen_align'])  // Refers to flit in tb_gen scope.
      m4_define(['m4_out_flit'], ['top/yy[y]/xx[m4_x]|tb_out/flit'])  // Refers to flit in tb_out scope.
      @2
         \SV_plus
            always_ff @(posedge clk) begin
               if (! $reset) begin
                  \$display("-In- m4_forloop(m4_x,M4_XX_LOW,M4_XX_HIGH-1,['    '])   -Out-      (Cycle: \%d, Inflight: \%d)", /top|tb_gen>>m4_gen_align$CycCnt, $FlitsInFlight);
                  \$display("/m4_forloop(m4_x,M4_XX_LOW,M4_XX_HIGH-1,---+)---\\\\   /m4_forloop(m4_x,M4_XX_LOW,M4_XX_HIGH-1,---+)---\\\\");
                  for(int y = 0; y <= M4_YY_MAX; y++) begin
                     \$display("\|m4_forloop(m4_x,M4_XX_LOW,M4_XX_HIGH,['\%1h\%1h\%1h\|'])   \|m4_forloop(m4_x,M4_XX_LOW,M4_XX_HIGH,['\%1h\%1h\%1h\|'])"m4_forloop(m4_x,M4_XX_LOW,M4_XX_HIGH,[', /m4_gen_flit$dest_x, /m4_gen_flit$dest_y, /m4_gen_flit$vc'])m4_forloop(m4_x,M4_XX_LOW,M4_XX_HIGH,[', /m4_out_flit$dest_x, /m4_out_flit$dest_y, /m4_out_flit$vc']));
                     \$display("\|m4_forloop(m4_x,M4_XX_LOW,M4_XX_HIGH,['\%1h\%1h\%1h\|'])   \|m4_forloop(m4_x,M4_XX_LOW,M4_XX_HIGH,['\%1h\%1h\%1h\|'])"m4_forloop(m4_x,M4_XX_LOW,M4_XX_HIGH,[', /m4_gen_flit$src_x, /m4_gen_flit$src_y, /m4_gen_flit$vc'])m4_forloop(m4_x,M4_XX_LOW,M4_XX_HIGH,[', /m4_out_flit$src_x, /m4_out_flit$src_y, /m4_out_flit$vc']));
                     \$display("\|m4_forloop(m4_x,M4_XX_LOW,M4_XX_HIGH,['%2h\%1h\|'])   \|m4_forloop(m4_x,M4_XX_LOW,M4_XX_HIGH,['\%2h\%1h\|'])"m4_forloop(m4_x,M4_XX_LOW,M4_XX_HIGH,[', /m4_gen_flit$pkt_cnt, /m4_gen_flit$flit_cnt'])m4_forloop(m4_x,M4_XX_LOW,M4_XX_HIGH,[', /m4_out_flit$pkt_cnt, /m4_out_flit$flit_cnt']));
                     if (y < M4_YY_MAX) begin
                        \$display("+m4_forloop(m4_x,M4_XX_LOW,M4_XX_HIGH,---+)   +m4_forloop(m4_x,M4_XX_LOW,M4_XX_HIGH,---+)");
                     end
                  end
                  \$display("\\\\m4_forloop(m4_x,M4_XX_LOW,M4_XX_HIGH-1,---+)---/   \\\\m4_forloop(m4_x,M4_XX_LOW,M4_XX_HIGH-1,---+)---/");
               end
            end
      @2
         // Pass the test on cycle 20.
         *failed = (/top|tb_gen<>0$CycCnt > 16'd200);
         *passed = (/top|tb_gen<>0$CycCnt > 16'd20) && ($FlitsInFlight == '0);
\SV
endmodule
