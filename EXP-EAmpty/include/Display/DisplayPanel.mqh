#ifndef __EA_OCO_DISPLAY_PANEL_MQH__
#define __EA_OCO_DISPLAY_PANEL_MQH__

#include "../EAData/EAAccess.mqh"
#include "../Monitoring/IndicatorSnapshot.mqh"

void UpdateChartStatus()
{
   if(!m_cfg.ShowChartStatus) return;
   string btick_file = m_btick_path + ".mq5";
   string atr_file = m_atrtrail_path + ".mq5";
   string ph_file = m_phase_path + ".mq5";
   string zz_file = m_pricezz_path + ".mq5";
   string s1 = StringFormat("ATR carregado no arquivo \"%s\": %s", atr_file, m_atr_loaded ? "OK" : "FAIL");
   string s2 = StringFormat("BTick carregado no arquivo \"%s\": %s", btick_file, m_btick_loaded ? "OK" : "FAIL");
   string s3 = StringFormat("PhaseClock carregado no arquivo \"%s\": %s", ph_file, m_phase_loaded ? "OK" : "FAIL");
   string s4 = StringFormat("ZigZag carregado no arquivo \"%s\": %s", zz_file, m_pricezz_loaded ? "OK" : "FAIL");
   string s6 = "Cruzamento BUY: -";
   if(m_last_cross_dir == 1)
   {
      string t_cross = TimeToString(m_last_cross_time, TIME_SECONDS);
      string t_bar = TimeToString(m_last_cross_bar, TIME_DATE|TIME_MINUTES);
      string t_now = TimeToString(TimeCurrent(), TIME_SECONDS);
      s6 = StringFormat("Cruzamento BUY às %s, na barra %s, agora %s", t_cross, t_bar, t_now);
   }
   string s7 = m_sig.DebugText();
   Comment(s1 + "\n" + s2 + "\n" + s3 + "\n" + s4 + "\n" + s6 + "\n" + s7);
}

string EntryPanelTextName(const int idx){ return "EAOCO_ENTRY_" + IntegerToString(idx); }
string EntryPanelBoxName(){ return "EAOCO_ENTRY_BOX"; }
string OrdersPanelBoxName(const int idx){ return "EAOCO_ORD_BOX_" + IntegerToString(idx); }
string OrdersPanelTextName(const int idx, const int line){ return "EAOCO_ORD_" + IntegerToString(idx) + "_" + IntegerToString(line); }
string ConfigPanelBoxName(const int idx){ return "EAOCO_CFG_BOX_" + IntegerToString(idx); }
string ConfigPanelTextName(const int idx, const int line){ return "EAOCO_CFG_" + IntegerToString(idx) + "_" + IntegerToString(line); }

double PanelPipSize()
{
   int d = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double p = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(d == 3 || d == 5) return p * 10.0;
   return p;
}

string StateText(const int state)
{
   if(state > 0) return "TRUE";
   if(state == 0) return "FALSE";
   return "AGUARDA";
}

color StateColor(const int state)
{
   if(state > 0) return clrLime;
   if(state == 0) return clrRed;
   return clrSilver;
}

void AddEntryLine(string &lines[], color &cols[], int &count, const string label, const int state, const string detail="")
{
   ArrayResize(lines, count + 1);
   ArrayResize(cols, count + 1);
   string txt = label + ": " + StateText(state);
   if(detail != "") txt += " (" + detail + ")";
   lines[count] = txt;
   cols[count] = StateColor(state);
   count++;
}

void AddEntryLineValue(string &lines[], color &cols[], int &count, const string label, const string value, const color col)
{
   ArrayResize(lines, count + 1);
   ArrayResize(cols, count + 1);
   lines[count] = label + ": " + value;
   cols[count] = col;
   count++;
}

void DeleteEntryPanel()
{
   for(int i=0; i<16; i++) ObjectDelete(0, EntryPanelTextName(i));
   ObjectDelete(0, EntryPanelBoxName());
}

#endif

