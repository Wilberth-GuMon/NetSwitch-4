create_clock -name clk_i -period 2.5 [get_ports clk_i]
set_property HD.CLK_SRC BUFGCTRL_X0Y0 [get_ports clk_i]
set_false_path -from [get_ports -filter {DIRECTION == IN && NAME !~ "*clk*"}]
set_false_path -to [get_ports -filter {DIRECTION == OUT}]
