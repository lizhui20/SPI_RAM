# SPI传感器数据采集系统开发指南

## 项目架构概述

这是一个基于SPI协议的传感器数据采集系统，核心是`spi_slave.v`模块，实现了双重数据路径架构：

- **SPI通信路径**: 通过4线SPI接口(spi_clk, mosi, miso, csb)与主设备通信
- **传感器数据路径**: 16个并行11位传感器数据输入(sensor_data_0到sensor_data_15)
- **LDB优先加载机制**: `ldb`信号下降沿触发的高优先级传感器数据同步加载

## 关键设计模式

### 双时钟域状态机
```verilog
// 状态转换在negedge spi_clk，避免建立/保持时间问题
always @(negedge spi_clk or negedge rst_n) begin
    current_state <= next_state;
end

// MISO输出在posedge spi_clk，确保数据稳定性
always @(posedge spi_clk or negedge rst_n) begin
    miso <= read_data_reg[bit_index];
end
```

### 优先级控制的RAM访问
系统使用严格的优先级控制：
1. **最高优先级**: LDB传感器数据加载（覆盖所有其他操作）
2. **次优先级**: SPI写入操作
3. **默认**: 保持状态清除

### 16位SPI帧格式
- Bit 0: 读写控制位 (0=写, 1=读)
- Bit 1-4: 4位地址 (0x0-0xF)
- Bit 5-15: 11位数据

## 开发约定

### 时钟域规范
- **negedge spi_clk**: 状态机更新、数据接收、地址解析
- **posedge spi_clk**: RAM写入控制、MISO输出、传感器数据加载

### 信号命名约定
- `_req`: 请求信号，持续有效直到被清除
- `_trigger`: 单周期触发信号
- `_buf`: 缓冲寄存器，用于跨时钟域传输
- `_pulse`: 基于trigger的脉冲检测

### 状态机设计原则
使用4状态Moore机：`IDLE → RW_BIT → ADDR_BITS → DATA_BITS`
- 每个状态明确单一职责
- CSB高电平时强制返回IDLE
- bit_counter驱动状态转换

## 关键调试点

### LDB时序检查
LDB检测仅在前5个时钟周期有效：
```verilog
if (bit_counter <= 5'd4 && !ldb) begin
    sensor_load_trigger <= 1'b1;
end
```

### SPI时序验证
- 确认negedge采样与posedge输出的时序关系
- 验证16位帧边界对齐
- 检查CSB去抖和状态复位

### 数据完整性
- 11位传感器数据的MSB对齐
- RAM地址4位限制 (0x0-0xF)
- 读写模式切换的数据锁存时机

## 扩展指南

添加新传感器时，需要更新：
1. 端口声明中的sensor_data_N输入
2. 传感器数据加载的always块中的赋值语句
3. 如果超过16个传感器，需扩展地址位宽和RAM深度

修改SPI协议时注意：
- 保持双时钟域设计原则
- 维护LDB优先级机制
- 确保状态机的确定性转换