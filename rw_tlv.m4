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


// ==========================================
//
// --------------------
// TLV M4 Library Files:
// --------------------
//
// TLV files with a version Preprocesses TLV with M4 if they begin with:
//
// \m4_TLV_version
//
// Additionally, there is a pre_m4 and a post_m4 script that enable multiline macros to be
// defined as:
//
// \m4+foo(|_pipe, @_stage)
//    |_pipe
//       @_stage
//          $sig = $other_sig;
//
// and instantiated as:
//
// \TLV
//    m4+foo(|my_pipe, @1)
//
// pre_m4 processes these and feeds them to M4 as:
//
// \TLV ['//\m4+foo(|_pipe, @_stage):']m4_define_plus2(['foo'], ['['
//    $']['1
//       $']['2
//          $sig = $other_sig;']'], ['{|_pipe}'], ['{@_stage}'])
//
// And:
//
// \TLV
//    m4_foo(['   '], ['UNUSED1'], ['UNUSED2'], ['   // Instantiated from ']m4_FILE[', ']m4___line__[' as: m4+foo(|my_pipe, @1)'], |my_pipe, @1)
//
// And M4 turns them into:
//
// \TLV //\m4+foo(|_pipe, @_stage):
//    // {|_pipe}
//    //    {@_stage}
//    //       $sig = $other_sig;
//
// And:
//
// \TLV
//    \source /home/steve/mono/sandhost/sandpiper-compiler/../tmp/9rfKz/top.tlv 14   // Instantiated from /home/steve/mono/sandhost/sandpiper-compiler/../tmp/9rfKz/top.tlv, 21 as: m4+foo(|my_pipe, @1)
//       |my_pipe
//          @1
//             $sig = $other_sig;
//    \end_source
//
// The process is horribly convoluted and will be replaced my native SandPiper macro support in a happier time.
//


// Define m4_FILE as the source file if it was not defined via the command line.
m4_ifdef(['m4_FILE'], [''], ['m4_define(['m4_FILE'], ['m4___file__'])'])


// m4_TLV_version is the tag for TLV files that need m4 pre-processing.
// This is substituted for TLV_version by this macro.
m4_define(['m4_TLV_version'], ['TLV_version [\source m4_FILE]'])


// A number that is unique to every instance of an m4+ macro (incremented at the head of each instance).
// This is available for user for uniquification.
m4_define(['m4_plus_inst_id'], 0)
// Quoted TL-X indentation.
m4_define(['m4_plus_indentation'], [''])

