`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/22/2024 10:52:32 PM
// Design Name: 
// Module Name: axis_max5316
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module axis_max5316#(
    // Parameters of Axi Slave Bus Interface IN_AXIS
    parameter integer C_AXIS_TDATA_WIDTH	= 16
)
(
    input clk,            // System clock
    input resetn,            // Reset signal

    // AXIS Interface
    input [C_AXIS_TDATA_WIDTH-1:0] tdata,   // Data to be sent to the DAC
    input tvalid,         // Data valid signal
    input tlast,             // TLAST signal from slave
    input [(C_AXIS_TDATA_WIDTH/8)-1:0] tkeep,       // TKEEP signal from slave
    output reg tready,    // Data ready signal
    
    output reg SCLK_DAC,  // SPI clock
    output reg DIN_DAC,   // Master Out Slave In (MOSI)
    output reg CS_DAC,    // Chip Select
    output reg LDAC,      // Load DAC
    input BUSY_DAC       // Busy signal from DAC
);

    reg [4:0] bit_cnt;
    reg [23:0] data_buf;
    reg [2:0] state;
    reg [15:0] count;

    // State machine states
    localparam IDLE   = 3'd0,
               LOAD   = 3'd1,
               TRANS  = 3'd2,
               DONE   = 3'd3;
    
    // Register to store control data
    localparam control = 4'b0001;
    // Initialize state and outputs
    initial begin
        state = IDLE;
        SCLK_DAC = 0;
        DIN_DAC = 0;
        CS_DAC = 1;
        LDAC = 1;
        tready = 0;
        count = 0;
    end

    // SPI clock generation
    always @(posedge clk) begin
        if (!resetn) begin
            SCLK_DAC <= 0;
        end else begin
            count <= count + 1;
            if (count == 10) begin
                count <= 0;
                SCLK_DAC <= ~SCLK_DAC;
            end
        end
    end

    // State machine and data transmission
    always @(posedge SCLK_DAC) begin
        if (!resetn) begin
            state <= IDLE;
            CS_DAC <= 1;
            bit_cnt <= 0;
            DIN_DAC <= 0;
            LDAC <= 1;
            tready <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tready <= 1;
                    if (tvalid) begin
                        tready <= 0;
                        state <= LOAD;
                        LDAC <= 1; // Keep LDAC high during communication
                    end
                end
                LOAD: begin
                    data_buf[23:20] <= control;
                    data_buf[19:4] <= tdata;
                    data_buf[3:0] <= 4'b0101; // 20-bit data plus 4 unused bits
                    bit_cnt <= 23;
                    state <= TRANS;
                end
                TRANS: begin
                    CS_DAC <= 0;
                    DIN_DAC <= data_buf[bit_cnt];
                    bit_cnt <= bit_cnt - 1;
                    if (bit_cnt == 0) begin
                        state <= DONE;
                    end
                end
                DONE: begin
                    CS_DAC <= 1;
                    LDAC <= 0; // Pulse LDAC to latch data into the DAC
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
