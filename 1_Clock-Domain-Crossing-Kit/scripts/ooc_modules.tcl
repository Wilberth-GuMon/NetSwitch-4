# -----------------------------------------------------------------------------
# ooc_modules.tcl
# Out-of-context implementation of each CDC-Kit primitive on its own.
# Run from the repository root in a fresh non-project session:
#   vivado -mode batch -source scripts/ooc_modules.tcl
# Reports go to reports/ooc_modules/<top>_<pass>_*.rpt
#   ref  : reference clocks (§1.3) -> utilization, closure, power
#   fmax : every clock at FMAX_T ns -> Fmax = 1 / (FMAX_T - WNS) per clock
# Module ports are false paths: timing is register to register inside the IP.
# -----------------------------------------------------------------------------
set part   xc7a100tcsg324-1
set out    reports/ooc_modules
set FMAX_T 2.5
set rtl    {pkg sync rst_sync pulse_sync hs afifo_mem afifo_wptr afifo_rptr afifo}

# top, generics, {clock_port period ...} for the ref pass, {clock_port {input ports}}
set runs {
  {cdckit_afifo      {}          {wclk_i 6.4 rclk_i 4.0}
                                 {wclk_i {wrst_ni wr_en_i wr_data_i[*]} rclk_i {rrst_ni rd_en_i}}}
  {cdckit_hs         {DATA_W=64} {clk_src_i 6.4 clk_dst_i 10.0}
                                 {clk_src_i {rst_src_ni src_valid_i src_data_i[*]} clk_dst_i {rst_dst_ni}}}
  {cdckit_pulse_sync {}          {clk_src_i 10.0 clk_dst_i 6.4}
                                 {clk_src_i {rst_src_ni pulse_src_i} clk_dst_i {rst_dst_ni}}}
  {cdckit_rst_sync   {}          {clk_i 4.0} {}}
}

file mkdir $out

proc ooc {top generics clocks inputs pass} {
  global part out rtl
  catch {close_project}

  foreach f $rtl { read_verilog -sv rtl/cdckit_$f.sv }

  set xdc $out/${top}_${pass}_clocks.xdc
  set fh [open $xdc w]
  set i 0
  set names {}
  foreach {p t} $clocks {
    puts $fh "create_clock -name $p -period $t \[get_ports $p\]"
    puts $fh "set_property HD.CLK_SRC BUFGCTRL_X0Y$i \[get_ports $p\]"
    lappend names $p
    incr i
  }
  if {[llength $names] == 2} {
    puts $fh "set_clock_groups -asynchronous -group \[get_clocks [lindex $names 0]\] -group \[get_clocks [lindex $names 1]\]"
  }
  foreach {c ports} $inputs {
    puts $fh "set_input_delay -clock $c 0 \[get_ports {$ports}\]"
  }
  puts $fh "set_false_path -from \[get_ports -filter {DIRECTION == IN && NAME !~ \"*clk*\"}\]"
  puts $fh "set_false_path -to \[get_ports -filter {DIRECTION == OUT}\]"
  close $fh
  read_xdc $xdc

  set scoped constraints/$top.xdc
  if {[file exists $scoped]} {
    read_xdc -unmanaged -ref $top $scoped
    set_property PROCESSING_ORDER LATE [get_files $scoped]
  }

  set gopt {}
  foreach g $generics { lappend gopt -generic $g }
  synth_design -top $top -part $part -mode out_of_context {*}$gopt
  opt_design
  place_design
  route_design

  set base $out/${top}_${pass}
  report_timing_summary -file ${base}_timing.rpt
  if {$pass eq "ref"} {
    report_utilization -file ${base}_util.rpt
    report_power       -file ${base}_power.rpt
    report_cdc -details -file ${base}_cdc.rpt
    report_methodology -file ${base}_meth.rpt
  }
}

foreach r $runs {
  lassign $r top generics clocks inputs
  ooc $top $generics $clocks $inputs ref
  set fast {}
  foreach {p t} $clocks { lappend fast $p $FMAX_T }
  ooc $top $generics $fast $inputs fmax
}
puts "Done: reports in $out"
exit
