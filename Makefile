# Makefile for SPI Slave simulation

# 编译器设置
IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave

# 文件设置
TOP_MODULE = spi_slave_tb
CONTINUOUS_MODULE = spi_slave_continuous_clk_tb
SOURCES = spi_slave.v spi_slave_tb.v
CONTINUOUS_SOURCES = spi_slave.v spi_slave_continuous_clk_tb.v
OUTPUT = $(TOP_MODULE).vvp
CONTINUOUS_OUTPUT = $(CONTINUOUS_MODULE).vvp
VCD_FILE = $(TOP_MODULE).vcd
CONTINUOUS_VCD_FILE = $(CONTINUOUS_MODULE).vcd

# 默认目标
all: compile simulate

# 编译门控时钟版本
compile: $(OUTPUT)

$(OUTPUT): $(SOURCES)
	$(IVERILOG) -o $(OUTPUT) $(SOURCES)

# 编译连续时钟版本
compile-continuous: $(CONTINUOUS_OUTPUT)

$(CONTINUOUS_OUTPUT): $(CONTINUOUS_SOURCES)
	$(IVERILOG) -o $(CONTINUOUS_OUTPUT) $(CONTINUOUS_SOURCES)

# 仿真门控时钟版本
simulate: $(OUTPUT)
	$(VVP) $(OUTPUT)

# 仿真连续时钟版本
simulate-continuous: $(CONTINUOUS_OUTPUT)
	$(VVP) $(CONTINUOUS_OUTPUT)

# 查看波形
wave: $(VCD_FILE)
	$(GTKWAVE) $(VCD_FILE)

wave-continuous: $(CONTINUOUS_VCD_FILE)
	$(GTKWAVE) $(CONTINUOUS_VCD_FILE)

# 清理
clean:
	rm -f $(OUTPUT) $(VCD_FILE) $(CONTINUOUS_OUTPUT) $(CONTINUOUS_VCD_FILE)

# 完整流程
test: clean compile simulate
test-continuous: clean compile-continuous simulate-continuous
test-all: test test-continuous

.PHONY: all compile compile-continuous simulate simulate-continuous wave wave-continuous clean test test-continuous test-all