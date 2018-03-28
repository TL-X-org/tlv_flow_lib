m4_divert(['-1'])
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


// Included by all \m4_TLV_version files.
// Contains generic M4 macro definitions using TLV M4 naming conventions.


// --------------------------------------
// From /usr/share/doc/m4/examples/, with m4_ prefixes and the right quote style.
// (Should find a way to include these.)

// Generic loop macros.

// m4_forloop(var, from, to, stmt) - simple version
m4_define(['m4_forloop'], ['m4_pushdef(['$1'], ['m4_eval($2)'])m4__forloop($@)m4_popdef(['$1'])'])
m4_define(['m4__forloop'],
          ['m4_ifelse(m4_eval($1 < $3), 1, ['$4['']m4_define(['$1'], m4_incr($1))$0($@)'], [''])'])

m4_define(['m4_argn'], ['m4_ifelse(['$1'], 1, ['['$2']'],
  ['m4_argn(m4_decr(['$1']), m4_shift(m4_shift($@)))'])'])
// m4_quote(args) - convert args to single-quoted string
m4_define(['m4_quote'], ['m4_ifelse(['$#'], ['0'], [''], ['['$*']'])'])
// m4_dquote(args) - convert args to quoted list of quoted strings
m4_define(['m4_dquote'], ['['$@']'])
// dquote_elt(args) - convert args to list of double-quoted strings
m4_define(['m4_dquote_elt'], ['m4_ifelse(['$#'], ['0'], [''], ['$#'], ['1'], ['['['$1']']'],['['['$1']'],$0(m4_shift($@))'])'])
// --------------------------------------

m4_define(['m4_new_line'], ['
'])

// Multiple defines.
// Args are parenthesized arguments to m4_define.
m4_define(['m4_defines'], ['m4_define$1m4_defines(m4_shift($@))'])

// Define a macro with diverted contents.
// Keep track of the depth of m4_define_no_out macro instantiations by push/pop-def'ing this flag and divert only at the top level.
//m4_define(['m4_no_out_flag'], ['-'])
//m4_define(['m4_define_no_out'], ['m4_define(['$1'], ['m4_ifelse(m4_no_out_flag, [''], ['m4_divert(-1)'], [''])m4_pushdef(['m4_no_out_flag'], ['-'])['']$2['']m4_popdef(['m4_no_out_flag'])m4_ifelse(m4_no_out_flag, [''], ['m4_divert'], [''])'])'])

m4_define(['m4_visibility'], ['show'])
m4_define(['m4_hide'], ['m4_ifelse(m4_visibility, ['show'], ['m4_divert(-1)'], [''])m4_pushdef(['m4_visibility'], ['hide'])['']$1['']m4_popdef(['m4_visibility'])m4_ifelse(m4_visibility, ['show'], ['m4_divert['']'], [''])'])
m4_define(['m4_show'], ['m4_ifelse(m4_visibility, ['hide'], ['m4_divert['']'], [''])m4_pushdef(['m4_visibility'], ['show'])['']$1['']m4_popdef(['m4_visibility'])m4_ifelse(m4_visibility, ['hide'], ['m4_divert(-1)'], [''])'])
m4_define(['m4_define_hide'], ['m4_define(['$1'], ['m4_hide(['$2'])'])'])
// A legacy name for m4_define_hide:
m4_define(['m4_define_no_out'], ['m4_define_hide($@)'])

// These provide quotes that will pass through a macro arg.

// Echo the input. It can be used to force evaluation of a quoted string.
// E.g. if m4_some_string() returns a quoted string, m4_echo(m4_some_string())
// will evaluate it.
m4_define(['m4_echo'], ['$1'])

m4_define(['m4_open_quote'], ['m4_echo([)m4_echo(')'])
m4_define(['m4_close_quote'], ['m4_echo(')m4_echo(])'])

// m4_arg(3) returns ['$3']. This defers argument evaluation and is useful for generating strings to use as definitions.
m4_define(['m4_arg'], ['['['$$1']']'])

// Do nothing. This is used to preserve line alignment in pre_m4 processing for lines that will disappear.
m4_define(['m4_nothing'], [''])

// Similar to m4_ifelse.
// m4_case(m4_case_var, ['value1'], content1, ['value2'], content2, ...)
// m4_case(m4_case_var, ['value1'], content1, default_content)
m4_define(
  ['m4_case'],
  ['m4_ifelse(
    m4_eval(['$# < 3']),
    ['1'],
    ['m4_ifelse(m4_eval(['$# < 2']),
                ['1'],
                ['m4_errprint(['Error: No matching case at m4___line__ of m4___file__.'])'],
                ['$2'])'],
    ['m4_ifelse(
      ['$1'],
      ['$2'],
      ['$3'],
      ['m4_case(['$1'], m4_shift(m4_shift(m4_shift($@))))'])'])'])

// Similar to m4_ifelse, but condition is an m4_eval expression.
// m4_ifexpr(expr1, content1, expr2, content2, ...)
// m4_ifexpr(expr1, content1, default_content)
// m4_ifexpr(expr1, content1)
m4_define(
  ['m4_ifexpr'],
  ['m4_ifelse(
    m4_eval(['$# < 2']),
    ['1'],
    ['$1'],
    ['m4_ifelse(
      m4_eval(['$1']),
      1,
      ['$2'],
      ['m4_ifexpr(m4_shift(m4_shift($@)))'])'])'])

// m4_prefix_lines(['prefix'], ['body'])
// Add a prefix after all newlines in body, returning the quoted updated body.
// Body should start w/ \n so the line after it gets a prefix.
m4_define(['m4_prefix_lines2'], ['m4_quote(m4_patsubst(['$2'], ['
'], ['
$1']))'])
m4_define(['m4_prefix_lines'], ['m4_patsubst(['['$2']'], ['
'], ['
$1'])'])

// Substitute lines with newline, or a given string for each parameter (for preserving line count for a block macro parameter).
// Note that the substituted pattern is the argument list, which includes a new line for each new line of all
// arguments.
m4_define(['m4_empty_lines'], ['m4_patsubst(['$@'], ['[^
]+'], [''])'])
m4_define(['m4_replace_lines'], ['m4_quote(m4_patsubst(['m4_shift($@)'], ['[^
]+'], ['$1']))'])

// Substitute macro arguments.
// E.g. m4_substitute_args(['stuff with args like $']['1 and so on.'], ['arg1'])
// Results in: ['stuff with args like arg1 and so on.']
m4_define(['m4_substitute_args'], ['m4_pushdef(['m4_expand'], ['['$1']'])m4_expand(m4_shift($@))['']m4_popdef(['m4_expand'])'])


m4_divert['']m4_dnl
