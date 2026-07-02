\m4_TLV_version 1d: tl-x.org
\SV
   // ==============================================================
   // m4+lottery_arb4: A lottery-scheduling arbiter flow component
   // in the style of (and using) the tlv_flow_lib.
   //
   // Four "avail/blocked" input flows compete for one output flow.
   // Each input provides $tickets (unconditioned, qualified by
   // $avail) at its input stage. Each cycle, a random draw in
   // [0, total_tickets) grants an available input with probability
   // proportional to its ticket count. The winner's transaction
   // ($ANY) is muxed to the output. Combinational; no storage
   // (like arb2). Tickets must be non-zero for liveness.
   // ==============================================================

   m4_include_url(['https:/']['/raw.githubusercontent.com/stevehoover/tlv_flow_lib/master/pipeflow_lib.tlv'])

   m4_makerchip_module

// The lottery arbiter flow component.
// Args (standard flow-library conventions):
//   /_top: Top scope.
//   |_in0, @_in0 .. |_in3, @_in3: The four input flows (provide $avail, $tickets, /_trans$ANY).
//   |_out, @_out: The output flow.
//   /_trans: Transaction scope (or empty).
//   $_reset1: (opt) Alternate reset reference, relative to |_in0@_in0.
//   #_ticket_w: (opt) Width of input $tickets signals (< 16). Default 8.
\TLV lottery_arb4(/_top, |_in0, @_in0, |_in1, @_in1, |_in2, @_in2, |_in3, @_in3, |_out, @_out, /_trans, $_reset1, #_ticket_w)
   m4+flow_interface(/_top, [' |_in0, @_in0, |_in1, @_in1, |_in2, @_in2, |_in3, @_in3'], [' |_out, @_out'], $_reset1)
   m4_pushdef(['m4_trans_ind'], m4_ifelse(/_trans, [''], [''], ['   ']))
   m4_pushdef(['m4_tw'], m4_ifelse(#_ticket_w, [''], ['8'], ['#_ticket_w']))
   // An input is blocked unless it wins the lottery and the output is unblocked.
   |_in0
      @_in0
         $blocked = /_top|_out>>m4_align(@_out, @_in0)$blocked ||
                    ! /_top|_out>>m4_align(@_out, @_in0)$lottery_grant0;
   |_in1
      @_in1
         $blocked = /_top|_out>>m4_align(@_out, @_in1)$blocked ||
                    ! /_top|_out>>m4_align(@_out, @_in1)$lottery_grant1;
   |_in2
      @_in2
         $blocked = /_top|_out>>m4_align(@_out, @_in2)$blocked ||
                    ! /_top|_out>>m4_align(@_out, @_in2)$lottery_grant2;
   |_in3
      @_in3
         $blocked = /_top|_out>>m4_align(@_out, @_in3)$blocked ||
                    ! /_top|_out>>m4_align(@_out, @_in3)$lottery_grant3;
   |_out
      @_out
         $reset = /_top|_in0>>m4_align(@_in0, @_out)$reset_in;

         // Free-running 16-bit Fibonacci LFSR (taps 16,15,13,4) provides the randomness.
         $LotteryLfsr[15:0] <= $reset ? 16'hACE1 :
                                        {$LotteryLfsr[14:0], $LotteryLfsr[15] ^ $LotteryLfsr[14] ^ $LotteryLfsr[12] ^ $LotteryLfsr[3]};

         // Cumulative ticket counts over available requesters.
         $lottery_cum0[15:0] = /_top|_in0>>m4_align(@_in0, @_out)$avail ? {m4_eval(16 - m4_tw)'b0, /_top|_in0>>m4_align(@_in0, @_out)$tickets} : 16'b0;
         $lottery_cum1[15:0] = $lottery_cum0 + (/_top|_in1>>m4_align(@_in1, @_out)$avail ? {m4_eval(16 - m4_tw)'b0, /_top|_in1>>m4_align(@_in1, @_out)$tickets} : 16'b0);
         $lottery_cum2[15:0] = $lottery_cum1 + (/_top|_in2>>m4_align(@_in2, @_out)$avail ? {m4_eval(16 - m4_tw)'b0, /_top|_in2>>m4_align(@_in2, @_out)$tickets} : 16'b0);
         $lottery_total[15:0] = $lottery_cum2 + (/_top|_in3>>m4_align(@_in3, @_out)$avail ? {m4_eval(16 - m4_tw)'b0, /_top|_in3>>m4_align(@_in3, @_out)$tickets} : 16'b0);

         // The draw: a random number in [0, $lottery_total).
         $lottery_draw[15:0] = ($lottery_total == 16'b0) ? 16'b0 : $LotteryLfsr % $lottery_total;

         // Grant the requester whose ticket range contains the draw.
         $lottery_grant0 = /_top|_in0>>m4_align(@_in0, @_out)$avail && ($lottery_draw < $lottery_cum0);
         $lottery_grant1 = /_top|_in1>>m4_align(@_in1, @_out)$avail && ! $lottery_grant0 && ($lottery_draw < $lottery_cum1);
         $lottery_grant2 = /_top|_in2>>m4_align(@_in2, @_out)$avail && ! $lottery_grant0 && ! $lottery_grant1 && ($lottery_draw < $lottery_cum2);
         $lottery_grant3 = /_top|_in3>>m4_align(@_in3, @_out)$avail && ! ($lottery_grant0 || $lottery_grant1 || $lottery_grant2);

         // Output is available if any input is available.
         $avail = /_top|_in0>>m4_align(@_in0, @_out)$avail ||
                  /_top|_in1>>m4_align(@_in1, @_out)$avail ||
                  /_top|_in2>>m4_align(@_in2, @_out)$avail ||
                  /_top|_in3>>m4_align(@_in3, @_out)$avail;
         ?$avail
            /_trans
         m4_trans_ind   $ANY = /_top|_out$lottery_grant0 ? /_top|_in0/_trans>>m4_align(@_in0, @_out)$ANY :
                               /_top|_out$lottery_grant1 ? /_top|_in1/_trans>>m4_align(@_in1, @_out)$ANY :
                               /_top|_out$lottery_grant2 ? /_top|_in2/_trans>>m4_align(@_in2, @_out)$ANY :
                                                           /_top|_in3/_trans>>m4_align(@_in3, @_out)$ANY;
   m4_popdef(['m4_trans_ind'])
   m4_popdef(['m4_tw'])

\TLV
   $reset = *reset;

   /lottery_test
      // ------------------------------------------------
      // Stimulus: four requesters with weights 1, 2, 4, 8.
      // ------------------------------------------------
      |in0
         @1
            $reset = /top<>0$reset;
            m4_rand($avail, 0, 0)
            $tickets[7:0] = 8'd1;
            $trans_valid = $avail && ! $blocked;
            $Cnt[7:0] <= $reset       ? 8'b0 :
                         $trans_valid ? $Cnt + 8'b1 :
                                        $RETAIN;
            ?$trans_valid
               /trans
                  $uid[7:0] = |in0$Cnt;
                  $src[1:0] = 2'd0;
      |in1
         @1
            $reset = /top<>0$reset;
            m4_rand($avail, 0, 0)
            $tickets[7:0] = 8'd2;
            $trans_valid = $avail && ! $blocked;
            $Cnt[7:0] <= $reset       ? 8'b0 :
                         $trans_valid ? $Cnt + 8'b1 :
                                        $RETAIN;
            ?$trans_valid
               /trans
                  $uid[7:0] = |in1$Cnt;
                  $src[1:0] = 2'd1;
      |in2
         @1
            $reset = /top<>0$reset;
            m4_rand($avail, 0, 0)
            $tickets[7:0] = 8'd4;
            $trans_valid = $avail && ! $blocked;
            $Cnt[7:0] <= $reset       ? 8'b0 :
                         $trans_valid ? $Cnt + 8'b1 :
                                        $RETAIN;
            ?$trans_valid
               /trans
                  $uid[7:0] = |in2$Cnt;
                  $src[1:0] = 2'd2;
      |in3
         @1
            $reset = /top<>0$reset;
            m4_rand($avail, 0, 0)
            $tickets[7:0] = 8'd8;
            $trans_valid = $avail && ! $blocked;
            $Cnt[7:0] <= $reset       ? 8'b0 :
                         $trans_valid ? $Cnt + 8'b1 :
                                        $RETAIN;
            ?$trans_valid
               /trans
                  $uid[7:0] = |in3$Cnt;
                  $src[1:0] = 2'd3;

      // ------------------------------------------------
      // The DUT.
      // ------------------------------------------------
      m4+lottery_arb4(/lottery_test, |in0, @1, |in1, @1, |in2, @1, |in3, @1, |out, @1, /trans, [''], 8)

      // ------------------------------------------------
      // Scoreboard.
      // ------------------------------------------------
      |out
         @1
            $trans_valid = $avail && ! $blocked;
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

            // Pass: every source served; heaviest (8 tickets) served more
            // than lightest (1 ticket); no per-source ordering errors.
            *passed = *cyc_cnt > 32'd400 &&
                      /src[0]$GrantCnt > 8'd0 && /src[1]$GrantCnt > 8'd0 &&
                      /src[2]$GrantCnt > 8'd0 && /src[3]$GrantCnt > 8'd0 &&
                      (/src[3]$GrantCnt > /src[0]$GrantCnt) &&
                      ! $Error;
            *failed = $Error || *cyc_cnt > 32'd500;
\SV
   endmodule
