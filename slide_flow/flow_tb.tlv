\m4_TLV_version 1c: tl-x.org
\SV
   // SystemVerilog
   
   // A generic macro that instantiates a "distance" module,
   // providing clock, reset, and checking.  Since the
   // SystemVerilog module instantiation is not the focus of
   // this example, it is burried in a macro.
   // Focus on "design.tlv" to the right.
   //
   // Note that simulation reports "failure" because
   // design.tlv does not declare success.
   
   m4_top_module_inst(top, 100)
