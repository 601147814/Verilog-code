# FPGA 项目 Verilog 开发与工程规范文档


**文档版本**：V2.0（合并工程规范 + 代码规范）
**编制日期**：2026 年 05 月 09 日
**适用范围**：项目全流程 FPGA 开发、调试、评审、归档
**核心原则**：标准化、规范化、可综合、可维护、无隐性风险

----

## 目录

1. 文档总则

2. 开发环境与安装规范

3. 工程目录结构规范

4. 代码书写规范

5. 时钟设计规范

6. FIFO 使用规范

7. BRAM 使用规范

8. DSP 使用规范

9. 跨时钟域处理规范

10. 常见 Warning 处理规范

11. 附录：项目专属代码 / 注释模板

----

## 1. 文档总则

1. 本规范整合**工程目录、开发环境、代码风格、IP 使用、时序约束、问题排查**全流程要求，所有开发人员必须严格执行；

2. 工程路径、文件命名、代码编写**禁止使用中文、特殊字符、空格**；

3. 代码以**同步时序逻辑**为核心，统一低电平同步复位，杜绝异步逻辑滥用；

4. 所有模块必须标准化注释、规范化例化、层次化设计，禁止冗余逻辑与隐性 bug。

----

## 2. 开发环境与安装规范

### 2.1 工具版本

- 综合 / 实现工具：**Xilinx Vivado 2020.2**

- 仿真工具：**Modelsim / Questasim**

- 代码编辑器：**Notepad++**

### 2.2 安装路径约束

- 所有工具**安装路径必须全英文**，禁止包含中文、空格、特殊符号；

- 示例合规路径：`C:\MentorGraphics\questasim64_10.6c`

- 示例违规路径：`C:\软件\Xilinx`、`D:\FPGA 工程\Vivado`

----

## 3. 工程目录结构规范

### 3.1 根目录规范

- 工程存放路径**强制全英文**，使用脚本快速搭建目录；

- 根目录固定包含两个一级文件夹：表格
	|文件夹名|用途|
	|:-:|:-:|
	|00_src|存放源代码、IP、约束、仿真等所有设计文件|
	|01_proj|存放 Vivado 工程生成文件（.xpr、cache、log 等）|

### 3.2 00_src 子目录规范

表格

|文件夹名|用途|
|:-:|:-:|
|00_code|Verilog 源代码（按功能分模块）|
|01_lib|IP 核文件（clk_wiz、fifo、bram 等）|
|02_xdc|IO 约束、时序约束文件|
|03_block|Block Design 框图文件|
|04_bit|编译生成的 bit 文件归档|
|05_st|仿真测试文件（.v、.do）|

### 3.3 00_code 子目录规范

按功能划分文件夹，示例：

- 00_top：顶层模块

- 01_rst：复位相关模块

- 02_jesd204b：JESD204B 协议模块

- 03_uart：UART 通信模块

### 3.4 01_proj 目录规范

- 仅存放 Vivado 自动生成文件，**禁止手动添加设计代码**；

- 关键文件：`xxx.xpr`（工程文件）、日志文件、缓存文件。

----

## 4. 代码书写规范

### 4.1 对齐规范（强制）

1. 缩进统一**1 个 Tab**（4 个空格），禁止混用 Tab / 空格；

2. 关键字、位宽、信号名**独占一列，Tab 对齐**；

3. always 模块每一级逻辑缩进 1 个 Tab；

4. 端口、参数、例化信号**分行对齐，逗号后置**。

### 4.2 信号命名规范

1. 通用规则：小写 + 下划线，见名知意，禁止拼音 / 无意义命名；

2. 常用缩写：address→addr、clock→clk、reset→rst；

3. 低电平有效信号：后缀**_n**（rst_n、cs_n）；

4. 时钟信号：clk_频率（clk_100M、clk_122M88）；

5. 多级打拍信号：_d、_dd、_ddd（仅同一时钟域）；

6. 常量 / 参数：**全大写**（DATA_WIDTH、CLK_CYCLE）；

7. Top 层管脚：**全大写**（FX3_DATA、DAC_SCLK）。

### 4.3 模块与文件命名

1. 文件名 = 模块名，全小写，后缀`.v`；