void UpdateEntryPanel(const int dir,
                                     const int st_sig_ok,
                                     const int st_sig_shift,
                                     const int st_hold,
                                     const int st_phase_up,
                                     const int st_phase_down,
                                     const int st_phase_rule,
                                     const int st_zz_high,
                                     const int st_zz_low,
                                     const int st_zz_rule,
                                     const int st_adxw_rule,
                                     const int st_sig_unique,
                                     const int st_trading,
                                     const int st_sl)
{
   if(!m_cfg.ShowEntryPanel)
   {
      DeleteEntryPanel();
      UpdateOrdersPanel();
      UpdateConfigPanel();
      return;
   }

   Monitoring::SIndicatorSnapshot snap;
   Monitoring::GetIndicatorSnapshot(snap);

   string lines[];
   color cols[];
   int n = 0;

   if(m_cfg.PanelShowBTick)
   {
      AddEntryLine(lines, cols, n, "BTick signal ok", st_sig_ok);
      if(st_sig_shift >= 0)
         AddEntryLine(lines, cols, n, "Signal shift", 1, "bar" + IntegerToString(st_sig_shift));
   }

   if(m_cfg.BarZeroHold)
      AddEntryLine(lines, cols, n, "Bar0 >= 1/2 (autoriza)", st_hold);
   if(m_cfg.BarZeroHold && snap.sig_shift == 0 && m_btick_cross_time > 0 && m_btick_cross_bar == iTime(_Symbol, m_tf, 0))
   {
      int bar_sec = PeriodSeconds(m_tf);
      int half = (bar_sec > 0 ? (bar_sec / 2) : 0);
      int elapsed = (int)(TimeCurrent() - m_btick_cross_time);
      if(elapsed < 0) elapsed = 0;
      string v = IntegerToString(elapsed) + "/" + IntegerToString(half) + "s";
      color c = (half > 0 && elapsed >= half) ? clrLime : clrYellow;
      AddEntryLineValue(lines, cols, n, "BTick counter", v, c);
   }

   // valores brutos do BTick State (buffers 2/3)
   if(m_cfg.PanelShowBTick)
   {
      AddEntryLineValue(lines, cols, n, "BTick State Buy", DoubleToString(snap.btick_buy, 2), clrAqua);
      AddEntryLineValue(lines, cols, n, "BTick State Sell", DoubleToString(snap.btick_sell, 2), clrAqua);
   }

   if(m_cfg.UsePhaseRule && m_cfg.PanelShowPhase)
      AddEntryLine(lines, cols, n, "Rule PHASE", st_phase_rule);
   if(m_cfg.UseZigZagRule && m_cfg.PanelShowZigZag)
      AddEntryLine(lines, cols, n, "Rule ZIGZAG", st_zz_rule);
   if(m_cfg.UseADXWRule)
      AddEntryLine(lines, cols, n, "Rule ADXW", st_adxw_rule);

   AddEntryLine(lines, cols, n, "Sinal unico", st_sig_unique);
   AddEntryLine(lines, cols, n, "Trading allowed", st_trading);
   if(st_sl != -1)
      AddEntryLine(lines, cols, n, "SL/TP ok", st_sl);

   int x = m_cfg.EntryPanelX;
   int y = m_cfg.EntryPanelY;
   int fs = 9;
   int lh = 14;
   int pad = 6;
   int w = 240;
   int h = n * lh + pad * 2;
   color bg = (color)ColorToARGB(clrBlack, 160);
   SetBoxWin(EntryPanelBoxName(), 0, x - pad, y - pad, w, h, bg, clrDimGray);

   for(int i=0; i<n; i++)
      SetLabelWin(EntryPanelTextName(i), 0, x, y + i * lh, cols[i], fs, lines[i]);

   for(int i=n; i<16; i++)
      ObjectDelete(0, EntryPanelTextName(i));

   UpdateOrdersPanel();
   UpdateConfigPanel();
}

void UpdateEntryPanelFromSnapshot(const int st_trading, const int st_sl)
{
   Monitoring::SIndicatorSnapshot snap;
   Monitoring::GetIndicatorSnapshot(snap);
   UpdateEntryPanel(snap.dir, snap.sig_ok, snap.sig_shift, snap.hold,
                    snap.phase_up, snap.phase_down, snap.phase_rule,
                    snap.zz_high, snap.zz_low, snap.zz_rule,
                    snap.adxw_rule,
                    snap.sig_unique, st_trading, st_sl);
}

