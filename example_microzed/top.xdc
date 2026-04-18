
set_operating_conditions -airflow 0
set_operating_conditions -heatsink low

create_clock -period 10.000 -name clk_100 -waveform {0.000 5.000} [get_pins */PS7_inst/FCLKCLK[0]]
# create_clock -period 8.000 -name lvds_clk_125 -waveform {0.000 4.000} [get_port cmv_lvds_outclk_*]
