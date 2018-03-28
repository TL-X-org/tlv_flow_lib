m4_include(['top_module_tlv.m4'])m4_divert(['-1'])   // Include "top_module_tlv.m4" automatically for TLV m4 files.
/*
Copyright (c) 2014, Intel Corporation

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Intel Corporation nor the names of its contributors
      may be used to endorse or promote products derived from this software
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


// TLV M4 Library Files:
// -------------------
//
// Preprocesses TLV with M4 if they begin with:
//
// \m4_TLV_version
//
// Additionally, there is a pre_m4 and a post_m4 script that enable multiline macros to be
// instantiated as:
//
//    m4+foo(args)
//
// and be fed to M4 as:
//
//    m4_foo("   ",['source_file.tlv'],<line-number>,['m4+foo(args)'],args)
//
//
// Multiline macro definitions, follow this structure.
//
// m4_define_plus(['m4_example'], ['
//
// m4_pushdef(['m4_arg1'],    ['$5'])
// m4_pushdef(['m4_arg2'],    ['$6'])
//
// '], m4___file__, m4___line__, ['
//    line1
//    line2
// '],
//
// ['
// m4_popdef(['m4_arg1'])
// m4_popdef(['m4_arg2'])
// '])




// ===========================
// Macros supporting m4+macros
// ===========================


// Define m4_FILE as the source file if it was not defined via the command line.
m4_ifdef(['m4_FILE'], [''], ['m4_define(['m4_FILE'], ['m4___file__'])'])


// m4_TLV_version is the tag for TLV files that need m4 pre-processing.
// This is substituted for TLV_version by this macro.
m4_define(['m4_TLV_version'], ['TLV_version [\source m4_FILE]'])


// A number that is unique to every instance of an m4+ macro (incremented at the head of each instance).
m4_define(['m4_plus_inst_id'], 0)

m4_define(['m4_escaped_string'], ['m4_patsubst(['$1'], [' '], ['\\ '])'])

// A macro that expands to multiple lines of TLV content should begin with:
//    \source <file>.tlv <line number>
// This macro produces this text (without indentation and new-lines) and is instantiated by m4_define_plus.
// Eg:  m4_source(__file__, __line__)
m4_define(['m4_source'], ['\source m4_escaped_string($1) $2'])


// A macro to use in libraries to identify versions of macros that are no longer supported.
// By convention, if a macro's interface is modified, it gets a new version, as m4_macro_name_v2.
// Old versions can continue to be supported, or abandoned in a new library version using this
// macro as:
//   m4_unsupported(['m4_my_macro'], 2)  // my_macro & my_macro_v2 are no longer supported.
m4_define(['m4_unsupported'], ['
  m4_forloop(['m4_ver'], 1, m4_incr($2), ['
    m4_pushdef(['m4_ver_str'], m4_ifelse(m4_ver, 1, [''], ['_v']m4_ver))
    m4_define(['$1']m4_ver_str, ['!!! ['$1']m4_ver_str[' is not supported for TLV ']m4_tlv_version['.']'])
    m4_popdef(['ver'])
  '])
'])


// A really messy wrapper for m4_define for m4+macros.
// Example:
//   m4_define_plus(['m4_func'], ['
//      m4 defines
//   '], m4___file__, m4___line__, ['
//      Body.
//   '], ['
//      m4 undefines
//   '])
// Expands as:
//   m4_define(['m4_func'],['m4_source(['file.tlv'], 100)   /['']/ Instantiated from $']['2, $']['3 as: $']['4['']m4_divert(['-1'])
//      m4 defines
//      m4_define(['m4_plus_inst_id'], m4_eval(m4_plus_inst_id+1))
//   ['']m4_divert['']m4_prefix_lines(m4_open_quote()$']['1['']m4_close_quote(),
//      Body.
//   \['end_source'])m4_divert(['-1'])
//      m4 undefines
//   ['']m4_divert['']'])
// So:
//   m4_func(['   '], ['file.tlv'], 100, ['m4+func(...)'])
// Expands as:
//   m4_source(['file.tlv'], 100)   /['']/ Instantiated from src.tlv, 20 as: m4+func(...)['']m4_divert(['-1'])
//      m4 defines
//      m4_define(['m4_plus_inst_id'], m4_eval(m4_plus_inst_id+1))
//   ['']m4_divert['']m4_prefix_lines(['   '],
//      Body.
//   \['end_source'])m4_divert(['-1'])
//   
//      m4 undefines
//   ['']m4_divert['']
// Which expands as:
//      \source file.tlv 100   // Instantiated from src.tlv, 20 as: m4+func(...)
//         Body.
//      \end_source
// (where Body. has parameters substituted)
//
m4_define(['m4_define_plus'],['m4_define(['$1'],['m4_source(['$3'], $4)   /['']/ Instantiated from $']['2, $']['3 as: $']['4['']m4_divert(['-1'])$2   m4_define(['m4_plus_inst_id'], m4_eval(m4_plus_inst_id+1))
   ['']m4_divert['']m4_prefix_lines(m4_open_quote()$']['1['']m4_close_quote(),['$5\['end_source']'])m4_divert(['-1'])$6['']m4_divert['']'])'])



// ===================
// Useful w/i TLV Code
// ===================

// m4_alignment(alignment)
// Provides an alignment value with '+'/'-' (eg: '+6'), given an alignment value.
m4_define(['m4_alignment'], ['m4_dnl
m4_ifelse(m4_eval($1 < 0), 1, $1, +$1)m4_dnl
'])

// m4_align(from_stage, to_stage)
// Provides an alignment value with '+'/'-' (eg: '+6'), to consume from from_stage into to_stage.
m4_define(['m4_align'], ['m4_dnl
m4_alignment(m4_eval($1 - $2))m4_dnl
'])



// Define m4 constants for a range.  Instantiate from divert(['-1']) context.
// m4_define_range(scope, SCOPE, 10, 1, 4) defines
//   SCOPE_MAX = 9
//   SCOPE_MIN = 1
//   SCOPE_HIGH = 10
//   SCOPE_LOW = 1
//   SCOPE_CNT = 10
//   SCOPE_WIDTH = 4
//   SCOPE_RANGE = scope[9:0]
m4_define(['m4_define_range'], ['m4_divert(['-1'])
   m4_define(['$2']_MAX, m4_eval($3 - 1))
   m4_define(['$2']_MIN, $4)
   m4_define(['$2']_HIGH, $3)
   m4_define(['$2']_LOW, $4)
   m4_define(['$2']_CNT, m4_eval($3 - $4))
   m4_define(['$2']_WIDTH, $5)
   m4_define(['$2']_RANGE, $1[m4_eval($3 - 1):$4])
m4_divert'])




// ====================
// Generic Logic Macros
// ====================


// Reduction macro.
// Performs an operation across all instances of a hierarchy and provides the result outside that hierarchy.
// m4+redux($sum[7:0], >hier, max, min, $addend, '0, +)
m4_define_plus(['m4_redux'], ['

m4_pushdef(['m4_redux_sig'],    ['$5'])
m4_pushdef(['m4_hier'],         ['$6'])
m4_pushdef(['m4_MAX'],          ['$7'])
m4_pushdef(['m4_MIN'],          ['$8'])
m4_pushdef(['m4_sig'],          ['$9'])
m4_pushdef(['m4_init'],         ['$10'])
m4_pushdef(['m4_op'],           ['$11'])

'], m4___file__, m4___line__, ['
   \always_comb
      $m4_redux_sig = m4_init;
      for (int i = m4_MIN; i <= m4_MAX; i++)
         m4_redux_sig = m4_redux_sig m4_op m4_hier[i]m4_sig;
'],

['
m4_popdef(['m4_redux_sig'])
m4_popdef(['m4_hier'])
m4_popdef(['m4_MAX'])
m4_popdef(['m4_MIN'])
m4_popdef(['m4_sig'])
m4_popdef(['m4_init'])
m4_popdef(['m4_op'])
'])


// Similar to m4+redux, but each element is conditioned.
// Performs an operation across all instances of a hierarchy and provides the result outside that hierarchy.
// m4+redux_cond($selected_value[7:0], >hier, max, min, $value, '0, |, $select)
m4_define_plus(['m4_redux_cond'], ['

m4_pushdef(['m4_redux_sig'],    ['$5'])
m4_pushdef(['m4_hier'],         ['$6'])
m4_pushdef(['m4_MAX'],          ['$7'])
m4_pushdef(['m4_MIN'],          ['$8'])
m4_pushdef(['m4_sig'],          ['$9'])
m4_pushdef(['m4_init'],         ['$10'])
m4_pushdef(['m4_op'],           ['$11'])
m4_pushdef(['m4_cond_expr'],    ['$12'])

'], m4___file__, m4___line__, ['
   m4_hier[*]
      m4_sig['']_cond = m4_cond_expr ? m4_sig : m4_init;
   \always_comb
      $m4_redux_sig = m4_init;
      for (int i = m4_MIN; i <= m4_MAX; i++)
         m4_redux_sig = m4_redux_sig m4_op m4_hier[i]m4_sig;
'],

['
m4_popdef(['m4_redux_sig'])
m4_popdef(['m4_hier'])
m4_popdef(['m4_MAX'])
m4_popdef(['m4_MIN'])
m4_popdef(['m4_sig'])
m4_popdef(['m4_init'])
m4_popdef(['m4_op'])
m4_popdef(['m4_cond_expr'])
'])


// Select across a hierarchy (MUX) within a pipeline with a decoded select.  Works for $pipe_signals and $ANY.
// m4+select($selected_value[7:0], >top, >hier, ...fix)
m4_define_plus(['m4_select'], ['

m4_pushdef(['m4_redux_sig'],    ['$5'])   // The resulting signal, including bit range.
m4_pushdef(['m4_top'],          ['$6'])   // Base scope for references.
m4_pushdef(['m4_hier'],         ['$7'])   // use m4_top['']m4_hier[*]m4_subhier
m4_pushdef(['m4_subhier'],      ['$8'])   // Replicated logic is created under m4_hier[*].
//m4_pushdef(['m4_MAX'],          ['$8'])
//m4_pushdef(['m4_MIN'],          ['$9'])
m4_pushdef(['m4_sel_sig_subhier'],['$9'])   // m4_top['']m4_hier[*]m4_sel_sig_subhier['']m4_sel_sig selects an input.
m4_pushdef(['m4_sel_sig'],      ['$10'])
m4_pushdef(['m4_sig'],          ['$11'])  // The signal to select, including bit range.
m4_pushdef(['m4_redux_sig_cond'], ['$12'])  // When condition for redux sig.  [''] for none (produces '0 if no select);  ['-'] or ['-$signame'] to generate as "| m4_top['']m4_hier[*]m4_sel_sig_subhier['']m4_sel_sig"; ['$signame'] to use given signal.

m4_pushdef(['m4_hier_index'], ['m4_substr(m4_hier, 1)'])
m4_pushdef(['m4_assign_redux_sig_cond'], m4_ifelse(m4_substr(m4_redux_sig_cond, 0, 1), ['-'], ['true'], ['']))  // Has '-'.
m4_define(['m4_redux_sig_cond'],         m4_ifelse(m4_substr(m4_redux_sig_cond, 0, 1), ['-'], m4_substr(m4_redux_sig_cond, 1), m4_redux_sig_cond))  // Remove '-'.
m4_define(['m4_redux_sig_cond'],         m4_ifelse(m4_redux_sig_cond,[''],m4_sel_sig['']_cond,m4_redux_sig_cond))  // Make up a signal name if not provided.

'], m4___file__, m4___line__, ['
   
   // This is a suboptimal implementation for simulation.
   // It does AND/OR reduction.  It would be better in simulation to simply index the desired value,
   //   but this is not currently supported in SandPiper as it is not legal across generate loops.
   m4_hier[*]
      >accum
         \always_comb
            if (m4_hier_index == \$low(m4_top['']m4_hier[*]m4_sel_sig_subhier['']m4_sel_sig))
               $m4_sig = m4_top['']m4_hier['']m4_sel_sig_subhier['']m4_sel_sig ? m4_top['']m4_hier['']m4_subhier['']m4_sig : '0;
            else
               m4_sig = m4_top['']m4_hier['']m4_sel_sig_subhier['']m4_sel_sig ? m4_top['']m4_hier['']m4_subhier['']m4_sig : m4_hier[m4_hier_index-1]>accum['']m4_sig;
m4_ifelse(m4_redux_sig_cond,['-'],['m4_dnl
   m4_redux_sig = m4_hier[\$high(m4_top['']m4_hier[*]m4_sel_sig_subhier['']m4_sel_sig)]>accum['']m4_sig;
'],['m4_dnl
   m4_ifelse(m4_assign_redux_sig_cond,[''],[''],m4_redux_sig_cond = | m4_top['']m4_hier[*]m4_sel_sig_subhier['']m4_sel_sig;)
   m4_ifelse(m4_redux_sig_cond,[''],[''],?m4_redux_sig_cond['
      '])m4_redux_sig = m4_hier[\$high(m4_top['']m4_hier[*]m4_sel_sig_subhier['']m4_sel_sig)]>accum['']m4_sig;
'])m4_dnl
   /* Old way:
   \always_comb
      $m4_redux_sig = m4_init;
      for (int i = m4_MIN; i <= m4_MAX; i++)
         m4_redux_sig = m4_redux_sig | (m4_hier[i]m4_index_sig['']_match ? m4_hier[i]m4_sig : '0);
   */
