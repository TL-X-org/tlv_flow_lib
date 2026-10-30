\m4_TLV_version 1d: tl-x.org
\SV
   // ==============================================================
   // m4+lottery_arb: An N-input lottery-scheduling arbiter flow
   // component in the style of (and using) the tlv_flow_lib.
   //
   // N "avail/blocked" input flows compete for one output flow.
   // Inputs are given as a list argument: ['|pipe, @stage, ...'],
   // so they may come from anywhere (no replicated scope assumed).
   // Each input provides $tickets at its input stage. Each cycle,
   // a random draw in [0, total_tickets) grants an available input
   // with probability proportional to its ticket count. The
   // winner's transaction ($ANY) is muxed to the output.
   // Combinational; no storage (like arb2). Tickets must be
   // non-zero for liveness.
   // ==============================================================

   m4_include_url(['https:/']['/raw.githubusercontent.com/stevehoover/tlv_flow_lib/master/pipeflow_lib.tlv'])

   m4_makerchip_module

// Recursive helper: emits per-input logic for the head of the _ins list
// (input index #_i), then recurses on the tail. At the last input, also
// emits $lottery_total and completes the m4_lott_mux_acc expression.
// Not intended for direct use; see m4+lottery_arb.
\TLV lottery_arb_ins(/_top, |_out, @_out, /_trans, #_i, #_tw, _ins)
   m4_ifelse(['_ins'], [''], [''], ['
   // Input #_i is blocked unless it wins the lottery and the output is unblocked.
   m4_argn(1, _ins)
      m4_argn(2, _ins)
         $blocked = /_top|_out>>m4_align(@_out, m4_argn(2, _ins))$blocked ||
                    ! /_top|_out>>m4_align(@_out, m4_argn(2, _ins))$lottery_grant['']#_i;
   // Input #_i owns draw range [$lottery_cum(#_i - 1), $lottery_cum['']#_i),
   // which is empty unless it is available (so grants are one-hot by construction).
   |_out
      @_out
         $lottery_cum['']#_i[15:0] = m4_ifelse(#_i, 0, ['16'b0'], ['$lottery_cum['']m4_eval(#_i - 1)']) +
                                     (/_top['']m4_argn(1, _ins)>>m4_align(m4_argn(2, _ins), @_out)$avail
                                         ? {m4_eval(16 - #_tw)'b0, /_top['']m4_argn(1, _ins)>>m4_align(m4_argn(2, _ins), @_out)$tickets}
                                         : 16'b0);
         $lottery_grant['']#_i = m4_ifelse(#_i, 0, [''], ['($lottery_draw >= $lottery_cum['']m4_eval(#_i - 1)) && '])($lottery_draw < $lottery_cum['']#_i);
   m4_ifelse(m4_quote(m4_shift(m4_shift(_ins))), [''], ['m4_define(['m4_lott_mux_acc'], m4_quote(m4_lott_mux_acc)['/_top['']m4_argn(1, _ins)/_trans>>m4_align(m4_argn(2, _ins), @_out)$ANY'])
   |_out
      @_out
         $lottery_total[15:0] = $lottery_cum['']#_i;'], ['m4_define(['m4_lott_mux_acc'], m4_quote(m4_lott_mux_acc)['/_top|_out$lottery_grant['']#_i ? /_top['']m4_argn(1, _ins)/_trans>>m4_align(m4_argn(2, _ins), @_out)$ANY : '])'])
   m4+lottery_arb_ins(/_top, |_out, @_out, /_trans, m4_eval(#_i + 1), #_tw, m4_quote(m4_shift(m4_shift(_ins))))
   '])

// The N-input lottery arbiter flow component.
// Args:
//   /_top: Top scope.
//   _ins: List of input flows: ['|pipe, @stage, ...'] (any number of pairs).
//         Each provides $avail, $tickets, and /_trans$ANY.
//   |_out, @_out: The output flow.
//   /_trans: Transaction scope (or empty).
//   $_reset1: (opt) Alternate reset reference, relative to the first input.
//   #_ticket_w: (opt) Width of input $tickets signals (< 16). Default 8.
\TLV lottery_arb(/_top, _ins, |_out, @_out, /_trans, $_reset1, #_ticket_w)
   m4+flow_interface(/_top, ['_ins'], [' |_out, @_out'], $_reset1)
   m4_pushdef(['m4_trans_ind'], m4_ifelse(/_trans, [''], [''], ['   ']))
   m4_pushdef(['m4_tw'], m4_ifelse(#_ticket_w, [''], ['8'], ['#_ticket_w']))
   m4_pushdef(['m4_lott_mux_acc'], [''])
   m4+lottery_arb_ins(/_top, |_out, @_out, /_trans, 0, m4_tw, ['_ins'])
   |_out
      @_out
         $reset = /_top['']m4_argn(1, _ins)>>m4_align(m4_argn(2, _ins), @_out)$reset_in;

         // Free-running 16-bit Fibonacci LFSR (taps 16,15,13,4) provides the randomness.
         $LotteryLfsr[15:0] <= $reset ? 16'hACE1 :
                                        {$LotteryLfsr[14:0], $LotteryLfsr[15] ^ $LotteryLfsr[14] ^ $LotteryLfsr[12] ^ $LotteryLfsr[3]};

         // The draw: a random number in [0, $lottery_total).
         $lottery_draw[15:0] = ($lottery_total == 16'b0) ? 16'b0 : $LotteryLfsr % $lottery_total;

         // Output is available if any input is available (non-zero tickets assumed).
         $avail = $lottery_total != 16'b0;
         ?$avail
            /_trans
         m4_trans_ind   $ANY = m4_lott_mux_acc;
   m4_popdef(['m4_lott_mux_acc'])
   m4_popdef(['m4_tw'])
   m4_popdef(['m4_trans_ind'])

\TLV
   $reset = *reset;

   // =====================================================
   // Instance 1: 4 inputs, weights 1, 2, 4, 8. Full scoreboard.
   // =====================================================
   /lottery_test
      |in0
         @1
            $reset = /top<>0$reset;
            $tickets[7:0] = 8'd1;
            // Offer a transaction randomly when idle; hold $avail and
            // transaction content steady until accepted (flow protocol).
            m4_rand($rand_avail, 0, 0)
            m4_rand($rand_color, 23, 0)
            $Avail <= $reset                  ? 1'b0 :
                      ($Avail && ! $accepted) ? 1'b1 :        // hold while blocked
                                                $rand_avail;  // idle/accepted: new offer?
            $avail = $Avail;
            $Color[23:0] <= ($Avail && ! $accepted) ? $RETAIN : $rand_color;
            $Cnt[7:0] <= $reset    ? 8'b0 :
                         $accepted ? $Cnt + 8'b1 :
                                     $RETAIN;
            ?$avail
               /trans
                  $uid[7:0] = |in0$Cnt;
                  $src[1:0] = 2'd0;
                  $color[23:0] = |in0$Color;
      |in1
         @1
            $reset = /top<>0$reset;
            $tickets[7:0] = 8'd2;
            // Offer a transaction randomly when idle; hold $avail and
            // transaction content steady until accepted (flow protocol).
            m4_rand($rand_avail, 0, 0)
            m4_rand($rand_color, 23, 0)
            $Avail <= $reset                  ? 1'b0 :
                      ($Avail && ! $accepted) ? 1'b1 :        // hold while blocked
                                                $rand_avail;  // idle/accepted: new offer?
            $avail = $Avail;
            $Color[23:0] <= ($Avail && ! $accepted) ? $RETAIN : $rand_color;
            $Cnt[7:0] <= $reset    ? 8'b0 :
                         $accepted ? $Cnt + 8'b1 :
                                     $RETAIN;
            ?$avail
               /trans
                  $uid[7:0] = |in1$Cnt;
                  $src[1:0] = 2'd1;
                  $color[23:0] = |in1$Color;
      |in2
         @1
            $reset = /top<>0$reset;
            $tickets[7:0] = 8'd4;
            // Offer a transaction randomly when idle; hold $avail and
            // transaction content steady until accepted (flow protocol).
            m4_rand($rand_avail, 0, 0)
            m4_rand($rand_color, 23, 0)
            $Avail <= $reset                  ? 1'b0 :
                      ($Avail && ! $accepted) ? 1'b1 :        // hold while blocked
                                                $rand_avail;  // idle/accepted: new offer?
            $avail = $Avail;
            $Color[23:0] <= ($Avail && ! $accepted) ? $RETAIN : $rand_color;
            $Cnt[7:0] <= $reset    ? 8'b0 :
                         $accepted ? $Cnt + 8'b1 :
                                     $RETAIN;
            ?$avail
               /trans
                  $uid[7:0] = |in2$Cnt;
                  $src[1:0] = 2'd2;
                  $color[23:0] = |in2$Color;
      |in3
         @1
            $reset = /top<>0$reset;
            $tickets[7:0] = 8'd8;
            // Offer a transaction randomly when idle; hold $avail and
            // transaction content steady until accepted (flow protocol).
            m4_rand($rand_avail, 0, 0)
            m4_rand($rand_color, 23, 0)
            $Avail <= $reset                  ? 1'b0 :
                      ($Avail && ! $accepted) ? 1'b1 :        // hold while blocked
                                                $rand_avail;  // idle/accepted: new offer?
            $avail = $Avail;
            $Color[23:0] <= ($Avail && ! $accepted) ? $RETAIN : $rand_color;
            $Cnt[7:0] <= $reset    ? 8'b0 :
                         $accepted ? $Cnt + 8'b1 :
                                     $RETAIN;
            ?$avail
               /trans
                  $uid[7:0] = |in3$Cnt;
                  $src[1:0] = 2'd3;
                  $color[23:0] = |in3$Color;

      m4+lottery_arb(/lottery_test, ['|in0, @1, |in1, @1, |in2, @1, |in3, @1'], |out, @1, /trans, [''], 8)

      |out
         @1
            $trans_valid = $avail && ! $blocked;
            `BOGUS_USE(/trans$color)
            // Block output with 3/8 probability.
            m4_rand($blocked_rand, 2, 0)
            $blocked = $blocked_rand < 3'd3;
            /src[3:0]
               $granted = |out$trans_valid && (|out/trans$src == #src);
               $GrantCnt[7:0] <= |out$reset ? 8'b0 :
                                 $granted   ? $GrantCnt + 8'b1 :
                                              $RETAIN;
               // Per-source transactions must arrive in order.
               $err = $granted && (|out/trans$uid != $GrantCnt);
            $Error <= $reset ? 1'b0 :
                               $Error || /src[0]$err || /src[1]$err || /src[2]$err || /src[3]$err;
            $ok = /src[0]$GrantCnt > 8'd0 && /src[1]$GrantCnt > 8'd0 &&
                  /src[2]$GrantCnt > 8'd0 && /src[3]$GrantCnt > 8'd0 &&
                  (/src[3]$GrantCnt > /src[0]$GrantCnt) &&
                  ! $Error;

   // =====================================================
   // Instance 2: 2 inputs, weights 1 and 3, from unrelated
   // pipelines (demonstrating list flexibility and macro
   // re-entrancy). Liveness/coverage checks only.
   // =====================================================
   /pair_test
      |alpha
         @1
            $reset = /top<>0$reset;
            $tickets[3:0] = 4'd1;
            m4_rand($rand_avail, 0, 0)
            m4_rand($rand_color, 23, 0)
            $Avail <= $reset                  ? 1'b0 :
                      ($Avail && ! $accepted) ? 1'b1 :        // hold while blocked
                                                $rand_avail;  // idle/accepted: new offer?
            $avail = $Avail;
            $Color[23:0] <= ($Avail && ! $accepted) ? $RETAIN : $rand_color;
            ?$avail
               /trans
                  $is_beta = 1'b0;
                  $color[23:0] = |alpha$Color;
      |beta
         @1
            $reset = /top<>0$reset;
            $tickets[3:0] = 4'd3;
            m4_rand($rand_avail, 0, 0)
            m4_rand($rand_color, 23, 0)
            $Avail <= $reset                  ? 1'b0 :
                      ($Avail && ! $accepted) ? 1'b1 :        // hold while blocked
                                                $rand_avail;  // idle/accepted: new offer?
            $avail = $Avail;
            $Color[23:0] <= ($Avail && ! $accepted) ? $RETAIN : $rand_color;
            ?$avail
               /trans
                  $is_beta = 1'b1;
                  $color[23:0] = |beta$Color;

      m4+lottery_arb(/pair_test, ['|alpha, @1, |beta, @1'], |merged, @1, /trans, [''], 4)

      |merged
         @1
            $trans_valid = $avail && ! $blocked;
            $blocked = 1'b0;
            `BOGUS_USE(/trans$color)
            $AlphaCnt[7:0] <= $reset                            ? 8'b0 :
                              $trans_valid && ! /trans$is_beta  ? $AlphaCnt + 8'b1 :
                                                                  $RETAIN;
            $BetaCnt[7:0] <= $reset                            ? 8'b0 :
                             $trans_valid && /trans$is_beta    ? $BetaCnt + 8'b1 :
                                                                 $RETAIN;
            // Both sources served; heavier (3 tickets) served more than lighter (1).
            $ok = $AlphaCnt > 8'd0 && $BetaCnt > $AlphaCnt;

   *passed = *cyc_cnt > 32'd400 &&
             /lottery_test|out>>1$ok &&
             /pair_test|merged>>1$ok;
   *failed = /lottery_test|out>>1$Error || *cyc_cnt > 32'd500;
\SV
   endmodule