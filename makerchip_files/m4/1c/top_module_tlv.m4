m4_divert(['-1'])
/*
Copyright (c) 2014, Steven F. Hoover

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



// Module definition for main module corresponding to the invocation in m4_top_module_inst(...).
m4_define(['m4_top_module_def'], ['m4_dnl
m4_pushdef(['m4_name'], $1)m4_dnl
module m4_name[''](input logic clk, input logic reset, input logic [15:0] cyc_cnt, output logic passed, output logic failed); m4_use_rand(clk, reset)m4_dnl
m4_popdef(['m4_name'])m4_dnl
'])

// Module definition for main module in Makerchip.
m4_define(['m4_makerchip_module'], ['m4_dnl
module top(input logic clk, input logic reset, input logic [31:0] cyc_cnt, output logic passed, output logic failed); m4_use_rand(clk, reset)m4_dnl
'])





// A generic parameterized TLV environment wrapper with defaults for the "default"
// TLV project.
// This instantiates a top-level module definition that instantiates a submodule that
// is expected to be implemented in TLV.  The submodule is provided with
// clk and reset inputs, and provides a success output that will terminate simulation.
// m4_top_module_inst(name, max_cycles)
m4_define(['m4_top_module_inst'], ['m4_dnl
m4_divert(-1)
m4_pushdef(['m4_name'], $1)
m4_pushdef(['m4_max_cycles'], $2)
m4_divert['']m4_dnl

// -------------------------------------------------------------------
// Expanded from instantiation: m4_top_module_inst(m4_name, m4_max_cycles)
//

module m4_name['']_top();

logic clk, reset;      // Generated in this module for DUT.
logic passed, failed;  // Returned from DUT to this module.  Passed must assert before
                       //   max cycles, without failed having asserted.  Failed can be undriven.
logic [15:0] cyc_cnt;


// Instantiate main module.
m4_name m4_name (.*);


// Clock
initial begin
   clk = 1'b1;
   forever #5 clk = ~clk;
end


// Run
initial begin

   //`ifdef DUMP_ON
      $dumpfile("m4_name.vcd");
      $dumpvars;
      $dumpon;
   //`endif

   reset = 1'b1;
   #55;
   reset = 1'b0;

   // Run

   cyc_cnt = '0;
   for (int cyc = 0; cyc < m4_max_cycles; cyc++) begin
      // Failed
      if (failed === 1'b1) begin
         FAILED: assert(1'b1) begin
            $display("Failed!!!  Error condition asserted.");
            $finish;
         end
      end

      // Success
      if (passed) begin
         SUCCESS: assert(1'b1) begin
            $display("Success!!!");
            $finish;
         end
      end

      #10;

      cyc_cnt++;
   end

   // Fail
   DIE: assert (1'b1) begin
      $error("Failed!!!  Test did not complete within ['m4_max_cycles'] time.");
      $finish;
   end

end

endmodule  // life_tb

// -------------------------------------------------------------------

m4_divert(-1)
m4_popdef(['m4_max_cycles'])
m4_popdef(['m4_name'])
m4_divert'])




m4_divert['']m4_dnl
