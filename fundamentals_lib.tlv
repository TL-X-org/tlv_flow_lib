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

// ====================
// Generic Logic Macros
// ====================

// Expand to a concatination.
// Big endian concatinates {[0], [1], ...}
// Little endian concatinates {..., [1], [0]}
// Generally, little endian is unnecessary, as [*] references do the same thing, but we've come across tools that
// can't handle the multiple packed dimensions [*] creates.
// Params:
//   $1: Scope.
//   $2: The number of indices in the scope [n-1:0].
//   $3: Signal to concatinate inside scope.
m4_define(['m4_hier_concat_big_endian'],
          ['{m4_forloop(['m4_ind'], 0, $2, ['m4_ifelse(m4_ind, 0, [''], [', '])$1[m4_ind]$2'])}'])
m4_define(['m4_hier_concat_little_endian'],
          ['{m4_forloop(['m4_ind'], 0, $2, ['m4_ifelse(m4_ind, 0, [''], [', '])$1[m4_eval($2 - m4_ind - 1)]$2'])}'])

// Reduction macro.
// Performs an operation across all instances of a hierarchy and provides the result outside that hierarchy.
// m4+redux($sum[7:0], /hier, max, min, $addend, '0, +)
\TLV redux($_redux_sig,/_hier,#_MAX,#_MIN,$_sig,$_init_expr ,_op)
   \always_comb
      $['']$_redux_sig = $_init_expr ;
      for (int i = #_MIN; i <= #_MAX; i++)
         $_redux_sig = $_redux_sig _op /_hier[i]$_sig;


// Similar to m4+redux, but each element is conditioned.
// Performs an operation across all instances of a hierarchy and provides the result outside that hierarchy.
// m4+redux_cond($selected_value[7:0], /hier, max, min, $value, '0, |, $select)
\TLV redux_cond($_redux_sig,/_hier,#_MAX,#_MIN,$_sig,$_init_expr ,_op,$_cond_expr)
   /_hier[*]
      $_sig['']_cond = $_cond_expr ? $_sig : $_init_expr ;
   \always_comb
      $['']$_redux_sig = $_init_expr ;
      for (int i = #_MIN; i <= #_MAX; i++)
         $_redux_sig = $_redux_sig _op /_hier[i]$_sig;


// Select across a hierarchy (MUX) within a pipeline with a decoded select.  Works for $pipe_signals and $ANY.
// m4+select($selected_value[7:0], /top, /hier, ...fix)
//$_redux_sig The resulting signal, including bit range.
//  /_top Base scope for references.
// /_hier  use /_top['']/_hier[*]/_subhier
// /_subhier Replicated logic is created under m4_hier[*].
//m4_pushdef(['m4_MAX'],          ['$8'])
//m4_pushdef(['m4_MIN'],          ['$9'])
// /_sel_sig_subhier /_top['']/_hier[*]$_sel_sig_subhier['']$_sel_sig selects an input.
// $_redux_sig_cond    When condition for redux sig.  [''] for none (produces '0 if no select);  ['-'] or ['-$signame'] to generate as "| /_top['']/_hier[*]/_sel_sig_subhier['']/_sel_sig"; ['$signame'] to use given signal.
\TLV select($_redux_sig, /_top, /_hier, /_subhier, /_sel_sig_subhier, $_sel_sig, $_sig, $_redux_sig_cond)
   
   m4_pushdef(['m4_hier_index'], ['m4_substr(/_hier, 1)'])
   m4_pushdef(['m4_assign_redux_sig_cond'], m4_ifelse(m4_substr(m4_redux_sig_cond, 0, 1), ['-'], ['true'], ['']))  // Has '-'.
   m4_pushdef(['S_redux_sig_cond'],         m4_ifelse(m4_substr($_redux_sig_cond, 0, 1), ['-'], m4_substr($_redux_sig_cond, 1), $_redux_sig_cond))  // Remove '-'.
   m4_define(['S_redux_sig_cond'],         m4_ifelse(S_redux_sig_cond, [''], $_sel_sig['']_cond, S_redux_sig_cond))  // Make up a signal name if not provided.
   
   // This is a suboptimal implementation for simulation.
   // It does AND/OR reduction.  It would be better in simulation to simply index the desired value,
   //   but this is not currently supported in SandPiper as it is not legal across generate loops.
   /_hier[*]
      /accum
         \always_comb
            if (m4_hier_index == \$low(/_top['']/_hier[*]/_sel_sig_subhier['']$_sel_sig))
               $['']$_sig = /_top['']/_hier/_sel_sig_subhier['']$_sel_sig ? /_top['']/_hier['']/_subhier['']$_sig : '0;
            else
               $_sig = /_top['']/_hier['']/_sel_sig_subhier['']$_sel_sig ? /_top['']/_hier['']/_subhier$_sig : /_hier[m4_hier_index-1]/accum$_sig;
   m4_ifelse($_redux_sig_cond,['-'],['
   $_redux_sig = /_hier[\$high(/_top['']/_hier[*]/_sel_sig_subhier['']$_sel_sig)]/accum$_sig;
   '], ['
   m4_ifelse(m4_assign_redux_sig_cond, [''], [''], S_redux_sig_cond = | m/_top/_hier[*]/_sel_sig_subhier['']$_sel_sig;)
   m4_ifelse(S_redux_sig_cond, [''], [''], ?S_redux_sig_cond)
   m4_ifelse(S_redux_sig_cond, [''], [''], ['   '])$_redux_sig = /_hier[\$high(/_top['']/_hier[*]/_sel_sig_subhier['']$_sel_sig)]/accum$_sig;'])
   /* Old way:
   \always_comb
      $m4_redux_sig = m4_init;
      for (int i = m4_MIN; i <= m4_MAX; i++)
         m4_redux_sig = m4_redux_sig | (m4_hier[i]m4_index_sig['']_match ? m4_hier[i]m4_sig : '0);
   */

   m4_popdef(['S_redux_sig_cond'])
   m4_popdef(['m4_hier_index'])
   m4_popdef(['m4_assign_redux_sig_cond'])

