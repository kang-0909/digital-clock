module clock(input clk_pre,
			input TU, TL, TC, TD,
			input T1, T2, T3, T4, T15, T16,
						 output logic [10:0] disp_7seg,
						 output logic mode1, mode2, mode3, mode4,
						 output logic alarm_light, down_light);

logic [3:0] disp_A0, disp_A1, disp_B0, disp_B1;
logic [3:0] h0 = 4'b0000, h1 = 4'b0000, m0 = 4'b0000, m1 = 4'b0000, s0 = 4'b0000, s1 = 4'b0000; // 时钟
logic [3:0] ah0 = 4'b0000, ah1 = 4'b0000, am0 = 4'b0000, am1 = 4'b0000, as0 = 4'b0000, as1 = 4'b0000; // 闹钟
logic [3:0] dh0 = 4'b0000, dh1 = 4'b0000, dm0 = 4'b0000, dm1 = 4'b0000, ds0 = 4'b0000, ds1 = 4'b0000; // 倒计时
logic [3:0] ch0 = 4'b0000, ch1 = 4'b0000, cm0 = 4'b0000, cm1 = 4'b0000, cs0 = 4'b0000, cs1 = 4'b0000; // 秒表
logic [3:0] yy3 = 4'b0010, yy2 = 4'b0000, yy1 = 4'b0010, yy0 = 4'b0010, mm1 = 4'b0000, mm0 = 4'b0001, dd1 = 4'b0000, dd0 = 4'b0111; // 日期

//--------------------------------------------------
typedef enum integer {MAIN, ALARM, COUNT, DOWN, DATE} ModeType;
typedef enum logic {LOW, HIGH} DispType;
typedef enum logic {OFF, ON} HandType;
ModeType mode = MAIN;
DispType DISP = LOW;
logic hand = OFF;
integer alarm_time = 0, down_time = 0;
logic [7:0] ksj;
logic down_sig = 1'b1, alarm_sig = 1'b1, counting = 1'b0;

//-------------------- control ----------------------
//-------------- 控制模块，译码输入信号 ---------------

logic tmpU1, tmpU2, tmpU3, UP;
logic tmpL1, tmpL2, tmpL3, LEFT;
logic tmpC1, tmpC2, tmpC3, CENTER;
logic tmpD1, tmpD2, tmpD3, RESET;
// 消除 buttton 抖动
always_ff @ (posedge clk_centi) begin 
	tmpU3 <= tmpU2;
	tmpU2 <= tmpU1;
	tmpU1 <= TU;

	tmpL3 <= tmpL2;
	tmpL2 <= tmpL1;
	tmpL1 <= TL;

	tmpC3 <= tmpC2;
	tmpC2 <= tmpC1;
	tmpC1 <= TC;

	tmpD3 <= tmpD2;
	tmpD2 <= tmpD1;
	tmpD1 <= TD;
end

// 译码，得到当前模式等信息
always_comb begin
	if (T16) hand = ON;
	else hand = OFF;
	
	if (T1) begin mode = ALARM; {mode1, mode2, mode3, mode4} = 4'b1000; end
	else if (T2) begin mode = COUNT; {mode1, mode2, mode3, mode4} = 4'b0100; end
	else if (T3) begin mode = DOWN; {mode1, mode2, mode3, mode4} = 4'b0010; end
	else if (T4) begin mode = DATE; {mode1, mode2, mode3, mode4} = 4'b0001; end
	else begin  mode = MAIN; {mode1, mode2, mode3, mode4} = 4'b0000; end

	if (T15) DISP = HIGH;
	else DISP = LOW;

	UP = tmpU1 & tmpU2 & tmpU3;
	LEFT = tmpL1 & tmpL2 & tmpL3;
	CENTER = tmpC1 & tmpC2 & tmpC3;
	RESET = tmpD1 & tmpD2 & tmpD3;
end

//--------------------- main -----------------------
//---------主逻辑，处理时钟/秒表的自增以及时间设定-------