'],

['
m4_popdef(['m4_redux_sig'])
m4_popdef(['m4_top'])
m4_popdef(['m4_hier'])
m4_popdef(['m4_subhier'])
//m4_popdef(['m4_MAX'])
//m4_popdef(['m4_MIN'])
m4_popdef(['m4_sel_sig_subhier'])
m4_popdef(['m4_sel_sig'])
m4_popdef(['m4_sig'])
m4_popdef(['m4_redux_sig_cond'])
m4_popdef(['m4_hier_index'])
m4_popdef(['m4_assign_redux_sig_cond'])
'])



// Select max.
// Eg:
//    >hier[*]
//       $avail = ...;
//       $sel = m4_am_max(>hier[*]$avail, hier);
// Asserts >hier[max]$sel, where 'max' is the max index with $avail asserted (or no $sel asserted if none $avail).
m4_define(['m4_am_max'], ['(($1 & ~((1 << $2) - 1)) == (1 << $2))'])




//========================
// Test Bench Macros


//
// Random Number Generator
//

// These require /proprietary/common_src/lfsr_crc.vs to be `included.

// Unique instance number for lfsr_crc module.
m4_define(['m4_rand_inst_num'], 0)

// Random stimulus example:
// \SV
//    m4_use_rand(clk, reset)
// \TLV
//    >xx[*]
//       >yy[*]
//          m4_rand($Rand, 7, 0, xx * yy ^ xx)

// Instantiate this in SV scope to enable use of m4_rand, below.
// m4_use_rand(clk, reset)
// Creates a 257-bit pseudo random bit vector using pseudo_rand() that is extended with wrapped bits to make it easier
// to pull off a range of bits (up to 64b) from an arbitrary starting point w/i the 257-bit vector.
m4_define(['m4_use_rand'], ['m4_dnl
   /* verilator lint_off UNOPTFLAT */  bit [256:0] RW_rand_raw; bit [256+63:0] RW_rand_vect; pseudo_rand #(.WIDTH(257)) pseudo_rand ($1, $2, RW_rand_raw[256:0]); assign RW_rand_vect[256+63:0] = {RW_rand_raw[62:0], RW_rand_raw};  /* verilator lint_on UNOPTFLAT */'])

// Random number generator
//    From the example above, this creates $Rand[7:0], assigned to field of the random vector, using *xx * *yy ^ *xx as a
//    hash for the indexing into the vector.  A unique hash is generated for each use of m4_rand, but the hash argument is
//    needed to uniquify the hash for each instance created by this m4_rand().
// Just putting something in place.  Probably needs improvement for better randomness.
m4_define(['m4_rand'], ['m4_dnl
m4_pushdef(['m4_rand_sig'], $1)m4_dnl
m4_pushdef(['m4_max'], $2)m4_dnl
m4_pushdef(['m4_min'], $3)m4_dnl
m4_pushdef(['m4_scope_hash'], m4_ifelse(['$4'], [''], 0, ['$4']))m4_dnl
m4_rand_sig[m4_max:m4_min] = *RW_rand_vect[(m4_eval((m4_rand_inst_num * 124) % 257) + (m4_scope_hash)) % 257 +: m4_eval(m4_max - m4_min + 1)];m4_dnl
m4_define(['m4_rand_inst_num'], m4_eval(m4_rand_inst_num + 1))m4_dnl
m4_popdef(['m4_rand_sig'])m4_dnl
m4_popdef(['m4_max'])m4_dnl
m4_popdef(['m4_min'])m4_dnl
m4_popdef(['m4_scope_hash'])m4_dnl
'])


m4_divert['']m4_dnl