void DeleteOrdersPanel()
{
   int total = ObjectsTotal(0, 0, -1);
   for(int i=total-1; i>=0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, "EAOCO_ORD_") == 0 || StringFind(name, "EAOCO_ORD_BOX_") == 0)
         ObjectDelete(0, name);
   }
}

void DeleteConfigPanel()
{
   int total = ObjectsTotal(0, 0, -1);
   for(int i=total-1; i>=0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, "EAOCO_CFG_") == 0 || StringFind(name, "EAOCO_CFG_BOX_") == 0)
         ObjectDelete(0, name);
   }
}

void UpdateConfigPanel()
{
   if(!m_cfg.ShowConfigPanel)
   {
      DeleteConfigPanel();
      return;
   }

   int fs = 9;
   int lh = 14;
   int pad = 6;
   int box_lines = 5;
   int box_w = 220;
   int box_h = box_lines * lh + pad * 2;
   int gap = 18;
   int base_x = m_cfg.ConfigPanelX;
   int base_y = m_cfg.ConfigPanelY;
   color bg = (color)ColorToARGB(clrBlack, 160);

   int r_sl_points = (m_cfg.RunnerSLPoints >= 0 ? m_cfg.RunnerSLPoints : m_cfg.SLPoints);
   int r_sl_min = (m_cfg.RunnerSLMinPoints >= 0 ? m_cfg.RunnerSLMinPoints : m_cfg.SLMinPoints);
   int r_sl_max = (m_cfg.RunnerSLMaxPoints >= 0 ? m_cfg.RunnerSLMaxPoints : m_cfg.SLMaxPoints);
   string r_tp = (m_cfg.RunnerTPPoints >= 0 ? IntegerToString(m_cfg.RunnerTPPoints) + " pts" : "1:1");

   string main_lines[5];
   color main_cols[5];
   main_lines[0] = "MAIN (config)";
   main_lines[1] = "TP pts: " + IntegerToString(m_cfg.TPPoints);
   main_lines[2] = "SL pts: " + IntegerToString(m_cfg.SLPoints);
   main_lines[3] = "SL min/max: " + IntegerToString(m_cfg.SLMinPoints) + "/" + IntegerToString(m_cfg.SLMaxPoints);
   main_lines[4] = "Trailing ATR: " + string(m_cfg.UseTrailingATR ? "ON" : "OFF");
   main_cols[0] = clrLime;
   for(int i=1; i<5; i++) main_cols[i] = clrWhite;

   string run_lines[5];
   color run_cols[5];
   run_lines[0] = "RUNNER (config)";
   run_lines[1] = "TP: " + r_tp;
   run_lines[2] = "SL pts: " + IntegerToString(r_sl_points);
   run_lines[3] = "SL min/max: " + IntegerToString(r_sl_min) + "/" + IntegerToString(r_sl_max);
   run_lines[4] = "Trailing ATR: " + string(m_cfg.UseTrailingATR ? "ON" : "OFF");
   run_cols[0] = clrAqua;
   for(int i=1; i<5; i++) run_cols[i] = clrWhite;

   DeleteConfigPanel();

   SetBoxWin(ConfigPanelBoxName(0), 0, base_x - pad, base_y - pad, box_w, box_h, bg, clrDimGray);
   for(int l=0; l<box_lines; l++)
      SetLabelWin(ConfigPanelTextName(0, l), 0, base_x, base_y + l * lh, main_cols[l], fs, main_lines[l]);

   int x2 = base_x + box_w + gap;
   SetBoxWin(ConfigPanelBoxName(1), 0, x2 - pad, base_y - pad, box_w, box_h, bg, clrDimGray);
   for(int l=0; l<box_lines; l++)
      SetLabelWin(ConfigPanelTextName(1, l), 0, x2, base_y + l * lh, run_cols[l], fs, run_lines[l]);
}

