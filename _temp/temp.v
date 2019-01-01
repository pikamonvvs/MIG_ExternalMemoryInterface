// `define SKIP_CALIB

`timescale 1ps/1ps

module top # (
	parameter DQ_WIDTH = 16, // # of DQ(data)
	parameter ECC_TEST = "OFF",
	parameter nBANK_MACHS = 4,
	parameter ADDR_WIDTH = 28, // # = RANK_WIDTH + BANK_WIDTH + ROW_WIDTH + COL_WIDTH
	parameter nCK_PER_CLK = 4 // # of memory CKs per fabric CLK

	)	(
	// Inouts
	inout [15:0] ddr3_dq,
	inout [1:0] ddr3_dqs_n,
	inout [1:0] ddr3_dqs_p,

	// Outputs
	output [13:0] ddr3_addr,
	output [2:0] ddr3_ba,
	output ddr3_ras_n,
	output ddr3_cas_n,
	output ddr3_we_n,
	output ddr3_reset_n,
	output [0:0] ddr3_ck_p,
	output [0:0] ddr3_ck_n,
	output [0:0] ddr3_cke,
	output [0:0] ddr3_cs_n,
	output [1:0] ddr3_dm,
	output [0:0] ddr3_odt,
	
	// Inputs
	input sys_clk_i,
	input clk_ref_i,
	input sys_rst
	);
	
	localparam DATA_WIDTH = 16;
	localparam PAYLOAD_WIDTH = (ECC_TEST == "OFF") ? DATA_WIDTH : DQ_WIDTH;
	localparam APP_DATA_WIDTH = 2 * nCK_PER_CLK * PAYLOAD_WIDTH;
	localparam APP_MASK_WIDTH = APP_DATA_WIDTH / 8;

	wire clk;
	wire rst;

	wire [ADDR_WIDTH-1:0] app_addr;
	wire [2:0] app_cmd;
	wire app_en;
	wire [APP_DATA_WIDTH-1:0] app_wdf_data;
	wire app_wdf_end;
	wire app_wdf_wren;
	wire [APP_DATA_WIDTH-1:0] app_rd_data;
	wire app_rd_data_end;
	wire app_rd_data_valid;
	wire app_rdy;
	wire app_wdf_rdy;
	wire app_sr_active;
	wire app_ref_ack;
	wire app_zq_ack;
	wire [APP_MASK_WIDTH-1:0] app_wdf_mask;

	wire [11:0] device_temp;

	assign clk_ref_i = 0; // temp
	assign device_temp = 0; // temp

`ifdef SKIP_CALIB
	// skip calibration wires
	wire calib_tap_req;
	reg calib_tap_load;
	reg [6:0] calib_tap_addr;
	reg [7:0] calib_tap_val;
	reg calib_tap_load_done;
`endif

	ExternalMemory _ExternalMemory
	(
		// Memory interface ports
		.ddr3_dq(ddr3_dq),
		.ddr3_dqs_n(ddr3_dqs_n),
		.ddr3_dqs_p(ddr3_dqs_p),

		.ddr3_addr(ddr3_addr),
		.ddr3_ba(ddr3_ba),
		.ddr3_ras_n(ddr3_ras_n),
		.ddr3_cas_n(ddr3_cas_n),
		.ddr3_we_n(ddr3_we_n),
		.ddr3_reset_n(ddr3_reset_n),
		.ddr3_ck_p(ddr3_ck_p),
		.ddr3_ck_n(ddr3_ck_n),
		.ddr3_cke(ddr3_cke),
		.ddr3_cs_n(ddr3_cs_n),
		.ddr3_dm(ddr3_dm),
		.ddr3_odt(ddr3_odt),

		.init_calib_complete(init_calib_complete),

		// Application interface ports
		.app_addr(app_addr),
		.app_cmd(app_cmd),
		.app_en(app_en),
		.app_wdf_data(app_wdf_data),
		.app_wdf_end(app_wdf_end),
		.app_wdf_wren(app_wdf_wren),
		.app_rd_data(app_rd_data),
		.app_rd_data_end(app_rd_data_end),
		.app_rd_data_valid(app_rd_data_valid),
		.app_rdy(app_rdy),
		.app_wdf_rdy(app_wdf_rdy),
		.app_sr_req(1'b0),
		.app_ref_req(1'b0),
		.app_zq_req(1'b0),
		.app_sr_active(app_sr_active),
		.app_ref_ack(app_ref_ack),
		.app_zq_ack(app_zq_ack),
		.ui_clk(clk),
		.ui_clk_sync_rst(rst),
		.app_wdf_mask(app_wdf_mask),

		// System Clock Ports
		.sys_clk_i(sys_clk_i),

		// Reference Clock Ports
		.clk_ref_i(clk_ref_i),
		.device_temp(device_temp),
`ifdef SKIP_CALIB
		.calib_tap_req(calib_tap_req),
		.calib_tap_load(calib_tap_load),
		.calib_tap_addr(calib_tap_addr),
		.calib_tap_val(calib_tap_val),
		.calib_tap_load_done(calib_tap_load_done),
`endif

		.sys_rst(sys_rst)
	);
endmodule

module ExternalMemory (

	// Inouts
	inout [15:0] ddr3_dq,
	inout [1:0] ddr3_dqs_n,
	inout [1:0] ddr3_dqs_p,
	
	// Outputs
	output [13:0] ddr3_addr,
	output [2:0] ddr3_ba,
	output ddr3_ras_n,
	output ddr3_cas_n,
	output ddr3_we_n,
	output ddr3_reset_n,
	output [0:0] ddr3_ck_p,
	output [0:0] ddr3_ck_n,
	output [0:0] ddr3_cke,
	output [0:0] ddr3_cs_n,
	output [1:0] ddr3_dm,
	output [0:0] ddr3_odt,
	
	// Inputs
	input sys_clk_i, // Single-ended system clock
	input clk_ref_i, // Single-ended iodelayctrl clk (reference clock)
	input sys_rst,

	// User Interface Inputs and Outputs
	input [27:0] app_addr, ////
	input [2:0] app_cmd, ////
	input app_en,
	input [127:0] app_wdf_data,
	input app_wdf_end,
	input [15:0] app_wdf_mask,
	input app_wdf_wren,
	input app_sr_req,
	input app_ref_req,
	input app_zq_req,

	output [127:0] app_rd_data,
	output app_rd_data_end,
	output app_rd_data_valid,
	output app_rdy,
	output app_wdf_rdy,
	output app_sr_active,
	output app_ref_ack,
	output app_zq_ack,
	output ui_clk,
	output ui_clk_sync_rst,
	output init_calib_complete,
	output [11:0] device_temp // 40
	
`ifdef SKIP_CALIB // Calibration
	,
	input calib_tap_load,
	input calib_tap_addr,
	input calib_tap_val,
	input calib_tap_load_done,
	output calib_tap_req //45
`endif

	);

	// dummy

endmodule

