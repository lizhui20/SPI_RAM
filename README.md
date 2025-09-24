# SPI Slave with Internal RAM

一个基于Verilog HDL实现的高性能SPI从设备模块，集成了内部RAM存储和传感器数据接口，采用跨时钟域安全设计。

## 项目概述

本项目实现了一个功能完整的SPI从设备，具有以下特性：
- 16位深度，11位宽的内部RAM
- 支持16个传感器数据输入接口
- 专用的LDB（Load Data Bus）信号用于批量加载传感器数据
- 标准SPI接口（MOSI、MISO、SCLK、CS）
- 跨时钟域安全设计，零多驱动冲突
- 支持50MHz高速SPI通信

## 文件结构

```
SPI_RAM/
├── spi_slave.v      # SPI从设备主模块
├── spi_slave_tb.v   # 测试台文件
├── spi_slave.sdc    # 综合约束文件（50MHz）
├── Makefile         # 编译脚本
└── README.md        # 项目文档
```

## 模块接口

### 端口定义

```verilog
module spi_slave (
    // SPI接口
    input  wire        rst_n,           // 异步复位（低电平有效）
    input  wire        spi_clk,         // SPI时钟（最高50MHz）
    input  wire        mosi,            // 主设备输出，从设备输入
    output reg         miso,            // 主设备输入，从设备输出
    input  wire        csb,             // 片选信号（低电平有效）
    input  wire        ldb,             // 加载数据总线信号（低电平触发）
    
    // 传感器数据接口 (16个11位传感器)
    input  wire [10:0] sensor_data_0,   // 传感器0数据
    input  wire [10:0] sensor_data_1,   // 传感器1数据
    // ... sensor_data_2 到 sensor_data_15
    input  wire [10:0] sensor_data_15   // 传感器15数据
);
```

### 信号说明

| 信号名 | 方向 | 位宽 | 功能描述 |
|--------|------|------|----------|
| rst_n | 输入 | 1 | 异步复位，低电平有效 |
| spi_clk | 输入 | 1 | SPI时钟信号，支持最高50MHz |
| mosi | 输入 | 1 | SPI数据输入（Master Out Slave In） |
| miso | 输出 | 1 | SPI数据输出（Master In Slave Out） |
| csb | 输入 | 1 | SPI片选，低电平有效 |
| ldb | 输入 | 1 | 传感器数据加载控制，低电平触发 |
| sensor_data_x | 输入 | 11 | 16个传感器数据输入端口 |

## 功能特性

### 1. SPI通信协议

- **数据格式**：16位数据帧
- **位序**：MSB优先
- **时钟模式**：Mode 0 (CPOL=0, CPHA=0)
- **最高频率**：50MHz
- **数据帧结构**：
  ```
  位15：读写控制位（0=写入，1=读取）
  位14-11：4位地址（0x0-0xF）
  位10-0：11位数据
  ```

### 2. 内部RAM存储

- **容量**：16个地址 × 11位数据
- **地址范围**：0x0 - 0xF
- **访问方式**：
  - SPI写入访问（单地址写入）
  - 传感器数据批量加载（16地址同时写入）
  - SPI读取访问（单地址读取）

### 3. 传感器数据接口

- **传感器数量**：16个独立输入
- **数据位宽**：每个传感器11位
- **加载方式**：LDB信号低电平触发，一次性加载所有传感器数据
- **加载优先级**：高于SPI写入操作

### 4. 工作模式详解

#### 写模式（位15 = 0）
1. CSB拉低，开始SPI传输
2. 位15接收到0，确定为写模式
3. 位14-11接收4位目标地址
4. 位10-0接收11位写入数据
5. 传输完成，数据写入指定RAM地址

#### 读模式（位15 = 1）
1. CSB拉低，开始SPI传输
2. 位15接收到1，确定为读模式
3. 位14-11接收4位目标地址
4. 地址确定后，立即准备MISO输出数据
5. 位10-0期间，通过MISO输出11位读取数据

#### 传感器加载模式
- LDB信号检测：仅在SPI传输前5个时钟周期内有效
- 触发条件：LDB信号为低电平
- 加载操作：同时将所有16个传感器数据写入RAM对应地址
- 优先级：高于SPI写入，低于复位操作

## 设计架构

### 跨时钟域设计

本设计采用创新的双时钟边沿架构，彻底解决多驱动冲突：

```
negedge spi_clk域          同步器          posedge spi_clk域
┌─────────────────┐      ┌─────────┐      ┌─────────────────┐
│  SPI数据采样    │────→ │ 双FF    │────→ │  RAM写入操作    │
│  LDB检测        │      │ 同步器  │      │  MISO输出       │
│  触发信号生成   │      └─────────┘      │  状态管理       │
└─────────────────┘                     └─────────────────┘
```

#### 1. negedge spi_clk域职责
- SPI数据采样和移位
- 地址和控制信息解析  
- LDB信号检测
- 触发信号生成（spi_write_trigger, sensor_load_trigger）

#### 2. posedge spi_clk域职责
- 跨时钟域信号同步
- RAM写入操作执行
- MISO数据输出
- 系统状态管理

### 跨时钟域同步机制