integer cnt_sec = 0, cnt_centi = 0, cnt_disp = 0, cnt_flip = 0;
logic clk_sec = 1'b0, clk_centi = 1'b0, clk_disp = 1'b0;
logic flip = 1'b1;
logic jw_d = 1'b0, jw_m = 1'b0, jw_y = 1'b0;
logic prehand = 1'b0, preleft = 1'b0, preup = 1'b0, predown_sig = 1'b0, prealarm_sig = 1'b0, precenter, prereset;

always_ff @ (posedge clk_pre) begin
	cnt_sec <= cnt_sec + 1;
	cnt_centi <= cnt_centi + 1;
	cnt_disp <= cnt_disp + 1;
	cnt_flip <= cnt_flip + 1;
	prehand <= hand;
	preleft <= LEFT;
	preup <= UP;
	precenter <= CENTER;
	prereset <= RESET;
	if (!prehand && hand || !preleft && LEFT) begin
		cnt_flip <= 0;
		flip <= 1'b1;
	end
	else if (cnt_flip == 50000000) begin
		cnt_flip <= 0;
		flip = 1'b1 ^ flip;
	end
	if (cnt_sec == 100000000) begin
		cnt_sec <= 0;
		clk_sec <= 1'b1;
	end
	else clk_sec <= 1'b0;

	if (cnt_centi == 1000000) begin
		cnt_centi <= 0;
		clk_centi <= 1'b1;
	end
	else clk_centi <= 1'b0;
	
	if (cnt_disp == 100000) begin
		cnt_disp <= 0;
		clk_disp <= 1'b1;
	end
	else clk_disp <= 1'b0;


	// 下面这段是日期自增
	if (jw_d) begin
		if (dd0 == 9) begin dd0 <= 0; dd1 <= dd1 + 1; end
		else if ({dd1, dd0} == ksj) begin dd0 <= 1; dd1 <= 0; jw_m <= 1'b1; end
		else dd0 <= dd0 + 1;
		jw_d <= 1'b0;
	end
	if (jw_m) begin
		if (mm0 == 9) begin mm0 <= 0; mm1 <= mm1 + 1; end
		else if ({mm1, mm0} == {4'd1, 4'd2}) begin mm0 <= 1; mm1 <= 0; jw_y <= 1'b1; end
		else mm0 <= mm0 + 1;
		jw_m <= 1'b0;
	end
	if (jw_y) begin
		if (yy0 == 9) begin
			if (yy1 == 9) begin
				if (yy2 == 9) begin
					if (yy3 == 9) begin
						yy3 <= 0;
					end
					else yy3 <= yy3 + 1;
					yy2 <= 0;
				end
				else yy2 <= yy2 + 1;
				yy1 <= 0;
			end	
			else yy1 <= yy1 + 1;
			yy0 <= 0;
		end
		else yy0 <= yy0 + 1;
		jw_y <= 1'b0;
	end

	// 秒表
	if (clk_centi) begin
		if (!(mode == COUNT && hand) && counting) begin
			if (cs0 == 9) begin
				if (cs1 == 9) begin
					if (cm0 == 9) begin
						if (cm1 == 5) begin
							if (ch0 == 9) begin
								if (ch1 == 5) begin
									{cs0, cs1, cm0, cm1, ch0, ch1} = 24'd0;
								end
								else ch1 <= ch1 + 1;
								ch0 <= 0;
							end
							else ch0 <= ch0 + 1;
							cm1 <= 0;
						end
						else cm1 <= cm1 + 1;
						cm0 <= 0;
					end
					else cm0 <= cm0 + 1;
					cs1 <= 0;
				end
				else cs1 <= cs1 + 1;
				cs0 <= 0;
			end
			else cs0 <= cs0 + 1;
		end
	end

	if (clk_sec) begin
		if (alarm_time != 0) alarm_time <= alarm_time - 1;
		if (down_time != 0) down_time <= down_time - 1;
		// 主时钟自增
		if (!(mode == MAIN && hand)) begin
			if (s0 == 9) begin
				if (s1 == 5) begin
					if (m0 == 9) begin
						if (m1 == 5) begin
							if (h0 == 3 && h1 == 2) begin 
								{s0, s1, m0, m1, h0, h1} <= 24'd0;
								jw_d <= 1'b1;
							end
							else if (h0 == 9) begin
								h0 <= 4'd0;
								h1 <= h1 + 1;
							end
							else h0 <= h0 + 1;
							m1 <= 0;
						end
						else m1 <= m1 + 1;
						m0 <= 0;
					end
					else m0 <= m0 + 1;
					s1 <= 0;
				end
				else s1 <= s1 + 1;
				s0 <= 0;
			end
			else s0 <= s0 + 1;
		end
		// 倒计时自减
		if (!(mode == DOWN && hand)) begin 
			if (!(ds0 == 0 && ds1 == 0 && dm0 == 0 && dm1 == 0 && dh0 == 0 && dh1 == 0)) begin
				if (ds0 == 0) begin
					if (ds1 == 0) begin
						if (dm0 == 0) begin
							if (dm1 == 0) begin
								if (dh0 == 0) begin
									dh1 <= dh1 - 1;
								end
								else dh0 <= dh0 - 1;
								dm1 <= 9;
							end
							else dm1 <= dm1 - 1;
							dm0 <= 9;
						end
						else dm0 <= dm0 - 1;
						ds1 <= 9;
					end
					else ds1 <= ds1 - 1;
					ds0 <= 9;
				end
				else ds0 <= ds0 - 1;
			end
		end
	end

	// 动态显示模块，对显示位置循环
	if (clk_disp) begin 
		case (disp_pos)
			0: disp_pos <= 1;
			1: disp_pos <= 2;
			2: disp_pos <= 3;
			3: disp_pos <= 0;
		endcase
	end

	//-------------------- set ---------------------------
	//-------------------设时模块 -------------------------
	if (!preup && UP) begin
		if (mode == MAIN && hand) begin //set clock
			if (DISP == LOW) begin
				case (set_pos)
					0: begin if (s0 == 9) s0 <= 0; else s0 <= s0 + 1; end
					1: begin if (s1 == 5) s1 <= 0; else s1 <= s1 + 1; end
					2: begin if (m0 == 9) m0 <= 0; else m0 <= m0 + 1; end
					3: begin if (m1 == 5) m1 <= 0; else m1 <= m1 + 1; end
				endcase
			end
			else begin
				case (set_pos)
					0: begin if (m0 == 9) m0 <= 0; else m0 <= m0 + 1; end
					1: begin if (m1 == 9) m1 <= 0; else m1 <= m1 + 1; end
					2: begin if (h0 == 9 || h0 == 3 && h1 == 2) h0 <= 0; else h0 <= h0 + 1; end
					3: begin if (h1 == 2) h1 <= 0; else h1 <= h1 + 1; end
				endcase
			end
		end
		if (mode == ALARM && hand) begin //set alarm
			if (DISP == LOW) begin
				case (set_pos)
					0: begin if (as0 == 9) as0 <= 0; else as0 <= as0 + 1; end
					1: begin if (as1 == 5) as1 <= 0; else as1 <= as1 + 1; end
					2: begin if (am0 == 9) am0 <= 0; else am0 <= am0 + 1; end
					3: begin if (am1 == 5) am1 <= 0; else am1 <= am1 + 1; end
				endcase
			end
			else begin
				case (set_pos)
					0: begin if (am0 == 9) am0 <= 0; else am0 <= am0 + 1; end
					1: begin if (am1 == 9) am1 <= 0; else am1 <= am1 + 1; end
					2: begin if (ah0 == 9 || ah0 == 3 && ah1 == 2) ah0 <= 0; else ah0 <= ah0 + 1; end
					3: begin if (ah1 == 2) ah1 <= 0; else ah1 <= ah1 + 1; end
				endcase
			end
		end
		if (mode == DOWN && hand) begin // set count_down
			if (DISP == LOW) begin
				case (set_pos)
					0: begin if (ds0 == 9) ds0 <= 0; else ds0 <= ds0 + 1; end
					1: begin if (ds1 == 5) ds1 <= 0; else ds1 <= ds1 + 1; end
					2: begin if (dm0 == 9) dm0 <= 0; else dm0 <= dm0 + 1; end
					3: begin if (dm1 == 5) dm1 <= 0; else dm1 <= dm1 + 1; end
				endcase
			end
			else begin
				case (set_pos)
					0: begin if (dm0 == 9) dm0 <= 0; else dm0 <= dm0 + 1; end
					1: begin if (dm1 == 9) dm1 <= 0; else dm1 <= dm1 + 1; end
					2: begin if (dh0 == 9 || dh0 == 3 && dh1 == 2) dh0 <= 0; else dh0 <= dh0 + 1; end
					3: begin if (dh1 == 2) dh1 <= 0; else dh1 <= dh1 + 1; end
				endcase
			end
		end
		if (mode == DATE && hand) begin // set date
			if (DISP == LOW) begin
				case (set_pos)
					0: begin if (dd0 == 9) dd0 <= 0; else dd0 <= dd0 + 1; end
					1: begin if (dd1 == 3) dd1 <= 0; else dd1 <= dd1 + 1; end
					2: begin if (mm0 == 9) mm0 <= 0; else mm0 <= mm0 + 1; end
					3: begin if (mm1 == 1) mm1 <= 0; else mm1 <= mm1 + 1; end
				endcase
			end
			else begin
				case (set_pos)
					0: begin if (yy0 == 9) yy0 <= 0; else yy0 <= yy0 + 1; end
					1: begin if (yy1 == 9) yy1 <= 0; else yy1 <= yy1 + 1; end
					2: begin if (yy2 == 9) yy2 <= 0; else yy2 <= yy2 + 1; end
					3: begin if (yy3 == 9) yy3 <= 0; else yy3 <= yy3 + 1; end
				endcase
			end
		end
	end

	// reset
	if (!prereset && RESET) begin
		case (mode) 
			COUNT: {cs0, cs1, cm0, cm1, ch0, ch1} <= 24'd0;
			MAIN: {s0, s1, m0, m1, h0, h1} <= 24'd0;
			ALARM: {as0, as1, am0, am1, ah0, ah1} <= 24'd0;
			DOWN: {ds0, ds1, dm0, dm1, dh0, dh1} <= 24'd0;
		endcase
	end

	// 开始/停止计时
	if (!precenter && CENTER) begin
		if (mode == COUNT) begin
			counting <= 1'b1 ^ counting;
		end
	end

	// 计时器归零，亮 5s
	if (ds0 == 0 && ds1 == 0 && dm0 == 0 && dm1 == 0 && dh0 == 0 && dh1 == 0) begin
		down_sig <= 1'b1;
		if (!down_sig) down_time <= 5;
	end
	else down_sig <= 1'b0;

	// 闹钟响，亮 5s
	if (s0 == as0 && s1 == as1 && m0 == am0 && m1 == am1 && h0 == ah0 && h1 == ah1) begin
		alarm_sig <= 1'b1;
		if (!alarm_sig) alarm_time <= 5;
	end
	else alarm_sig <= 1'b0;
