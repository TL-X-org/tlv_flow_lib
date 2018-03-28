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



// Generic loop macros.

// m4_forloop(var, from, to, stmt) - simple version
m4_define(['m4_forloop'], ['m4_pushdef(['$1'], ['m4_eval($2)'])m4__forloop($@)m4_popdef(['$1'])'])
m4_define(['m4__forloop'],
          ['m4_ifelse(m4_eval($1 < $3), 1, ['$4['']m4_define(['$1'], m4_incr($1))$0($@)'], [''])'])



// These provide quotes that will pass through a macro arg.

// Echo the input.
m4_define(['m4_echo'], ['$1'])

m4_define(['m4_open_quote'], ['m4_echo([)m4_echo(')'])
m4_define(['m4_close_quote'], ['m4_echo(')m4_echo(])'])



// Add a line prefix to all given lines.
m4_define(['m4_prefix_lines'], ['m4_patsubst(['$2'], ['
'], ['
$1'])'])




m4_divert['']m4_dnl
