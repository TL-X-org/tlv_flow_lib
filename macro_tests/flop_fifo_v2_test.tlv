\m4_TLV_version 1d: tl-x.org
\SV
   
   // Makerchip TLV code to test the latest m4+flop_fifo_v2 macro in master.
   
   // Instantiates the macro, sends a transaction containing a transaction count and an indication of whether the
   // transaction suffered backpressure (for coverage checking).
   // Test passes if enough transactions were sent and received in order, and if at least one suffered backpressure.

   m4_include_url(['https:/']['/raw.githubusercontent.com/stevehoover/tlv_flow_lib/master/pipeflow_lib.tlv'])

   m4_makerchip_module


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
