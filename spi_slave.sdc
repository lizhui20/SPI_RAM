create_clock -name spi_clk -period 20.0 [get_ports spi_clk]


set_clock_uncertainty 0.5 [get_clocks spi_clk]


set_false_path -from [get_ports rst_n]


set_input_delay -clock spi_clk -max 2.0 [get_ports csb]
set_input_delay -clock spi_clk -min 0.5 [get_ports csb]


set_input_delay -clock spi_clk -max 2.0 [get_ports mosi]
set_input_delay -clock spi_clk -min 0.5 [get_ports mosi]


set_input_delay -clock spi_clk -max 2.0 [get_ports ldb]
set_input_delay -clock spi_clk -min 0.5 [get_ports ldb]


set_input_delay -clock spi_clk -max 5.0 [get_ports sensor_data_*]
set_input_delay -clock spi_clk -min 1.0 [get_ports sensor_data_*]

#
set_output_delay -clock spi_clk -max 3.0 [get_ports miso]
set_output_delay -clock spi_clk -min 0.5 [get_ports miso]



set_load 0.5 [get_ports miso]


set_max_fanout 16 [current_design]


set_max_transition 1.0 [current_design]


