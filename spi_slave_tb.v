// SPI从机测试
`timescale 1ns/1ps

module spi_slave_tb;

    reg        rst_n;
    reg        spi_clk;
    reg        mosi;
    wire       miso;
    reg        csb;
    reg        ldb;
    
    // 传感器数据
    reg [10:0] sensor_data_0, sensor_data_1, sensor_data_2, sensor_data_3;
    reg [10:0] sensor_data_4, sensor_data_5, sensor_data_6, sensor_data_7;
    reg [10:0] sensor_data_8, sensor_data_9, sensor_data_10, sensor_data_11;
    reg [10:0] sensor_data_12, sensor_data_13, sensor_data_14, sensor_data_15;
    
    reg [10:0] read_result;
    
    spi_slave uut (
        .rst_n(rst_n),
        .spi_clk(spi_clk),
        .mosi(mosi),
        .miso(miso),
        .csb(csb),
        .ldb(ldb),
        .sensor_data_0(sensor_data_0),
        .sensor_data_1(sensor_data_1),
        .sensor_data_2(sensor_data_2),
        .sensor_data_3(sensor_data_3),
        .sensor_data_4(sensor_data_4),
        .sensor_data_5(sensor_data_5),
        .sensor_data_6(sensor_data_6),
        .sensor_data_7(sensor_data_7),
        .sensor_data_8(sensor_data_8),
        .sensor_data_9(sensor_data_9),
        .sensor_data_10(sensor_data_10),
        .sensor_data_11(sensor_data_11),
        .sensor_data_12(sensor_data_12),
        .sensor_data_13(sensor_data_13),
        .sensor_data_14(sensor_data_14),
        .sensor_data_15(sensor_data_15)
    );
    
    // 50MHz时钟
    always begin
        #25 spi_clk = 0;  // 10ns低电平
        #25 spi_clk = 1;  // 10ns高电平
    end
    
    // 连续MOSI随机噪声（仅在非SPI传输期间）
    always @(posedge spi_clk) begin
        if (csb) begin  // 只有在CSB高电平时才产生随机噪声
            mosi <= $random & 1;
        end
    end
    
    // 发送SPI数据任务
    task send_spi_word;
        input [15:0] data;
        integer i, random_ldb_cycle;
        begin
            #100;
            
            // 随机LDB触发时机（前5个周期）
            random_ldb_cycle = ($random % 5) + 1;
            
            @(posedge spi_clk);
            #1;
            csb = 0;
            
            // 传输16位数据
            for (i = 15; i >= 0; i = i - 1) begin
                @(posedge spi_clk);
                
                // MOSI与时钟上升沿对齐
                mosi = data[i];
                
                // 随机触发LDB
                if ((15 - i + 1) == random_ldb_cycle) begin
                    #1;
                    ldb = 0;
                    $display("    在SPI第%d个时钟周期触发LDB", 15 - i + 1);
                end
                
                if ((15 - i + 1) == random_ldb_cycle) begin
                    @(negedge spi_clk);
                    #1;
                    ldb = 1;
                end
            end
            
            @(posedge spi_clk);
            #1;
            csb = 1;
            #100;
        end
    endtask
    
    // 读取SPI数据任务
    task read_spi_word;
        input [15:0] cmd_data;
        output [10:0] read_data;
        integer i, random_ldb_cycle;
        reg [15:0] received_data;
        begin
            #100;
            
            // 随机LDB触发时机
            random_ldb_cycle = ($random % 5) + 1;
            
            @(posedge spi_clk);
            #1;
            csb = 0;
            
            received_data = 16'b0;
            
            // 传输并接收16位数据
            for (i = 15; i >= 0; i = i - 1) begin
                @(posedge spi_clk);
                
                // MOSI与时钟上升沿对齐
                mosi = cmd_data[i];
                
                // 随机触发LDB
                if ((15 - i + 1) == random_ldb_cycle) begin
                    #1;
                    ldb = 0;
                    $display("    在SPI读取第%d个时钟周期触发LDB", 15 - i + 1);
                end
                
                @(negedge spi_clk);
                #1;
                received_data[i] = miso;
                
                if ((15 - i + 1) == random_ldb_cycle) begin
                    #1;
                    ldb = 1;
                end
            end
            
            read_data = received_data[10:0];
            
            @(posedge spi_clk);
            #1;
            csb = 1;
            #100;
        end
    endtask
    
    // 主测试
    initial begin
        rst_n = 0;
        csb = 1;
        ldb = 1;
        mosi = 0;
        
        $srandom(42);
        
        // 初始化传感器数据
        sensor_data_0 = $random & 11'h7FF;
        sensor_data_1 = $random & 11'h7FF;
        sensor_data_2 = $random & 11'h7FF;
        sensor_data_3 = $random & 11'h7FF;
        sensor_data_4 = $random & 11'h7FF;
        sensor_data_5 = $random & 11'h7FF;
        sensor_data_6 = $random & 11'h7FF;
        sensor_data_7 = $random & 11'h7FF;
        sensor_data_8 = $random & 11'h7FF;
        sensor_data_9 = $random & 11'h7FF;
        sensor_data_10 = $random & 11'h7FF;
        sensor_data_11 = $random & 11'h7FF;
        sensor_data_12 = $random & 11'h7FF;
        sensor_data_13 = $random & 11'h7FF;
        sensor_data_14 = $random & 11'h7FF;
        sensor_data_15 = $random & 11'h7FF;
        
        $display("传感器数据:");
        $display("0x%h, 0x%h, 0x%h, 0x%h", sensor_data_0, sensor_data_1, sensor_data_2, sensor_data_3);
        $display("0x%h, 0x%h, 0x%h, 0x%h", sensor_data_4, sensor_data_5, sensor_data_6, sensor_data_7);
        $display("0x%h, 0x%h, 0x%h, 0x%h", sensor_data_8, sensor_data_9, sensor_data_10, sensor_data_11);
        $display("0x%h, 0x%h, 0x%h, 0x%h", sensor_data_12, sensor_data_13, sensor_data_14, sensor_data_15);
        
        #100;
        rst_n = 1;
        #100;
        
        $display("=== SPI测试开始 ===");
        
        $display("测试1：LDB触发传感器加载");
        send_spi_word({4'h0, 11'h123});
        #1000;
        
        // 验证加载结果
        $display("验证传感器数据加载:");
        for (integer addr = 0; addr < 16; addr = addr + 1) begin
            read_spi_word({1'b1, addr[3:0], 11'b0}, read_result);
            case (addr)
                0: $display("  地址%d: 0x%h vs 0x%h %s", addr, read_result, sensor_data_0, 
                           (read_result == sensor_data_0) ? "✓" : "✗");
                1: $display("  地址%d: 0x%h vs 0x%h %s", addr, read_result, sensor_data_1, 
                           (read_result == sensor_data_1) ? "✓" : "✗");
                2: $display("  地址%d: 0x%h vs 0x%h %s", addr, read_result, sensor_data_2, 
                           (read_result == sensor_data_2) ? "✓" : "✗");
                3: $display("  地址%d: 0x%h vs 0x%h %s", addr, read_result, sensor_data_3, 
                           (read_result == sensor_data_3) ? "✓" : "✗");
                default: $display("  地址%d: 0x%h", addr, read_result);
            endcase
        end
        
        // 测试2：更新传感器数据
        $display("测试2：更新传感器数据");
        sensor_data_0 = $random & 11'h7FF;
        sensor_data_1 = $random & 11'h7FF;
        sensor_data_5 = $random & 11'h7FF;
        sensor_data_10 = $random & 11'h7FF;
        sensor_data_15 = $random & 11'h7FF;
        
        $display("更新数据: 0x%h, 0x%h, 0x%h, 0x%h, 0x%h", 
                 sensor_data_0, sensor_data_1, sensor_data_5, sensor_data_10, sensor_data_15);
        
        #500;
        send_spi_word({4'h1, 11'h456});
        #1000;
        
        // 验证更新结果
        $display("验证更新后数据:");
        read_spi_word({1'b1, 4'h0, 11'b0}, read_result);
        $display("  地址0: 0x%h vs 0x%h %s", read_result, sensor_data_0, 
                (read_result == sensor_data_0) ? "✓" : "✗");
        read_spi_word({1'b1, 4'h1, 11'b0}, read_result);
        $display("  地址1: 0x%h vs 0x%h %s", read_result, sensor_data_1, 
                (read_result == sensor_data_1) ? "✓" : "✗");
        read_spi_word({1'b1, 4'h5, 11'b0}, read_result);
        $display("  地址5: 0x%h vs 0x%h %s", read_result, sensor_data_5, 
                (read_result == sensor_data_5) ? "✓" : "✗");
        read_spi_word({1'b1, 4'hA, 11'b0}, read_result);
        $display("  地址10: 读取=0x%h, 期望=0x%h %s", read_result, sensor_data_10, 
                (read_result == sensor_data_10) ? "✓" : "✗");
        read_spi_word({1'b1, 4'hF, 11'b0}, read_result);
        $display("  地址15: 读取=0x%h, 期望=0x%h %s", read_result, sensor_data_15, 
                (read_result == sensor_data_15) ? "✓" : "✗");

        // 测试3：多次快速LDB脉冲测试
        $display("测试3：多次快速LDB脉冲测试");
        
        // 测试3：快速LDB脉冲
        $display("测试3：快速LDB脉冲");
        for (integer pulse = 0; pulse < 3; pulse = pulse + 1) begin
            // 更新传感器数据
            case (pulse % 16)
                0:  sensor_data_0 = ($random & 11'h7FF);
                1:  sensor_data_1 = ($random & 11'h7FF);
                2:  sensor_data_2 = ($random & 11'h7FF);
                default: sensor_data_3 = ($random & 11'h7FF);
            endcase
        end
        
        send_spi_word({4'h2, 11'h789});
        #1000;
        
        // 验证部分数据
        for (integer addr = 0; addr < 16; addr = addr + 4) begin
            read_spi_word({1'b1, addr[3:0], 11'b0}, read_result);
            $display("  地址%d: 0x%h", addr, read_result);
        end

        // 测试4：随机SPI写操作
        $display("测试4：随机写操作");
        for (integer i = 0; i < 4; i = i + 1) begin
            reg [10:0] data = $random & 11'h7FF;
            reg [3:0] addr = $random & 4'hF;
            send_spi_word({addr, data});
        end
        
        // 测试5：SPI写入与LDB交互
        $display("测试5：写入与LDB交互");
        send_spi_word({4'h0, 11'hAAA});
        send_spi_word({4'h1, 11'hBBB});
        
        // 更新传感器数据
        sensor_data_0 = 11'h111;
        sensor_data_1 = 11'h222;
        
        read_spi_word({1'b1, 4'h0, 11'b0}, read_result);
        #1000;
        
        // 验证LDB覆盖
        read_spi_word({1'b1, 4'h0, 11'b0}, read_result);
        $display("  地址0: 0x%h vs 0x%h %s", read_result, sensor_data_0, 
                (read_result == sensor_data_0) ? "✓" : "✗");
        
        // 测试6：随机读操作
        $display("测试6：随机读操作");
        for (integer addr = 0; addr < 8; addr = addr + 2) begin
            read_spi_word({1'b1, addr[3:0], 11'b0}, read_result);
            $display("  地址%d: 0x%h", addr, read_result);
        end
        
        // 测试7：混合读写
        $display("测试7：混合读写");
        for (integer i = 0; i < 6; i = i + 1) begin
            reg [15:0] cmd = $random;
            reg [3:0] addr = (cmd >> 1) & 4'hF;
            reg [10:0] data = (cmd >> 5) & 11'h7FF;
            
            if (cmd[0]) begin
                read_spi_word({1'b1, addr, 11'b0}, read_result);
                $display("  读地址0x%h: 0x%h", addr, read_result);
            end else begin
                send_spi_word({addr, data});
                $display("  写地址0x%h: 0x%h", addr, data);
            end
        end
        
        #2000;
        $display("=== 测试完成 ===");
        $finish;
    end
    
    // 波形文件生成
    initial begin
        $dumpfile("spi_slave_tb.vcd");
        $dumpvars(0, spi_slave_tb);
    end

endmodule