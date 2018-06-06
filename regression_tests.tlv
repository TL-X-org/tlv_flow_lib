\m4_TLV_version 1d: tl-x.org
\SV
/*
Copyright (c) 2015, Steven F. Hoover

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

   m4_include_url(['https://raw.githubusercontent.com/stevehoover/tlv_flow_lib/master/pipeflow_lib.tlv'])

   m4_makerchip_module

\TLV
   $reset = *reset;
   /stall_stage_test
      m4+simple_flow_macro_testbench()
      m4+stall_stage(/stall_stage_test, |pipe1, @1, |pipe3, @1, /trans)
   /stall_pipeline_test
      m4+simple_flow_macro_testbench()
      m4+stall_pipeline(/stall_pipeline_test, |pipe, 1, 3, /trans)
   /bp_pipeline_test
      m4+simple_flow_macro_testbench()
      m4+bp_pipeline(/bp_pipeline_test, |pipe, 1, 3, /trans)

   *passed = *cyc_cnt > 100 &&
             (/top/stall_stage_test|pipe3>>1$passed ||
              /top/stall_pipeline_test|pipe3>>1$passed ||
              /top/bp_pipeline_test|pipe3>>1$passed ||
              1'b0);
   *failed = *cyc_cnt > 102;
   
\SV
   endmodule