2. 顶层模块：`top.v`；

3. Testbench：`xxx_tb.v`；

4. 模块后缀规范：
	- _ctrl：控制逻辑模块
	- _wrapper：封装模块
	- _cross：跨时钟域模块
	- _initial_cfg：初始化配置模块

5. 模块例化名：`u0_xxx`、`u1_xxx`（强制加前缀）。

### 4.4 Top 文件规范

1. Top 模块**仅做例化 + 信号连接**，无任何业务逻辑；

2. Top 内只允许出现**wire 信号**，禁止 reg 赋值逻辑。

### 4.5 Always 语句规范

1. 一个 always 块**仅赋值一个 / 一组强关联信号**；

2. 括号内参数与符号间加空格；

3. 条件判断必须完整：`if(rst_n == 1'b0)`，禁止`if(rst)`；

4. 位宽严格匹配：判断两边、赋值左右位宽必须一致；

5. if-else 必须写全，**禁止缺 else**；

6. case 语句必须加**default**，禁止 latch 生成。

### 4.6 状态机规范（强制三段式）

1. 状态定义：`localparam STP_xxx = 4'dx`；

2. 第一段：时序逻辑，现态赋值；

3. 第二段：组合逻辑，**仅做状态跳转**，禁止信号赋值；

4. 第三段：时序逻辑，所有输出信号赋值；

5. 必须加超时机制，防止死锁。

### 4.7 复位信号规范

1. 全局统一**低电平同步复位（rst_n）**，仅 1 个外部复位输入；

2. 复位从 PAD 输入必须**打拍同步**；

3. 每个模块默认必须有 rst_n（特殊模块除外）；

4. 无复位模块：纯打拍、状态机第三段（idle 初始化）、FIFO 读控制、分布式 RAM。

### 4.8 注释规范

1. 统一使用**英文注释**，禁止中文 / 拼音缩写；

2. 屏蔽代码：行首加 Tab，再加`//`注释；

3. 模块必须加标准头部注释；

4. 关键信号、状态机、时序逻辑必须加注释。

### 4.9 原代码规范合并（补充）

1. 端口顺序：时钟→复位→控制→数据输入→数据输出→外设接口；

2. 位宽显式声明：`[N-1:0]`，禁止隐式位宽；

3. 模块例化：**显式端口映射**，禁止顺序映射；

4. 跨时钟域：必须用`data_cross`/`reset_cross`，禁止直接打拍；

5. 组合逻辑：全覆盖分支，禁止 latch；

6. 调试 ILA：`generate if(ILA_MODULE == 1'b1)`，上线关闭。

----

## 5. 时钟设计规范

1. 时钟命名：`clk_频率`，例：clk_100M、clk_122M88；

2. 时钟生成：统一使用**clock wizard IP**，封装为`clock_wrapper`；

3. 时钟输出：必须包含`locked`信号，时钟未锁定时保持复位；

4. 时钟约束：在 02_xdc 中添加时序约束，保证时钟稳定性；

5. 跨时钟域：严格区分时钟域，禁止跨域直接握手。

----

## FIFO 使用规范

### 命名规则

- 同步 FIFO：`fifo_sync_深度x位宽` → fifo_sync_64x64

- 异步 FIFO：`fifo_async_深度x位宽` → fifo_async_1024x32

### 类型选择

1. 深度≥512：**Block RAM** 类型；

2. 深度＜512：**Distributed RAM** 类型；

3. 接口模式：**Native Ports → First Word Fall Through**；

4. 复位类型：**异步复位**。

### 信号与操作

1. 必须使用`almost_full`/`almost_empty`信号；

2. 读 FIFO 标准逻辑：判空→使能→读数据；

3. 异步 FIFO：严格区分 wr_clk/rd_clk，跨域必须同步。

----

## 7. BRAM 使用规范

### 7.1 命名规则

- 单口 BRAM：`bram_sp_深度x位宽` → bram_sp_1024x16

- 双口 BRAM：`bram_dp_深度x位宽` → bram_dp_1024x16

### 7.2 参数配置

1. 内存类型：True Dual Port RAM（双口）；

2. 操作模式：Write First；

3. 输出寄存器：使能，提升时序；