void UpdateOrdersPanel()
{
   if(!m_cfg.ShowOrdersPanel)
   {
      DeleteOrdersPanel();
      return;
   }

   int total = PositionsTotal();
   ulong tickets[];
   ArrayResize(tickets, 0);
   for(int i=0; i<total; i++)
   {
      if(!m_pos.IsMine(i)) continue;
      ulong t = (ulong)PositionGetInteger(POSITION_TICKET);
      int n = ArraySize(tickets);
      ArrayResize(tickets, n + 1);
      tickets[n] = t;
   }

   DeleteOrdersPanel();

   int count = ArraySize(tickets);
   if(count <= 0) return;

   int cols = m_cfg.OrdersPanelColumns;
   if(cols < 1) cols = (count > 1 ? 2 : 1);
   if(cols > 4) cols = 4;
   int box_lines = 5;
   int fs = 9;
   int lh = 14;
   int pad = 6;
   int box_w = 220;
   int box_h = box_lines * lh + pad * 2;
   int col_gap = 18;
   int row_gap = 10;
   int base_x = m_cfg.OrdersPanelX;
   int base_y = m_cfg.OrdersPanelY;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double pip = PanelPipSize();
   if(pip <= 0.0) pip = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   for(int i=0; i<count; i++)
   {
      if(!PositionSelectByTicket(tickets[i])) continue;

      long type = PositionGetInteger(POSITION_TYPE);
      double vol = PositionGetDouble(POSITION_VOLUME);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      string cmt = PositionGetString(POSITION_COMMENT);
      ulong pos_id = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      string tag = GetPositionTag(pos_id, cmt);
      ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);

      string side = (type == POSITION_TYPE_BUY ? "BUY" : "SELL");
      color head_col = (type == POSITION_TYPE_BUY ? clrLime : clrTomato);

      string sl_txt = "--";
      string tp_txt = "--";
      if(sl > 0.0)
         sl_txt = DoubleToString(sl, digits) + " (" + DoubleToString(MathAbs(open - sl) / pip, 1) + "p)";
      if(tp > 0.0)
         tp_txt = DoubleToString(tp, digits) + " (" + DoubleToString(MathAbs(tp - open) / pip, 1) + "p)";

      string trail = "OFF";
      if(m_cfg.UseTrailingATR)
      {
         trail = "ATR";
      }
      if(tag == "RUNNER" && m_cfg.RunnerEnabled && !m_cfg.UseTrailingATR)
      {
         if(m_cfg.RunnerTrailStartPoints > 0) trail = "RUNNER+TRAIL";
         else trail = "RUNNER";
      }

      string lines[5];
      color cols_line[5];
      lines[0] = StringFormat("%s #%d %s", side, i + 1, (tag != "" ? "(" + tag + ")" : ""));
      lines[1] = StringFormat("Ticket: %I64u  Lots: %.2f", ticket, vol);
      lines[2] = "Open: " + DoubleToString(open, digits);
      lines[3] = "SL: " + sl_txt + "  TP: " + tp_txt;
      lines[4] = "Trail: " + trail;

      cols_line[0] = head_col;
      cols_line[1] = clrWhite;
      cols_line[2] = clrWhite;
      cols_line[3] = clrSilver;
      cols_line[4] = (trail == "OFF" ? clrSilver : clrAqua);

      int col = (cols > 1 ? (i % cols) : 0);
      int row = (cols > 1 ? (i / cols) : i);
      int x = base_x + col * (box_w + col_gap);
      int y = base_y + row * (box_h + row_gap);
      color bg = (color)ColorToARGB(clrBlack, 160);
      SetBoxWin(OrdersPanelBoxName(i), 0, x - pad, y - pad, box_w, box_h, bg, clrDimGray);

      for(int l=0; l<box_lines; l++)
         SetLabelWin(OrdersPanelTextName(i, l), 0, x, y + l * lh, cols_line[l], fs, lines[l]);
   }
}

string PriceStatsTextName(const int idx){ return "EAOCO_PSTATS_" + IntegerToString(idx); }
string PriceStatsBoxName(){ return "EAOCO_PSTATS_BOX"; }

void SetLabelWin(const string name, const int win, const int xdist, const int ydist, const color col, const int fsz, const string text)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, win, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, xdist);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, ydist);
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fsz);
   ObjectSetString (0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString (0, name, OBJPROP_TEXT, text);
}

void SetBoxWin(const string name, const int win, const int xdist, const int ydist, const int w, const int h, const color bg, const color border)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, win, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, xdist);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, ydist);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, border);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void DeletePriceStatsObjects()
{
   for(int i=0; i<4; i++) ObjectDelete(0, PriceStatsTextName(i));
   ObjectDelete(0, PriceStatsBoxName());
}