```verilog
// 双寄存器同步器设计
reg trigger_sync1, trigger_sync2;
always @(posedge spi_clk) begin
    trigger_sync1 <= trigger_signal;    // 第一级同步
    trigger_sync2 <= trigger_sync1;     // 第二级同步  
end

// 上升沿检测生成单周期脉冲
wire pulse = trigger_sync1 & ~trigger_sync2;
```

### 多驱动冲突解决方案

本设计完全消除了多驱动冲突：

| 信号类型 | 驱动域 | 解决方案 |
|----------|--------|----------|
| 触发信号 | negedge域 | 专用域驱动，不在其他域赋值 |
| 同步寄存器 | posedge域 | 专用域驱动，不在其他域赋值 |
| RAM控制 | posedge域 | 通过脉冲检测统一控制 |
| 状态机 | negedge域 | 独立状态管理 |

## 综合约束文件

### SDC约束 (spi_slave.sdc)

```tcl
# 创建50MHz主时钟
create_clock -name spi_clk -period 20.0 [get_ports spi_clk]

# 设置时钟不确定性
set_clock_uncertainty 0.5 [get_clocks spi_clk]

# 异步复位虚假路径
set_false_path -from [get_ports rst_n]

# SPI接口时序约束
set_input_delay -clock spi_clk -max 2.0 [get_ports {csb mosi ldb}]
set_input_delay -clock spi_clk -min 0.5 [get_ports {csb mosi ldb}]
set_output_delay -clock spi_clk -max 3.0 [get_ports miso]
set_output_delay -clock spi_clk -min 0.5 [get_ports miso]

# 传感器数据时序约束
set_input_delay -clock spi_clk -max 5.0 [get_ports sensor_data_*]
set_input_delay -clock spi_clk -min 1.0 [get_ports sensor_data_*]

# 设计约束
set_max_fanout 16 [current_design]
set_max_transition 1.0 [current_design]
set_min_pulse_width 8.0 [get_clocks spi_clk]
```

## 仿真验证

### 测试台功能 (spi_slave_tb.v)

1. **基本SPI通信测试**：
   - 写入操作验证
   - 读取操作验证
   - 数据完整性检查

2. **传感器数据加载测试**：
   - LDB信号触发验证
   - 批量数据加载检查
   - 优先级测试

3. **边界条件测试**：
   - 复位功能验证
   - 片选信号测试
   - 时序边界验证

4. **跨时钟域测试**：
   - 同步器功能验证
   - 多驱动冲突检查

### 运行仿真

```bash
# 使用Makefile（推荐）
make compile    # 编译设计文件
make simulate   # 运行仿真
make wave       # 查看波形文件

# 手动运行
iverilog -o spi_slave_tb spi_slave.v spi_slave_tb.v
vvp spi_slave_tb
gtkwave dump.vcd  # 查看波形
```

## 综合实现

### 设计优势

- ✅ **零多驱动冲突**：每个信号单一驱动源
- ✅ **无锁存器推断**：完全同步设计  
- ✅ **时序收敛**：满足50MHz约束
- ✅ **功能验证**：完整测试覆盖
- ✅ **跨时钟域安全**：双寄存器同步器
- ✅ **标准化接口**：符合SPI标准

### 资源估算

| 资源类型 | 数量估算 | 说明 |
|----------|----------|------|
| 寄存器 | ~80个 | 状态机、同步器、缓存 |
| 组合逻辑 | 最小化 | 优化设计减少逻辑 |
| 存储器 | 16×11位 | 内部RAM块 |
| 时钟域 | 2个 | 双边沿设计 |

### 时序分析

- **建立时间**：满足50MHz要求
- **保持时间**：跨时钟域安全保证
- **传播延迟**：优化关键路径
- **时钟偏斜**：0.5ns余量设计

## 应用示例

### 1. 系统集成

```verilog
// 实例化SPI从设备模块
spi_slave u_spi_slave (
    // 系统信号
    .rst_n(system_reset_n),
    .spi_clk(spi_master_clock),
    
    // SPI接口
    .mosi(spi_master_out),
    .miso(spi_master_in),
    .csb(spi_chip_select_n),
    
    // 控制信号
    .ldb(load_sensor_data),
    
    // 传感器接口
    .sensor_data_0(temperature_sensor),
    .sensor_data_1(pressure_sensor),
    .sensor_data_2(humidity_sensor),
    // 连接其他传感器...
    .sensor_data_15(spare_sensor)
);
```

### 2. 主机端操作示例

```c
// 写入操作：向地址0x5写入数据0x3FF
uint16_t write_frame = 0x0 << 15 |    // 写模式
                       0x5 << 11 |    // 地址0x5  
                       0x3FF;         // 数据0x3FF
spi_transfer(write_frame);

// 读取操作：从地址0x5读取数据
uint16_t read_frame = 0x1 << 15 |     // 读模式
                      0x5 << 11 |     // 地址0x5
                      0x000;          // 数据位无关
uint16_t read_data = spi_transfer(read_frame) & 0x7FF;  // 取低11位

// 传感器数据加载
gpio_set_low(LDB_PIN);   // 触发传感器数据加载
gpio_set_high(LDB_PIN);  // 完成加载
```