4. 复位：输出复位值 0x00，优先级 CE＞RST。

----

## 8. DSP 使用规范

1. 命名规则：`mult_符号位宽x符号位宽`；
	- 有符号：mult_s16xs16
	- 无符号：mult_u16xu16

2. 流水线：添加寄存器级，提升最高工作频率；

3. 控制信号：同步清零、时钟使能，规范时序。

----

## 9. 跨时钟域处理规范

1. 数据跨域：**专用 data_cross 模块**（异步 FIFO）；

2. 复位跨域：**专用 reset_cross 模块**；

3. 控制信号跨域：多拍同步（≥3 拍）；

4. 禁止直接跨域赋值、禁止跨域组合逻辑；

5. 跨域握手：vld/rdy 信号必须同步后再交互。

----

## 10. 常见 Warning 处理规范

### 10.1 最高优先级：[Synth 8-327] inferring latch

- 风险：上板时序与仿真不一致，状态机死机；

- 原因：if-else 不全、case 无 default、状态机自赋值；

- 解决：补全所有分支、添加 default、修正状态跳转。

### 10.2 其他常见 Warning

1. 端口未连接：检查信号映射，删除无用端口；

2. 时钟周期不匹配：修正 XDC 约束，统一时钟定义；

3. 时序违规：优化逻辑、添加寄存器、调整时序约束。

----

## 11. 附录：项目专属代码 / 注释模板

### 11.1 标准模块头注释模板

verilog

```
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 202X/XX/XX XX:XX:XX
// Design Name: 
// Module Name: 
// Project Name: 
// Target Devices: 
// Tool Versions: Vivado2020.2
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//////////////////////////////////////////////////////////////////////////////////
```

### 11.2 端口定义模板

verilog

```
input               clk             ,   // 主时钟100MHz
input               rst_n           ,   // 同步复位，低有效
input   [15:0]      din             ,   // 数据输入
input               din_vld         ,   // 输入有效
output  reg [15:0]  dout            ,   // 数据输出
output  reg         dout_vld            // 输出有效
```

### 11.3 时序逻辑模板（带复位）

verilog


```
always@(posedge clk)begin
    if(rst_n == 1'b0)begin
        cnt <= 4'd0;
    end
    else if(cnt < 4'd15)begin
        cnt <= cnt + 1'b1;
    end
    else;
end
```


### 11.4 三段式状态机模板


verilog


```
localparam  STP_idle    = 4'd0;
localparam  STP_READ     = 4'd1;
localparam  STP_WRITE    = 4'd2;

reg [3:0]   curr_state;
reg [3:0]   next_state;

// 第一段：现态
always@(posedge clk)begin
    if(rst_n == 1'b0)begin
        curr_state <= STP_idle;
    end
    else begin
        curr_state <= next_state;
    end
end

// 第二段：次态（仅跳转）
always@(*)begin
    case(curr_state)
        STP_idle: next_state = STP_READ;
        STP_READ: next_state = STP_WRITE;
        STP_WRITE: next_state = STP_idle;
        default: next_state = STP_idle;
    endcase
end

// 第三段：输出
always@(posedge clk)begin
    if(rst_n == 1'b0)begin
        dout <= 16'd0;
    end
    else begin
        case(curr_state)
            STP_idle: dout <= 16'd0;
            STP_READ: dout <= 16'h1234;
            STP_WRITE: dout <= 16'h5678;
            default: dout <= 16'd0;
        endcase
    end
end
```


### 11.5 模块例化模板


verilog


```
module_name u0_module_name(
    .clk        ( clk        ),
    .rst_n      ( rst_n      ),
    .din        ( din        ),
    .din_vld    ( din_vld    ),
    .dout       ( dout       ),
    .dout_vld   ( dout_vld   )
);
```


### 11.6 跨时钟域处理模板


verilog


```
data_cross#(
    .DATA_WIDTH     ( 16        ),
    .DEFAULT_VALUE  ( 16'h0000  )
)u_data_cross(
    .clk_i      ( clk_i      ),
    .clk_o      ( clk_o      ),
    .din        ( din        ),
    .din_vld    ( din_vld    ),
    .dout       ( dout       ),
    .dout_vld   ( dout_vld   )
);
```