end


always_comb begin // 判断月份天数的组合逻辑（不考虑闰年）
	case ({mm1, mm0}) 
		{4'd0, 4'd1}: ksj = {4'd3, 4'd1};
		{4'd0, 4'd2}: ksj = {4'd2, 4'd8};
		{4'd0, 4'd3}: ksj = {4'd3, 4'd1};
		{4'd0, 4'd4}: ksj = {4'd3, 4'd0};
		{4'd0, 4'd5}: ksj = {4'd3, 4'd1};
		{4'd0, 4'd6}: ksj = {4'd3, 4'd0};
		{4'd0, 4'd7}: ksj = {4'd3, 4'd1};
		{4'd0, 4'd8}: ksj = {4'd3, 4'd1};
		{4'd0, 4'd9}: ksj = {4'd3, 4'd0};
		{4'd1, 4'd0}: ksj = {4'd3, 4'd1};
		{4'd1, 4'd1}: ksj = {4'd3, 4'd0};
		{4'd1, 4'd2}: ksj = {4'd3, 4'd1};
	endcase
end

// 设置 hand 模式下的修改位置
integer set_pos = 0;
always_ff @ (posedge LEFT) begin
	if (hand == ON) begin
		if (set_pos == 3) set_pos <= 0;
		else set_pos <= set_pos + 1;
	end