// Provides new-line within an m4+ macro. It provides proper indentation, however,
// note that using this macro will throw off line tracking. Another macro could
m4_define(['m4_plus_new_line'], ['
m4_plus_indentation()'])

// Provide TLV backslash escapes for a string.
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



// A wrapper for m4_define for m4+macros.
// Example, as generated by pre_m4:
//   m4_define_plus2(['func'], ['['
//      Body($']['1, $']['2)
//   ']'], ['{param1}'], ['{param2)}'])
// Expands as:
//   m4_define(['m4_func'],['['\source ']m4_escaped_string(m4_FILE) m4___line__']m4_arg(2)['m4_define(['m4_plus_inst_id'], m4_eval(m4_plus_inst_id+1))m4_pushdef(['m4_plus_indentation'], m4_open_quote()m4_plus_indentation()m4_close_quote()']m4_dquote(m4_arg(1))[')['']m4_echo(m4_prefix_lines(m4_plus_indentation, m4_substitute_args(['
//      Body($']['1, $']['2)']['
//   \end_source'], m4_shift(m4_shift($']['@)))))['']m4_popdef(['m4_plus_indentation'])'])['']m4_prefix_lines(['   // '], m4_substitute_args(['
//      Body($']['1, $']['2)'], m4_shift(m4_shift(--, --, {param1}, {param2}))))
// And becomes:
//     // Body({param1}, {param2})
// The expansion defines m4_func. pre_m4 will use it like:
//   m4_func(['   '], ['  // Instantiated as ...'], arg1, arg2)
// Which is defined as:
//   ['\source ']m4_escaped_string(m4_FILE) m4___line__['   // Instantiated as ...']m4_define(['m4_plus_inst_id'], m4_eval(m4_plus_inst_id+1))m4_pushdef(['m4_plus_indentation'], m4_open_quote()m4_plus_indentation()m4_close_quote()']m4_dquote(m4_arg(1))[')['']m4_prefix_lines(['   '], m4_substitute_args(['
//      Body($']['1, $']['2)
//   \end_source'], m4_shift(m4_shift($@))))
// Which expands as:
//      \source file.tlv 100   // Instantiated as ...
//         Body(arg1, arg2)
//      \end_source
//
// (Implementation differs slightly from above to account for two legacy unused arguments to remain compatible w/ macros defined by legacy m4_define_plus macro.)
m4_define(['m4_define_plus2'],
          ['m4_define(['m4_$1'], ['['\source ']']m4_open_quote()m4_escaped_string(m4_FILE) m4___line__['']m4_close_quote()m4_arg(4)['m4_define(['m4_plus_inst_id'], m4_eval(m4_plus_inst_id+1))m4_pushdef(['m4_plus_indentation'], m4_dquote(m4_plus_indentation())']m4_dquote(m4_arg(1))[')['']m4_echo(m4_prefix_lines(m4_plus_indentation, m4_substitute_args($2['
\end_source'], m4_shift(m4_shift(m4_shift(m4_shift($']['@)))))))['']m4_popdef(['m4_plus_indentation'])'])['']m4_ifelse(m4_strip_macro_definitions, ['0'], ['m4_prefix_lines(['   // '], m4_substitute_args($2, m4_shift(m4_shift($@))))'], [''])'])
// Without legacy args:
//        ['m4_define(['m4_$1'], ['['\source ']']m4_open_quote()m4_escaped_string(m4_FILE) m4___line__['']m4_close_quote()m4_arg(2)['m4_define(['m4_plus_inst_id'], m4_eval(m4_plus_inst_id+1))m4_pushdef(['m4_plus_indentation'], m4_dquote()m4_plus_indentation()']m4_dquote(m4_arg(1))[')['']m4_echo(m4_prefix_lines(m4_plus_indentation, m4_substitute_args($2['
//\end_source'], m4_shift(m4_shift($']['@)))))))['']m4_popdef(['m4_plus_indentation'])'])['']m4_prefix_lines(['   // '], m4_substitute_args($2, m4_shift(m4_shift($@))))'])


// This can be used to invoke one of a number of possible m4+ macros based on the first parameter.
// Usage:
// m4_define(['m4_which'], ['two'])
// \m4+fn_one(|pipe)
//    // stuff1
// \m4+fn_two(|pipe)
//    // stuff2
// \TLV
//    m4+indirect(['fn_']m4_which, |my_pipe)
m4_define(['m4_indirect'], ['m4_$5(['$1'], ['$2'], ['$3'], ['$4'], m4_shift(m4_shift(m4_shift(m4_shift(m4_shift($@))))))'])

// ==========================================



// ============
// Block Macros
// ============
// These are for defining blocks of code.

// m4_ifelse_block(...)
// Same protocol as m4_ifelse(..), but this preserves line alignment by producing blank lines for every line of conditioned-off code.
// As a bug workaround with blank lines, an additional first arg temporarily provides an indentation string.
m4_define(['m4_ifelse_block_tmp'],
  ['m4_ifelse(
    ['$2'],
    ['$3'],
    ['$4['']m4_replace_lines(['$1'], m4_shift(m4_shift(m4_shift(m4_shift($@)))))'],
    ['m4_replace_lines(['$1'], ['$4'])m4_ifelse(
      m4_eval(['$# > 5']),
      ['1'],
      ['m4_ifelse_block_tmp(
        ['$1'],
        m4_shift(m4_shift(m4_shift(m4_shift($@)))))'],
      ['$5'])'])'])


// ========================================
// Macros for manipulating TL-X identifiers
// ========================================

// Strip the prefix from an identifier.
m4_define(['m4_strip_prefix'], ['m4_patsubst(['$1'], ['^\W*'], [''])'])

// m4_alignment(alignment)
// Provides an alignment identifier value, given a numeric alignment.
// For version 1d, these are equivalent (no '+' sign), so this macro is a no-op.
m4_define(['m4_alignment'], ['$1'])

// m4_stage_eval(expr)
// Evaluates expr with:
//   '@' stripped,
//   '<<' -> ' - '
//   '>>' -> ' + '
// Eg:
//   @m4_stage_eval(@(2-1))
//   @m4_stage_eval(@2<<1)
//   >>m4_stage_eval((@2 - @1)<<1)
m4_define(['m4_stage_eval'], ['m4_dnl
m4_eval(m4_patsubst(m4_dquote(m4_patsubst(m4_dquote(m4_patsubst(['['$1']'], ['@'], [''])), ['>>'], [' + '])), ['<<'], [' - ']))m4_dnl
'])

// m4_align(signal's_from_stage, signal's_into_stage)
// Provides an ahead alignment identifier value (which can be negative), to consume from from_stage into to_stage.
// Eg:
//   >>m4_align(@2, @1-1)  ==>  >>2
m4_define(['m4_align'], ['m4_stage_eval(($1) - ($2))'])



// Range declarations.
// TODO: Should have push/pop variants of these (to replace these).

// Determine the number of bits required to hold the given binary number.
// (aka, the max 1 position +1; aka floor(lg2(n))+1)
m4_define(['m4_width'], ['m4_ifelse(m4_eval($1), ['0'], ['0'], ['m4_eval(m4_width(m4_eval($1 >> 1)) + 1)'])'])

// DEPRECATED:
// m4_define_range(scope, SCOPE, 10, 1) defines
//   SCOPE_MAX = 9
//   SCOPE_MIN = 1
//   SCOPE_HIGH = 10
//   SCOPE_LOW = 1
//   SCOPE_CNT = 10
//   SCOPE_WIDTH = 4
//   SCOPE_RANGE = scope[9:0]
m4_define(['m4_define_range'], ['m4_define_vector(['$2'], ['$3'], ['$4'])['']m4_divert(['-1'])
   m4_define(['$2_WIDTH'], $5)
   m4_define(['$2_RANGE'], $1[m4_eval($3 - 1):$4])   // Phase out, in favor of m4_define_hier.
m4_divert['']'])

// Define TLV behavioral hierarchy range (which can be reused multiple places in the TL-X hierarchy) and
// define related range constants, including all vector constants for:
//   o the hierarchy's range
//   o the range of indexes into the hierarchy
//   o the range of counts of a number of indices
//
// For example, eight cores might have definitions like:
//   /core[7:0]
//   $core_index[2:0]  // 7..0
//   $num_active_cores[3:0]  // 8..0
// and this macro defines all the related constants for these definitions, so:
//   m4_define_hier(M4_CORE, 8)
//   \M4_CORE_HIER
//   $core_index[M4_CORE_INDEX_RANGE]
//   $num_active_cores[M4_CORE_CNT_RANGE]
//
// Another example:
// m4_define_hier(M4_SCOPE, 10, 2) defines
//   M4_SCOPE_HIER = scope[9:2]
//   For the range of SCOPE:
//     M4_SCOPE_MAX = 9
//     M4_SCOPE_MIN = 2
//     M4_SCOPE_HIGH = 10
//     M4_SCOPE_LOW = 2
//     M4_SCOPE_CNT = 8
//     M4_SCOPE_RANGE = 9:2
//   For the range of indexes into scope[9:2] (e.g. $scope_index[3:0])
//     M4_SCOPE_INDEX_MAX = 3
//     M4_SCOPE_INDEX_MIN = 0
//     M4_SCOPE_INDEX_HIGH = 4
//     M4_SCOPE_INDEX_LOW = 0
//     M4_SCOPE_INDEX_CNT = 4
//     M4_SCOPE_INDEX_RANGE = 3:0
//   For the range of counts of scopes (supporting counts from M4_SCOPE_CNT..0).
//     M4_SCOPE_CNT_MAX = 3
//     M4_SCOPE_CNT_MIN = 0
//     M4_SCOPE_CNT_HIGH = 4
//     M4_SCOPE_CNT_LOW = 0
//     M4_SCOPE_CNT_CNT = 4
//     M4_SCOPE_CNT_RANGE = 3:0
m4_define_no_out(['m4_define_hier'], ['
   m4_define_vector(['$1'], ['$2'], ['$3'])
   m4_define_vector(['$1_INDEX'], m4_width(['$1_MAX']))
   m4_define_vector(['$1_CNT'], m4_width(m4_eval($1_CNT + 1)))
   m4_define(['$1_HIER'], m4_regexp(m4_translit(['$1'], ['A-Z'], ['a-z']), ['^\(m4_\)?\(.*\)'], ['\2'])[['$1_MAX:$1_MIN']])
'])

// Define m4 constants for a bit field.
// m4_define_vector(M4_SCOPE, 10 , 2) defines
//   M4_SCOPE_MAX = 9
//   M4_SCOPE_MIN = 2
//   M4_SCOPE_HIGH = 10
//   M4_SCOPE_LOW = 2
//   M4_SCOPE_CNT = 8
//   M4_SCOPE_RANGE = 9:1
// The 3rd arg is optional, and defaults to 0.
m4_define_no_out(['m4_define_vector'], ['
   m4_define(['$1_MAX'], m4_eval($2 - 1))
   m4_define(['$1_MIN'], m4_ifelse($3, [''], 0, $3))
   m4_define(['$1_HIGH'], $2)
   m4_define(['$1_LOW'],   $1_MIN)
   m4_define(['$1_CNT'],   m4_eval($2 - $1_MIN))
   m4_define(['$1_RANGE'], $1_MAX:$1_MIN)
'])

// Define fields of a vector.
// This is similar to m4_define_vector_with_fields, except that the vector is assumed to already be defined.
// E.g. m4_define_fields(M4_INSTR, 32, OP, 26, R1, 21, R2, 16, IMM, 5, DEST, 0)
//   calls m4_define_vector for (M4_INSTR_OP, 32, 26), (M4_INSTR_R1, 26, 21), etc.
// Also captures parameters (shifted by 1), in $1_FIELDS. In the example above:
//   m4_define(['M4_INSTR_FIELDS'], ['['32'], ['OP'], ...']). 
// Subfields and alternate fields can be declared w/ subsequent calls.
m4_define_hide(['m4_define_fields_guts'], ['
   m4_ifelse(['$4'], [''], [''], ['  // Terminate if < 4 args
      // Define first field.
      m4_define_vector(['$1_$3'], ['$2'], ['$4'])
      // Recurse.
      m4_define_fields_guts(['$1'], m4_shift(m4_shift(m4_shift($@))))
   '])
'])
m4_define(['m4_define_fields'], ['['']m4_define(['$1_FIELDS'], m4_quote(m4_shift($@)))m4_define_fields_guts($@)'])

// Define a vector with fields.
// E.g. m4_define_vector_with_fields(M4_INSTR, 32, OP, 26, R1, 21, R2, 16, IMM, 5, DEST, 0)
//   calls m4_define_vector for: (M4_INSTR, 32, 0) and subfields: (M4_INSTR_OP, 32, 26), (M4_INSTR_R1, 26, 21), etc.
//   Subfields and alternate fields can be declared w/ subsequent calls.
m4_define(['m4_define_vector_with_fields'], ['m4_define_vector(['$1'], ['$2'], m4_argn($#, $@))['']m4_define_fields($@)'])

// Produce a TLV expression to assign field signals to the fields of a vector.
// E.g.
//   m4_define_fields(['M4_INSTR'], 32, OP, 26, R1, 21, R2, 16, IMM, 5, DEST, 0)
//   m4_into_fields(['M4_INSTR'], ['$instr_sig'])
//   Produces:
//   {$instr_sig_op[6:0], $instr_sig_r1[5:0], $instr_sig_r2[5:0], $instr_sig_imm[11:0], $instr_sig_dest[5:0]} = $instr_sig;
m4_define(['m4_into_fields_lhs'], ['m4_ifelse(['$5'], [''], [''], ['$2$1_['']m4_translit(['$4'], ['A-Z'], ['a-z'])[m4_eval($3 - $5 - 1):0]m4_into_fields_lhs(['$1'], [', '], m4_shift(m4_shift(m4_shift(m4_shift($@)))))'])'])
m4_define(['m4_into_fields'], ['{m4_into_fields_lhs(['$2'], [''], $1_FIELDS)['} = $2;']'])


// ====================
// Generic Logic Macros
// ====================


// Reduction macro.
// Performs an operation across all instances of a hierarchy and provides the result outside that hierarchy.
// m4+redux($sum[7:0], /hier, max, min, $addend, '0, +)
\TLV redux($_redux_sig,/_hier,#_MAX,#_MIN,$_sig,$_init_expr ,_op)
   \always_comb
      $_redux_sig = $_init_expr ;
      for (int i = #_MIN; i <= #_MAX; i++)
         $_redux_sig = $_redux_sig _op /_hier[i]$_sig;


// Similar to m4+redux, but each element is conditioned.
// Performs an operation across all instances of a hierarchy and provides the result outside that hierarchy.
// m4+redux_cond($selected_value[7:0], /hier, max, min, $value, '0, |, $select)
\TLV redux_cond($_redux_sig,/_hier,#_MAX,#_MIN,$_sig,$_init_expr ,_op,$_cond_expr)
   /_hier[*]
      $_sig['']_cond = $_cond_expr ? $_sig : $_init_expr ;
   \always_comb
      $_redux_sig = $_init_expr ;
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
\TLV select($_redux_sig,/_top,/_hier,/_subhier,$_sel_sig_subhier,$_sel_sig,$_sig,$_redux_sig_cond)

m4_pushdef(['m4_hier_index'], ['m4_substr(/_hier, 1)'])
m4_pushdef(['m4_assign_redux_sig_cond'], m4_ifelse(m4_substr(m4_redux_sig_cond, 0, 1), ['-'], ['true'], ['']))  // Has '-'.
m4_pushdef(['S_redux_sig_cond'],         m4_ifelse(m4_substr($_redux_sig_cond, 0, 1), ['-'], m4_substr($_redux_sig_cond, 1), $_redux_sig_cond))  // Remove '-'.
m4_pushdef(['S_redux_sig_cond'],         m4_ifelse($_redux_sig_cond,[''],$_sel_sig['']_cond,$_redux_sig_cond))  // Make up a signal name if not provided.

   // This is a suboptimal implementation for simulation.
   // It does AND/OR reduction.  It would be better in simulation to simply index the desired value,
   //   but this is not currently supported in SandPiper as it is not legal across generate loops.
   /_hier[*]
      /accum
         \always_comb
            if (m4_hier_index == \$low(/_top['']/_hier[*]$_sel_sig_subhier['']$_sel_sig))
               $m4_sig = /_top['']/_hier['']$_sel_sig_subhier['']$_sel_sig ? /_top['']/_hier['']/_subhier['']$_sig : '0;
            else
               $_sig = /_top['']/_hier['']$_sel_sig_subhier['']$_sel_sig ? /_top['']/_hier['']/_subhier['']$_sig : /_hier[m4_hier_index-1]/accum['']$_sig;
m4_ifelse($_redux_sig_cond,['-'],['m4_dnl
   $_redux_sig = /_hier[\$high(/_top['']/_hier[*]$_sel_sig_subhier['']$_sel_sig)]/accum['']$_sig;
'],['m4_dnl
   m4_ifelse(m4_assign_redux_sig_cond,[''],[''],$_redux_sig_cond = | /_top['']/_hier[*]$_sel_sig_subhier['']$_sel_sig;)
   m4_ifelse($_redux_sig_cond,[''],[''],? $_redux_sig_cond['
      '])$_redux_sig = /_hier[\$high(/_top['']/_hier[*]$_sel_sig_subhier['']$_sel_sig)]/accum['']$_sig;
'])m4_dnl
   /* Old way:
   \always_comb
      $m4_redux_sig = m4_init;
      for (int i = m4_MIN; i <= m4_MAX; i++)
         m4_redux_sig = m4_redux_sig | (m4_hier[i]m4_index_sig['']_match ? m4_hier[i]m4_sig : '0);
   */

 
m4_popdef(['m4_hier_index'])
m4_popdef(['m4_assign_redux_sig_cond'])
m4_popdef(['S_redux_sig_cond'])




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
   /* verilator lint_save */ /* verilator lint_off UNOPTFLAT */  bit [256:0] RW_rand_raw; bit [256+63:0] RW_rand_vect; pseudo_rand #(.WIDTH(257)) pseudo_rand ($1, $2, RW_rand_raw[256:0]); assign RW_rand_vect[256+63:0] = {RW_rand_raw[62:0], RW_rand_raw};  /* verilator lint_restore */'])

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





#################
# LEGACY MACROS #
#################

// --------------------------
// OBSOLETE
// Argument substitution is now performed by pre_m4 script.


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
//   m4_define(['m4_func'],['m4_source(m4_FILE, m4___line__)   /['']/ Instantiated from $']['2, $']['3 as: $']['4['']m4_divert(['-1'])
//      m4 defines
//      m4_define(['m4_plus_inst_id'], m4_eval(m4_plus_inst_id+1))
//   ['']m4_divert['']m4_echo(m4_prefix_lines(['$1'],['
//      Body.
//   \end_source']))['']m4_divert(['-1'])
//      m4 undefines
//   ['']m4_divert['']'])
// So:
//   m4_func(['   '], ['src.tlv'], 20, ['m4+func(...)'])
// Expands as:
//   m4_source(['file.tlv'], 100)   /['']/ Instantiated from src.tlv, 20 as: m4+func(...)['']m4_divert(['-1'])
//      m4 defines
//      m4_define(['m4_plus_inst_id'], m4_eval(m4_plus_inst_id+1))
//   ['']m4_divert['']m4_echo(m4_prefix_lines(['   '],['
//      Body.
//   \end_source']))['']m4_divert(['-1'])
//      m4 undefines
//   ['']m4_divert['']
// Which expands as:
//      \source file.tlv 100   // Instantiated from src.tlv, 20 as: m4+func(...)
//         Body.
//      \end_source
// (where Body. has parameters substituted (by m4_echo(...)))
//
m4_define(['m4_define_plus'],
   ['m4_define(['$1'], ['m4_source(['$3'], $4)   /['']/']m4_arg(4)['['']m4_divert(['-1'])$2   m4_define(['m4_plus_inst_id'], m4_eval(m4_plus_inst_id+1))
   ['']m4_divert['']m4_echo(m4_prefix_lines(']m4_arg(1)[',['$5\end_source']))['']m4_divert(['-1'])$6['']m4_divert['']'])'])


// --------------------------


m4_divert['']m4_dnl


