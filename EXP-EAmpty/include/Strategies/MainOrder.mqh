#ifndef __EA_OCO_STRATEGY_MAIN_ORDER_MQH__
#define __EA_OCO_STRATEGY_MAIN_ORDER_MQH__

#include "../EAData/EAAccess.mqh"
#include "../Display/DisplayPanel.mqh"
#include "../Monitoring/MonitoringAPI.mqh"
#include "../Monitoring/IndicatorSnapshot.mqh"
#include "ExitSequence.mqh"

bool GetTrailLevel(const int shift, double &level);

void RunMainOrder()
{
   datetime bar0_time = iTime(_Symbol, m_tf, 0);

   SIndicatorDecision ind;
   bool ind_ok = MonitoringUpdateIndicators(ind);

   int dir = ind.dir;
   datetime bar_time = ind.bar_time;
   int st_trading = -1;
   int st_sl = -1;

   st_trading = (m_cfg.AllowTrading &&
                 TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) &&
                 AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)) ? 1 : 0;

   if(!ind_ok)
   {
      UpdateEntryPanelFromSnapshot(st_trading, st_sl);
      UpdateChartStatus();
      return;
   }

   UpdateSeqClose(bar_time);

   if(m_cfg.MaxOpenPositions > 0 && m_pos.Count() >= m_cfg.MaxOpenPositions)
   {
      m_log.Info("Entrada bloqueada: max positions atingido.");
      UpdateEntryPanelFromSnapshot(st_trading, st_sl);
      UpdateChartStatus();
      return;
   }


   if(!m_cfg.AllowTrading) { m_log.Info("Trading disabled."); UpdateEntryPanelFromSnapshot(st_trading, st_sl); return; }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) { m_log.Info("Terminal trade not allowed."); UpdateEntryPanelFromSnapshot(st_trading, st_sl); return; }
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)) { m_log.Info("Account trade not allowed."); UpdateEntryPanelFromSnapshot(st_trading, st_sl); return; }
   // filtro de spread removido a pedido

   double lot = m_risk.NormalizeLot(_Symbol, m_cfg.LotSize);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   int tp_points = m_cfg.TPPoints;
   int sl_points = m_cfg.SLPoints;
   bool use_stop_entry = false; // forçar mercado

   if(m_cfg.StrategyPreset == 1) // PRESET_STOP_TP4_SL2
   {
      tp_points = 4;
      sl_points = 2;
      use_stop_entry = false; // mercado mesmo no preset
   }

   // calcula SL/TP sempre a partir do preço de entrada (mercado ou stop)
   double entry_price = (dir > 0 ? ask : bid);

   double sl = 0.0;
   double tp = 0.0;
   double trail_level = 0.0;
   bool sl_from_trail = false;
   if(m_cfg.UseTrailingATR)
      GetTrailLevel(1, trail_level);

   double stop_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   double spread = ask - bid;
   if(!m_slm.Build(dir, bid, ask, point, digits, entry_price, trail_level, stop_level, spread, sl_points, tp_points, sl, tp, sl_from_trail))
   {
      st_sl = 0;
      if(bar_time != 0 && bar_time != m_last_atr_block_bar)
      {
         m_log.Info("Entrada bloqueada: ATR trailing inválido para esta direção.");
         m_last_atr_block_bar = bar_time;
      }
      UpdateEntryPanelFromSnapshot(st_trading, st_sl);
      UpdateChartStatus();
      return;
   }
   st_sl = 1;

   // runner: SL separado (opcional) e TP 1:1 por padrão
   int r_sl_points = (m_cfg.RunnerSLPoints >= 0 ? m_cfg.RunnerSLPoints : sl_points);
   int r_sl_min = (m_cfg.RunnerSLMinPoints >= 0 ? m_cfg.RunnerSLMinPoints : m_cfg.SLMinPoints);
   int r_sl_max = (m_cfg.RunnerSLMaxPoints >= 0 ? m_cfg.RunnerSLMaxPoints : m_cfg.SLMaxPoints);
   int r_tp_points = (m_cfg.RunnerTPPoints >= 0 ? m_cfg.RunnerTPPoints : 0);

   double runner_sl = sl;
   double runner_tp = tp;
   bool runner_sl_from_trail = false;

   if(m_cfg.RunnerEnabled && m_cfg.NumOrders >= 2)
   {
      if(!m_slm.Build(dir, bid, ask, point, digits, entry_price, trail_level, stop_level, spread,
                     r_sl_points, r_tp_points, runner_sl, runner_tp, runner_sl_from_trail, r_sl_min, r_sl_max))
      {
         runner_sl = sl;
         runner_tp = tp;
      }
      if(m_cfg.RunnerTPPoints < 0)
      {
         if(runner_sl > 0.0)
         {
            double dist = MathAbs(entry_price - runner_sl);
            if(dist > 0.0)
               runner_tp = (dir > 0 ? entry_price + dist : entry_price - dist);
         }
      }
      if(runner_tp > 0.0) runner_tp = NormalizeDouble(runner_tp, digits);
      if(runner_sl > 0.0) runner_sl = NormalizeDouble(runner_sl, digits);
   }

   int ok_count = 0;
   bool ok_main = false;
   bool ok_runner = false;
   Monitoring::SIndicatorSnapshot snap;
   Monitoring::GetIndicatorSnapshot(snap);
   string phase_s = (m_cfg.UsePhaseRule ? (snap.phase_rule != 0 ? "OK" : "NO") : "OFF");
   string zz_s = (m_cfg.UseZigZagRule ? (snap.zz_rule != 0 ? "OK" : "NO") : "OFF");
   string hold_s = (m_cfg.BarZeroHold ? (snap.hold == 1 ? "OK" : "NO") : "OFF");
   if(dir > 0)
   {
      if(m_exec.Buy(_Symbol, lot, sl, tp, "MAIN")) { ok_count++; ok_main = true; }
      else
      {
         uint rc; string cm; ulong ord; int err;
         m_exec.GetLastResult(rc, cm, ord, err);
         m_log.Error(StringFormat("Order failed BUY MAIN | retcode=%u(%s) comment=%s order=%I64u err=%d",
                                  rc, TRCSTR(rc), cm, ord, err));
      }
      if(m_cfg.RunnerEnabled && m_cfg.NumOrders >= 2)
      {
         if(m_exec.Buy(_Symbol, lot, runner_sl, runner_tp, "RUNNER")) { ok_count++; ok_runner = true; }
         else
         {
            uint rc; string cm; ulong ord; int err;
            m_exec.GetLastResult(rc, cm, ord, err);
            m_log.Error(StringFormat("Order failed BUY RUNNER | retcode=%u(%s) comment=%s order=%I64u err=%d",
                                     rc, TRCSTR(rc), cm, ord, err));
         }
      }
   }
   else if(dir < 0)
   {
      if(m_exec.Sell(_Symbol, lot, sl, tp, "MAIN")) { ok_count++; ok_main = true; }
      else
      {
         uint rc; string cm; ulong ord; int err;
         m_exec.GetLastResult(rc, cm, ord, err);
         m_log.Error(StringFormat("Order failed SELL MAIN | retcode=%u(%s) comment=%s order=%I64u err=%d",
                                  rc, TRCSTR(rc), cm, ord, err));
      }
      if(m_cfg.RunnerEnabled && m_cfg.NumOrders >= 2)
      {
         if(m_exec.Sell(_Symbol, lot, runner_sl, runner_tp, "RUNNER")) { ok_count++; ok_runner = true; }
         else
         {
            uint rc; string cm; ulong ord; int err;
            m_exec.GetLastResult(rc, cm, ord, err);
            m_log.Error(StringFormat("Order failed SELL RUNNER | retcode=%u(%s) comment=%s order=%I64u err=%d",
                                     rc, TRCSTR(rc), cm, ord, err));
         }
      }
   }

   if(ok_count > 0)
   {
      string side = (dir > 0 ? "BUY" : "SELL");
      if(ok_main)
      {
         m_log.Info(StringFormat("ENTRY %s MAIN lot=%.2f price=%.5f sl=%.5f tp=%.5f | rules: phase=%s zz=%s hold=%s",
                                 side, lot, entry_price, sl, tp, phase_s, zz_s, hold_s));
      }
      if(ok_runner)
      {
         m_log.Info(StringFormat("ENTRY %s RUNNER lot=%.2f price=%.5f sl=%.5f tp=%.5f | rules: phase=%s zz=%s hold=%s",
                                 side, lot, entry_price, runner_sl, runner_tp, phase_s, zz_s, hold_s));
      }
   }
   else
      m_log.Error(StringFormat("Order failed: %s (no execution)", dir>0?"BUY":"SELL"));

   if(ok_count > 0)
   {
      m_last_signal_bar = bar_time; // registro do último sinal efetivado
      m_last_signal_dir = dir;      // evita repetir o mesmo sinal em barras seguintes
   }

   UpdateEntryPanelFromSnapshot(st_trading, st_sl);
   UpdateChartStatus();
}

#endif