end

//------------------- display --------------------------
//------------------- 显示模块 --------------------------

// 根据当前模式选择相应显示内容
always_comb begin 
	case (mode)
		MAIN:
			if (DISP == LOW) begin disp_A0 = m0; disp_A1 = m1; disp_B0 = s0; disp_B1 = s1; end
			else begin disp_A0 = h0; disp_A1 = h1; disp_B0 = m0; disp_B1 = m1; end
		ALARM: 
			if (DISP == LOW) begin disp_A0 = am0; disp_A1 = am1; disp_B0 = as0; disp_B1 = as1; end
			else begin disp_A0 = ah0; disp_A1 = ah1; disp_B0 = am0; disp_B1 = am1; end
		COUNT:
			if (DISP == LOW) begin disp_A0 = cm0; disp_A1 = cm1; disp_B0 = cs0; disp_B1 = cs1; end
			else begin disp_A0 = ch0; disp_A1 = ch1; disp_B0 = cm0; disp_B1 = cm1; end
		DOWN:
			if (DISP == LOW) begin disp_A0 = dm0; disp_A1 = dm1; disp_B0 = ds0; disp_B1 = ds1; end
			else begin disp_A0 = dh0; disp_A1 = dh1; disp_B0 = dm0; disp_B1 = dm1; end
		DATE:
			if (DISP == LOW) begin disp_A0 = mm0; disp_A1 = mm1; disp_B0 = dd0; disp_B1 = dd1; end
			else begin disp_A0 = yy2; disp_A1 = yy3; disp_B0 = yy0; disp_B1 = yy1; end
	endcase
