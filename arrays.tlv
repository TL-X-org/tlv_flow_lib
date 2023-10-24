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

// A 1r1w array that reads and writes into (possibly) independent pipelines that
// follow the flow library convention (at least, they have $accepted signals).
// The array size should be defined outside of pipeline scope by, eg:
// m4_define_hier(M4_ENTRIES, 1024)
// Can write transaction (/_trans$ANY) or signal. If writing a signal, include signal range in $_wr_data and $_rd_data.
// Write from |_wr@_wr and read data written last cycle into |_rd@_rd.
// For naturally-aligned rd/wr pipelines (rd transaction reflects data of stage-aligned wr transaction), @_rd would be @_wr + 1.
// Functionality is preserved if @_rd and @_wr are changed by the same amount.
// If $_rd_data is [''] it has the same name as $_wr_data.
// Write enable is: /_trans$_wr && $accepted.
// Read enable is: /_trans$_rd && $accepted.
\TLV array1r1w(/_top, /_entries, |_wr, @_wr, $_wr, $_wr_addr, $_wr_data, |_rd, @_rd, $_rd, $_rd_addr, $_rd_data, /_trans)
   m4_define(['m4_rd_data_sig'], m4_ifelse($_rd_data, , $_wr_data, $_rd_data))
   // Write Pipeline
   // The array entries hierarchy (needs a definition to define range, and currently, /_trans declaration required before reference).
   /m5_get(m4_to_upper(m4_strip_prefix(/_entries))_HIER)
      /_trans
         
   // Write transaction to cache
   // (TLV assignment syntax prohibits assignment outside of it's own scope, but \SV_plus does not.)
   \SV_plus
      always @ (posedge clk) begin
         if (|_wr/_trans>>m4_stage_eval(@_wr - 0)$_wr && |_wr>>m4_stage_eval(@_wr - 0)$accepted)
            /_entries[|_wr/_trans>>m4_stage_eval(@_wr - 0)$_wr_addr]/_trans>>1$['']$_wr_data <= |_wr/_trans>>m4_stage_eval(@_wr - 0)$_wr_data;
      end
   
   // Read Pipeline
   |_rd
      @_rd
         // Read transaction from cache.
         $m4_strip_prefix(/_entries)_rd_en = /_trans$_rd && $accepted;
         ?$m4_strip_prefix(/_entries)_rd_en
            /_trans
            m4_ifelse(/_trans, [''], [''], ['   '])['']m4_rd_data_sig = /_top/_entries[$_rd_addr]/_trans>>m4_stage_eval(1 - @_rd)$_wr_data;
