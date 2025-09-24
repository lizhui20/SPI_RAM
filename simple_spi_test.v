// 简化的SPI从机测试
// 可以在EDAPlayground.com等在线平台运行

`timescale 1ns/1ps

module simple_spi_test;
    // 测试信号
    reg rst_n;
    reg spi_clk;
    reg mosi;
    wire miso;
    reg csb;
    reg ldb;
    
    // 传感器数据
    reg [10:0] sensor_data_0 = 11'h555;
    reg [10:0] sensor_data_1 = 11'h3AA;
    
    // 实例化DUT
    spi_slave dut (
        .rst_n(rst_n),
        .spi_clk(spi_clk),
        .mosi(mosi),
        .miso(miso),
        .csb(csb),
        .ldb(ldb),
        .sensor_data_0(sensor_data_0),
        .sensor_data_1(sensor_data_1),
        .sensor_data_2(11'h0), .sensor_data_3(11'h0),
        .sensor_data_4(11'h0), .sensor_data_5(11'h0),
        .sensor_data_6(11'h0), .sensor_data_7(11'h0),
        .sensor_data_8(11'h0), .sensor_data_9(11'h0),
        .sensor_data_10(11'h0), .sensor_data_11(11'h0),
        .sensor_data_12(11'h0), .sensor_data_13(11'h0),
        .sensor_data_14(11'h0), .sensor_data_15(11'h0)
    );
    
    // 时钟生成
    initial begin
        spi_clk = 0;
        forever #10 spi_clk = ~spi_clk; // 50MHz
    end
    
    // 测试序列
    initial begin
        // 初始化
        rst_n = 0;
        csb = 1;
        ldb = 1;
        mosi = 0;
        
        // 复位释放
        #100;
        rst_n = 1;
        #50;
        
        // 测试LDB数据加载
        $display("测试LDB数据加载...");
        csb = 0;
        #20;
        ldb = 0;  // 触发传感器数据加载
        #20;
        ldb = 1;
        #20;
        csb = 1;
        #100;
        
        // 测试SPI读操作
        $display("测试SPI读操作 - 地址0...");
        spi_write_read(1, 4'h0, 11'h000); // 读操作
        #200;
        
        // 测试SPI写操作
        $display("测试SPI写操作 - 地址1写入0x123...");
        spi_write_read(0, 4'h1, 11'h123); // 写操作
        #200;
        
        // 再次读取验证
        $display("验证写入 - 读取地址1...");
        spi_write_read(1, 4'h1, 11'h000); // 读操作
        #200;
        
        $display("测试完成");
        $finish;
    end
    
    // SPI传输任务
    task spi_write_read(input rw, input [3:0] addr, input [10:0] data);
        integer i;
        reg [15:0] frame;
        begin
            frame = {rw, addr, data};
            csb = 0;
            #20;
            
            for (i = 15; i >= 0; i = i - 1) begin
                @(negedge spi_clk);
                mosi = frame[i];
                #1;
                if (rw && i <= 10) begin // 读操作时检查MISO
                    $display("MISO[%0d] = %b", 15-i, miso);
                end
            end
            
            #20;
            csb = 1;
            #50;
        end
    endtask
    
    // 监控
    initial begin
        $dumpfile("spi_test.vcd");
        $dumpvars(0, simple_spi_test);
        $monitor("Time=%0t, csb=%b, ldb=%b, mosi=%b, miso=%b", 
                 $time, csb, ldb, mosi, miso);
    end
    
endmodule