end

// 根据 disp_pos 显示一个数
integer disp_pos = 0;
logic [3:0] disp_number;
always_comb begin 
	case (disp_pos)
		0: begin disp_7seg[10:7] = 4'b1110; disp_number = disp_B0; end
		1: begin disp_7seg[10:7] = 4'b1101; disp_number = disp_B1; end
		2: begin disp_7seg[10:7] = 4'b1011; disp_number = disp_A0; end
		3: begin disp_7seg[10:7] = 4'b0111; disp_number = disp_A1; end
		default: begin disp_7seg[10:7] = 4'b0000; disp_number = 0; end
	endcase
	if (hand && disp_pos == set_pos && flip) begin
		disp_7seg[6:0] = 7'b1111111;
	end
	else begin
		case (disp_number)
			4'd0: disp_7seg[6:0] = 7'b0000001;
			4'd1: disp_7seg[6:0] = 7'b1001111;
			4'd2: disp_7seg[6:0] = 7'b0010010;
			4'd3: disp_7seg[6:0] = 7'b0000110;
			4'd4: disp_7seg[6:0] = 7'b1001100;
			4'd5: disp_7seg[6:0] = 7'b0100100;
			4'd6: disp_7seg[6:0] = 7'b0100000;
			4'd7: disp_7seg[6:0] = 7'b0001111;
			4'd8: disp_7seg[6:0] = 7'b0000000;
			4'd9: disp_7seg[6:0] = 7'b0000100;
			default: disp_7seg[6:0] = 7'b1111111;
		endcase
	end
end

// 控制闹钟和定时器的灯
always_comb begin
	if (alarm_time != 0) alarm_light = 1'b1;
	else alarm_light = 1'b0;

	if (down_time == 0) down_light = 1'b0;
	else down_light = 1'b1;
end

endmodule