module spi_slave (
    // SPI接口
    input  wire        rst_n,
    input  wire        spi_clk,
    input  wire        mosi,
    output reg         miso,
    input  wire        csb,
    input  wire        ldb,       // 下降沿加载传感器数据
    
    // 传感器数据接口
    input  wire [10:0] sensor_data_0,
    input  wire [10:0] sensor_data_1,
    input  wire [10:0] sensor_data_2,
    input  wire [10:0] sensor_data_3,
    input  wire [10:0] sensor_data_4,
    input  wire [10:0] sensor_data_5,
    input  wire [10:0] sensor_data_6,
    input  wire [10:0] sensor_data_7,
    input  wire [10:0] sensor_data_8,
    input  wire [10:0] sensor_data_9,
    input  wire [10:0] sensor_data_10,
    input  wire [10:0] sensor_data_11,
    input  wire [10:0] sensor_data_12,
    input  wire [10:0] sensor_data_13,
    input  wire [10:0] sensor_data_14,
    input  wire [10:0] sensor_data_15
);

    // 状态机状态定义
    typedef enum reg [2:0] {
        IDLE       = 3'b000,  // 空闲状态
        RW_BIT     = 3'b001,  // 接收读写控制位
        ADDR_BITS  = 3'b010,  // 接收地址位
        DATA_BITS  = 3'b011   // 处理数据位
    } spi_state_t;
    
    spi_state_t current_state, next_state;
    
    // 内部寄存器
    reg [15:0] shift_reg;
    reg [4:0]  bit_counter;
    reg        read_mode;
    reg [3:0]  target_addr;
    reg [3:0]  addr_shift;
    reg [10:0] read_data_reg;
    reg        addr_received;
    reg        transaction_active;
    
    // 内部RAM (11位宽，16位深)
    reg [10:0] internal_ram [0:15];
    

    
    // 写入控制信号 - 只在posedge块中赋值
    reg spi_write_req;
    reg [10:0] spi_write_data;
    reg [3:0] spi_write_addr;
    
    // 传感器数据加载控制 - 只在posedge块中赋值
    reg sensor_load_req;
    
    // 触发信号 - 用于单周期脉冲检测
    reg spi_write_trigger;
    reg [10:0] spi_write_data_buf;
    reg [3:0] spi_write_addr_buf;
    reg sensor_load_trigger;
    
    // 脉冲检测（直接使用触发信号）
    wire spi_write_pulse = spi_write_trigger;
    wire sensor_load_pulse = sensor_load_trigger;
    
    integer i;
    
    // 统一RAM写入控制：传感器数据加载优先级最高
    always @(posedge spi_clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_write_req <= 1'b0;
            spi_write_data <= 11'h0;
            spi_write_addr <= 4'h0;
            sensor_load_req <= 1'b0;
            for (i = 0; i < 16; i = i + 1) begin
                internal_ram[i] <= 11'h0;
            end
        end 
        else if (sensor_load_pulse) begin
            // 传感器数据同时加载（最高优先级）
                internal_ram[0] <= sensor_data_0;
                internal_ram[1] <= sensor_data_1;
                internal_ram[2] <= sensor_data_2;
                internal_ram[3] <= sensor_data_3;
                internal_ram[4] <= sensor_data_4;
                internal_ram[5] <= sensor_data_5;
                internal_ram[6] <= sensor_data_6;
                internal_ram[7] <= sensor_data_7;
                internal_ram[8] <= sensor_data_8;
                internal_ram[9] <= sensor_data_9;
                internal_ram[10] <= sensor_data_10;
                internal_ram[11] <= sensor_data_11;
                internal_ram[12] <= sensor_data_12;
                internal_ram[13] <= sensor_data_13;
                internal_ram[14] <= sensor_data_14;
                internal_ram[15] <= sensor_data_15;
                sensor_load_req <= 1'b0;
                spi_write_req <= 1'b0;
            end
            // SPI写入请求
            else if (spi_write_pulse) begin
                internal_ram[spi_write_addr_buf] <= spi_write_data_buf;
                spi_write_req <= 1'b1;
                spi_write_data <= spi_write_data_buf;
                spi_write_addr <= spi_write_addr_buf;
            end
            // 默认情况 - 只清除请求信号
            else begin
                spi_write_req <= 1'b0;
            end
    end

    // 状态机状态寄存器更新
    always @(negedge spi_clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else if (csb) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    // 状态转换逻辑
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (!csb) begin
                    next_state = RW_BIT;
                end
            end
            
            RW_BIT: begin
                if (bit_counter >= 5'd0) begin
                    next_state = ADDR_BITS;
                end
            end
            
            ADDR_BITS: begin
                if (bit_counter > 5'd4) begin
                    next_state = DATA_BITS;
                end
            end
            
            DATA_BITS: begin
                if (bit_counter >= 5'd15) begin
                    next_state = RW_BIT;  // 准备下一个16位帧
                end
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // SPI协议处理和LDB检测 - 状态机实现
    always @(negedge spi_clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 16'b0;
            bit_counter <= 5'b0;
            transaction_active <= 1'b0;
            read_mode <= 1'b0;
            target_addr <= 4'b0;
            addr_shift <= 4'b0;
            read_data_reg <= 11'b0;
            addr_received <= 1'b0;
            spi_write_trigger <= 1'b0;
            spi_write_data_buf <= 11'h0;
            spi_write_addr_buf <= 4'h0;
            sensor_load_trigger <= 1'b0;
        end else if (csb) begin
            // CSB高电平时清除状态
            transaction_active <= 1'b0;
            bit_counter <= 5'b0;
            read_mode <= 1'b0;
            addr_received <= 1'b0;
            addr_shift <= 4'b0;
            target_addr <= 4'b0;
            shift_reg <= 16'b0;
            read_data_reg <= 11'b0;
            spi_write_trigger <= 1'b0;
            spi_write_data_buf <= 11'h0;
            spi_write_addr_buf <= 4'h0;
            sensor_load_trigger <= 1'b0;
        end else begin
            // LDB检测（仅在前5个时钟周期，最高优先级）
            if (bit_counter <= 5'd4 && !ldb) begin
                sensor_load_trigger <= 1'b1;
            end
            
            // 状态机处理
            case (current_state)
                IDLE: begin
                    if (!transaction_active) begin
                        // 开始新的事务
                        transaction_active <= 1'b1;
                        bit_counter <= 5'b0;
                        shift_reg <= 16'b0;
                        addr_received <= 1'b0;
                        addr_shift <= 4'b0;
                    end
                end
                
                RW_BIT: begin
                    // 第0位：读写控制位
                    if (bit_counter == 5'd0) begin
                        read_mode <= mosi;
                        addr_shift <= 4'b0000;
                    end
                    // 接收数据并递增计数器
                    shift_reg <= {shift_reg[14:0], mosi};
                    bit_counter <= bit_counter + 1'b1;
                end
                
                ADDR_BITS: begin
                    // 第1-4位：地址接收
                    if (bit_counter >= 5'd1 && bit_counter <= 5'd4) begin
                        addr_shift <= {addr_shift[2:0], mosi};
                        if (bit_counter == 5'd4) begin
                            target_addr <= {addr_shift[2:0], mosi};
                            addr_received <= 1'b1;
                            // 读模式时立即锁存数据
                            if (read_mode) begin
                                read_data_reg <= internal_ram[{addr_shift[2:0], mosi}];
                            end
                        end
                    end
                    // 接收数据并递增计数器
                    shift_reg <= {shift_reg[14:0], mosi};
                    bit_counter <= bit_counter + 1'b1;
                end
                
                DATA_BITS: begin
                    // 第5-15位：数据位处理
                    if (bit_counter == 5'd15) begin
                        if (!read_mode) begin
                            // 写模式：设置写入触发信号和数据缓存
                            spi_write_trigger <= 1'b1;
                            spi_write_data_buf <= {shift_reg[9:0], mosi};
                            spi_write_addr_buf <= target_addr;
                        end
                        bit_counter <= 5'b0;  // 重置计数器准备下一帧
                    end else begin
                        // 接收数据并递增计数器
                        shift_reg <= {shift_reg[14:0], mosi};
                        bit_counter <= bit_counter + 1'b1;
                    end
                end
                
                default: begin
                    // 默认状态处理
                end
            endcase
        end
    end


    // MISO输出
    always @(posedge spi_clk or negedge rst_n) begin
        if (!rst_n) begin
            miso <= 1'b0;
        end else begin
            if (transaction_active && read_mode && !csb) begin
                if (addr_received) begin
                    // 第5-15位输出数据（第6-16个时钟周期）
                    if (bit_counter >= 5'd5 && bit_counter <= 5'd15) begin
                        case (bit_counter - 5'd5)
                            5'd0:  miso <= read_data_reg[10];
                            5'd1:  miso <= read_data_reg[9];
                            5'd2:  miso <= read_data_reg[8];
                            5'd3:  miso <= read_data_reg[7];
                            5'd4:  miso <= read_data_reg[6];
                            5'd5:  miso <= read_data_reg[5];
                            5'd6:  miso <= read_data_reg[4];
                            5'd7:  miso <= read_data_reg[3];
                            5'd8:  miso <= read_data_reg[2];
                            5'd9:  miso <= read_data_reg[1];
                            5'd10: miso <= read_data_reg[0];
                            default: miso <= 1'b0;
                        endcase
                    end else begin
                        miso <= 1'b0;
                    end
                end else begin
                    miso <= 1'b0;
                end
            end else begin
                miso <= 1'b0;
            end
        end
    end

endmodule