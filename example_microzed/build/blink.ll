Revision 3
; Created by bitgen 2025.2 at Fri Apr 17 16:33:56 2026
; Bit lines have the following form:
; <offset> <frame address> <frame offset> <information>
; <information> may be zero or more <kw>=<value> pairs
; Block=<blockname     specifies the block associated with this
;                      memory cell.
;
; Latch=<name>         specifies the latch associated with this memory cell.
;
; Net=<netname>        specifies the user net associated with this
;                      memory cell.
;
; COMPARE=[YES | NO]   specifies whether or not it is appropriate
;                      to compare this bit position between a
;                      "program" and a "readback" bitstream.
;                      If not present the default is NO.
;
; Ram=<ram id>:<bit>   This is used in cases where a CLB function
; Rom=<ram id>:<bit>   generator is used as RAM (or ROM).  <Ram id>
;                      will be either 'F', 'G', or 'M', indicating
;                      that it is part of a single F or G function
;                      generator used as RAM, or as a single RAM
;                      (or ROM) built from both F and G.  <Bit> is
;                      a decimal number.
;
; Info lines have the following form:
; Info <name>=<value>  specifies a bit associated with the LCA
;                      configuration options, and the value of
;                      that bit.  The names of these bits may have
;                      special meaning to software reading the .ll file.
;
Info STARTSEL0=1
Bit 14458627 0x00401b1f   1891 Block=SLICE_X86Y79 Latch=AQ Net=div_led_inst/stage_15
Bit 14458691 0x00401b1f   1955 Block=SLICE_X86Y80 Latch=AQ Net=div_led_inst/stage_14
Bit 14109443 0x0040199f   1763 Block=SLICE_X80Y77 Latch=AQ Net=div_led_inst/stage_25
Bit 14109444 0x0040199f   1764 Block=SLICE_X81Y77 Latch=AQ Net=div_led_inst/stage_24
Bit 14109507 0x0040199f   1827 Block=SLICE_X80Y78 Latch=AQ Net=div_led_inst/stage_26
Bit 14109508 0x0040199f   1828 Block=SLICE_X81Y78 Latch=AQ Net=div_led_inst/blue_led
Bit 14109571 0x0040199f   1891 Block=SLICE_X80Y79 Latch=AQ Net=div_led_inst/stage_0
Bit 14109572 0x0040199f   1892 Block=SLICE_X81Y79 Latch=AQ Net=div_led_inst/stage_22
Bit 14109635 0x0040199f   1955 Block=SLICE_X80Y80 Latch=AQ Net=div_led_inst/stage_1
Bit 14109636 0x0040199f   1956 Block=SLICE_X81Y80 Latch=AQ Net=div_led_inst/stage_2
Bit 14109700 0x0040199f   2020 Block=SLICE_X81Y81 Latch=AQ Net=div_led_inst/stage_3
Bit 14109763 0x0040199f   2083 Block=SLICE_X80Y82 Latch=AQ Net=div_led_inst/stage_4
Bit 14109764 0x0040199f   2084 Block=SLICE_X81Y82 Latch=AQ Net=div_led_inst/stage_5
Bit 14225795 0x00401a1f   1763 Block=SLICE_X82Y77 Latch=AQ Net=div_led_inst/stage_23
Bit 14225860 0x00401a1f   1828 Block=SLICE_X83Y78 Latch=AQ Net=div_led_inst/stage_18
Bit 14225923 0x00401a1f   1891 Block=SLICE_X82Y79 Latch=AQ Net=div_led_inst/stage_21
Bit 14225924 0x00401a1f   1892 Block=SLICE_X83Y79 Latch=AQ Net=div_led_inst/stage_17
Bit 14225988 0x00401a1f   1956 Block=SLICE_X83Y80 Latch=AQ Net=div_led_inst/stage_11
Bit 14226051 0x00401a1f   2019 Block=SLICE_X82Y81 Latch=AQ Net=div_led_inst/stage_10
Bit 14226052 0x00401a1f   2020 Block=SLICE_X83Y81 Latch=AQ Net=div_led_inst/stage_8
Bit 14226115 0x00401a1f   2083 Block=SLICE_X82Y82 Latch=AQ Net=div_led_inst/stage_6
Bit 14226116 0x00401a1f   2084 Block=SLICE_X83Y82 Latch=AQ Net=div_led_inst/stage_7
Bit 14342211 0x00401a9f   1827 Block=SLICE_X84Y78 Latch=AQ Net=div_led_inst/stage_19
Bit 14342275 0x00401a9f   1891 Block=SLICE_X84Y79 Latch=AQ Net=div_led_inst/stage_20
Bit 14342276 0x00401a9f   1892 Block=SLICE_X85Y79 Latch=AQ Net=div_led_inst/stage_16
Bit 14342339 0x00401a9f   1955 Block=SLICE_X84Y80 Latch=AQ Net=div_led_inst/stage_12
Bit 14342340 0x00401a9f   1956 Block=SLICE_X85Y80 Latch=AQ Net=div_led_inst/stage_13
Bit 14342403 0x00401a9f   2019 Block=SLICE_X84Y81 Latch=AQ Net=div_led_inst/stage_9
