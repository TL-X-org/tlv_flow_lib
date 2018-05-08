\m4_TLV_version 1d: tl-x.org
\SV
   
   // Test the m4+flop_fifo_v2 macro.
   // Instantiate the macro, sent a transaction containing a transaction count, and an indication of whether the
   // transaction suffered backpressure (for coverage checking).
   // Test passes if enough transactions were sent and received in order, and if at least one suffered backpressure.


   m4_makerchip_module

   //m4_include(['pipeflow_lib.m4'])

//----------------------------------------------
// This will come from library.
\TLV flop_fifo_v2(/_top,|_in_pipe,@_in_at,|_out_pipe,@_out_at,#_depth,/_trans_hier,#_high_water)
   m4_pushdef(['m4_ptr_width'], \$clog2(#_depth))
   m4_pushdef(['m4_counter_width'], \$clog2((#_depth)+1))
   m4_pushdef(['m4_bypass_align'], m4_align(@_out_at, @_in_at))
   m4_pushdef(['m4_reverse_bypass_align'], m4_align(@_in_at,@_out_at))
   m4_pushdef(['m4_trans_ind'], m4_ifelse(#_trans_hier, [''], [''], ['   ']))
   //   @0
   \SV_plus
      localparam bit [m4_counter_width-1:0] full_mark_['']m4_plus_inst_id = #_depth - m4_ifelse(#_high_water, [''], 0, ['#_high_water']);
   // FIFO Instantiation
   // Hierarchy declarations
   |_in_pipe
      /entry[(#_depth)-1:0]
   |_out_pipe
      /entry[(#_depth)-1:0]
   |_in_pipe
      @_in_at
         $out_blocked = /_top|_out_pipe>>m4_bypass_align$blocked;
         $blocked = >>1$full && $out_blocked;
         `BOGUS_USE($blocked)   // Not required to be consumed elsewhere.
         $would_bypass = >>1$empty;
         $bypass = $would_bypass && ! $out_blocked;
         $push = $trans_valid && ! $bypass;
         $grow   =   $trans_valid &&   $out_blocked;
         $shrink = ! $trans_avail && ! $out_blocked && ! >>1$empty;
         $valid_count[m4_counter_width-1:0] = $reset ? '0
                                                     : >>1$valid_count + (
                                                          $grow   ? { {(m4_counter_width-1){1'b0}}, 1'b1} :
                                                          $shrink ? '1
                                                                  : '0
                                                       );
         // At least 2 valid entries.
         //$two_valid = | $ValidCount[m4_counter_width-1:1];
         // but logic depth minimized by taking advantage of prev count >= 4.
         $two_valid = | >>1$valid_count[m4_counter_width-1:2] || | $valid_count[2:1];
         // These are an optimization of the commented block below to operate on vectors, rather than bits.
         // TODO: Keep optimizing...
         {/entry[*]$$prev_entry_was_tail} = {/entry[*]>>1$reconstructed_is_tail\[m4_eval(#_depth-2):0], /entry[m4_eval(#_depth-1)]>>1$reconstructed_is_tail} /* circular << */;
         {/entry[*]$$push} = {#_depth{$push}} & /entry[*]$prev_entry_was_tail;
         /entry[*]
            // Replaced with optimized versions above:
            // $prev_entry_was_tail = /entry[(entry+(m4_depth)-1)%(m4_depth)]>>1$reconstructed_is_tail;
            // $push = |_in_pipe$push && $prev_entry_was_tail;
            $valid = (>>1$reconstructed_valid && ! /_top|_out_pipe/entry>>m4_bypass_align$pop) || $push;
            $is_tail = |_in_pipe$trans_valid ? $prev_entry_was_tail  // shift tail
                                               : >>1$reconstructed_is_tail;  // retain tail
            $state = |_in_pipe$reset ? 1'b0
                                       : $valid && ! (|_in_pipe$two_valid && $is_tail);
      @m4_stage_eval(@_in_at>>1)
         $empty = ! $two_valid && ! $valid_count[0];
         $full = ($valid_count == full_mark_['']m4_plus_inst_id);  // Could optimize for power-of-two depth.
      /entry[*]
         @m4_stage_eval(@_in_at>>1)
            $prev_entry_state = /entry[(entry+(#_depth)-1)%(#_depth)]$state;
            $next_entry_state = /entry[(entry+1)%(#_depth)]$state;
            $reconstructed_is_tail = (  /_top|_in_pipe$two_valid && (!$state && $prev_entry_state)) ||
                                     (! /_top|_in_pipe$two_valid && (!$next_entry_state && $state)) ||
                                     (|_in_pipe$empty && (entry == 0));  // need a tail when empty for push
            $is_head = $state && ! $prev_entry_state;
            $reconstructed_valid = $state || (/_top|_in_pipe$two_valid && $prev_entry_state);
      // Write data
   |_in_pipe
      @_in_at
         /entry[*]
               //?$push
               //   $aNY = |m4_in_pipe['']m4_trans_hier$ANY;
            /_trans_hier
 m4_trans_ind           $ANY = /entry$push ? /_top|_in_pipe['']/_trans_hier$ANY : >>1$ANY /* RETAIN */;
      // Read data
   |_out_pipe
      @_out_at
            //$pop  = ! /m4_top|m4_in_pipe>>m4_align(m4_in_at + 1, m4_out_at)$empty && ! $blocked;
         /entry[*]
            $is_head = /_top|_in_pipe/entry>>m4_align(@_in_at + 1, @_out_at)$is_head;
            $pop  = $is_head && ! |_out_pipe$blocked;
            /read_masked
               /_trans_hier
 m4_trans_ind              $ANY = /entry$is_head ? /_top|_in_pipe/entry['']/_trans_hier>>m4_align(@_in_at + 1, @_out_at)$ANY /* $aNY */ : '0;
            /accum
               /_trans_hier
 m4_trans_ind              $ANY = ((entry == 0) ? '0 : /entry[(entry+(#_depth)-1)%(#_depth)]/accum['']/_trans_hier$ANY) |
                             /entry/read_masked['']/_trans_hier$ANY;
         /head
            $trans_avail = |_out_pipe$trans_avail;
            ?$trans_avail
               /_trans_hier
 m4_trans_ind              $ANY = /_top|_out_pipe/entry[(#_depth)-1]/accum['']/_trans_hier$ANY;
   // Bypass
   |_out_pipe
      @_out_at
         // Available output.  Sometimes it's necessary to know what would be coming to determined
         // if it's blocked.  This can be used externally in that case.
         /fifo_head
            $trans_avail = |_out_pipe$trans_avail;
            ?$trans_avail
               /_trans_hier
 m4_trans_ind              $ANY = /_top|_in_pipe>>m4_reverse_bypass_align$would_bypass
 m4_trans_ind                           ? /_top|_in_pipe['']/_trans_hier>>m4_reverse_bypass_align$ANY
 m4_trans_ind                           : |_out_pipe/head['']/_trans_hier$ANY;
         $trans_avail = ! /_top|_in_pipe>>m4_reverse_bypass_align$would_bypass || /_top|_in_pipe>>m4_reverse_bypass_align$trans_avail;
         $trans_valid = $trans_avail && ! $blocked;
         ?$trans_valid
            /_trans_hier
 m4_trans_ind           $ANY = |_out_pipe/fifo_head['']/_trans_hier$ANY;

//----------------------------------------------



\TLV
   $reset = *reset;

   /flop_fifo_test
      |in
         @1
            $reset = /top<>0$reset;
            m4_rand($trans_avail, 0, 0)
            $trans_valid = $trans_avail && ! $blocked;
            $Cnt[7:0] <= $reset       ? '0 :
                         $trans_valid ? $Cnt + 8'b1 :
                                        $RETAIN;
            // Count the number of times backpressure is applied to an available transaction since the last.
            $BackpressureCnt[7:0] <= $reset || $trans_valid   ? '0 :
                                     $trans_avail && $blocked ? $BackpressureCnt + 8'b1 :
                                                                $RETAIN;
            ?$trans_valid
               /trans
                  $cnt[7:0] = |in$Cnt;
                  // Flag whether this transaction was backpressured.
                  $backpressured = |in$BackpressureCnt > 8'b0;
      m4+flop_fifo_v2(/flop_fifo_test, |in, @1, |out, @1, 6, /trans)
      |out
         @1
            $reset = /top<>0$reset;
            $Cnt[7:0] <= $reset ? '0 :
                         $trans_valid ? $Cnt + 8'b1 :
                                        $RETAIN;
            // Block output with 5/8 probability.
            m4_rand($blocked_rand, 2, 0)
            $blocked = $blocked_rand < 3'd5;
            ?$trans_valid
               /trans
                  `BOGUS_USE($cnt)
            $Error <= $reset       ? '0 :
                      $trans_valid ? $Error || (/trans$cnt != $Cnt) :
                      $RETAIN;
            // Sticky indication that there was a backpressured transaction.
            $BackpressureApplied <= $reset       ? 1'b0 :
                                    $trans_valid ? $BackpressureApplied || /trans$backpressured :
                                                   $RETAIN;

            // Assert these to end simulation (before Makerchip cycle limit).
            *passed = *cyc_cnt > 100 && $Cnt > 20 && !$Error && $BackpressureApplied;
            *failed = *cyc_cnt > 102;
\SV
   endmodule