void UpdatePriceStats()
{
   if(!m_cfg.ShowPriceStats)
   {
      DeletePriceStatsObjects();
      return;
   }
   if(m_pricezz_attach_handle == INVALID_HANDLE)
   {
      DeletePriceStatsObjects();
      return;
   }

   datetime bar_time = iTime(_Symbol, m_tf, 0);
   if(bar_time <= 0) return;
   if(m_last_price_stats_bar == bar_time) return; // barra a barra
   m_last_price_stats_bar = bar_time;

   int bars = Bars(_Symbol, m_tf);
   if(bars <= 0) return;
   int lookback = MathMin(bars - 1, 1200);
   if(lookback < 5) return;

   double peaks[];
   double bottoms[];
   ArraySetAsSeries(peaks, true);
   ArraySetAsSeries(bottoms, true);
   if(CopyBuffer(m_pricezz_attach_handle, 0, 0, lookback, peaks) <= 0) return;
   if(CopyBuffer(m_pricezz_attach_handle, 1, 0, lookback, bottoms) <= 0) return;

   int pidx[];
   int pdir[];
   ArrayResize(pidx, 0);
   ArrayResize(pdir, 0);

   for(int i=lookback-1; i>=1; i--)
   {
      if(peaks[i] != 0.0)
      {
         int n = ArraySize(pidx);
         ArrayResize(pidx, n+1);
         ArrayResize(pdir, n+1);
         pidx[n] = i;
         pdir[n] = 1;
      }
      else if(bottoms[i] != 0.0)
      {
         int n = ArraySize(pidx);
         ArrayResize(pidx, n+1);
         ArrayResize(pdir, n+1);
         pidx[n] = i;
         pdir[n] = -1;
      }
   }

   int pivots = ArraySize(pidx);
   if(pivots < 2)
   {
      DeletePriceStatsObjects();
      return;
   }

   int last = pivots - 1;
   int prev = pivots - 2;
   int curr_len = pidx[last];
   int prev_len = pidx[prev] - pidx[last];
   if(prev_len < 0) prev_len = 0;

   const int LONG_COUNT = 20;
   double sum_long = 0.0;
   int count_long = 0;

   for(int k=0; k<pivots-1; k++)
   {
      int len = pidx[k] - pidx[k+1];
      if(len <= 0) continue;
      if(count_long < LONG_COUNT){ sum_long += len; count_long++; }
      // apenas PER (média de ciclos)
   }

   double avg_long = (count_long > 0 ? sum_long / count_long : 0.0);

   int per = (avg_long > 0 ? (int)MathRound(avg_long * 2.0) : 0);
   int prev_cycle = (prev_len > 0 ? (int)MathRound((double)prev_len * 2.0) : 0);

   int rem = (prev_len > 0 ? (prev_len - curr_len) : -1);
   if(rem < 0) rem = 0;
   string u = "--";
   string d = "--";
   if(pdir[last] < 0) u = IntegerToString(rem);
   else if(pdir[last] > 0) d = IntegerToString(rem);

   string l1 = StringFormat("PER: %d", per);
   string l2 = StringFormat("PREV: %d", prev_cycle);
   string l3 = "-----------";
   string l4 = StringFormat("U: %s  D: %s", u, d);

   int x = m_cfg.PriceStatsXOffset;
   int y = m_cfg.PriceStatsYOffset;
   color bg = (color)ColorToARGB(clrBlack, 160);
   SetBoxWin(PriceStatsBoxName(), 0, x - 6, y - 6, m_cfg.PriceStatsBoxWidth, m_cfg.PriceStatsBoxHeight, bg, clrDimGray);
   SetLabelWin(PriceStatsTextName(0), 0, x, y, clrWhite, 10, l1);
   SetLabelWin(PriceStatsTextName(1), 0, x, y + 14, clrSilver, 10, l2);
   SetLabelWin(PriceStatsTextName(2), 0, x, y + 28, clrSilver, 10, l3);
   SetLabelWin(PriceStatsTextName(3), 0, x, y + 42, clrWhite, 10, l4);
}
