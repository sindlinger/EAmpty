void CEAController::OnTick()
{
   ApplyTrailing();
   ManageRunner();

   int dir = 0;
   datetime bar_time = 0;
   if(!m_sig.GetSignal(dir, bar_time))
      return;

   UpdateSeqClose(bar_time);

   if(dir == 0)
   {
      UpdateChartStatus();
      return;
   }

   if(dir != 0)
   {
      m_last_cross_dir = dir;
      m_last_cross_bar = bar_time;
      m_last_cross_time = TimeCurrent();
   }
   // evita múltiplas entradas na mesma barra do sinal
   if(bar_time != 0 && m_last_signal_bar == bar_time)
   {
      UpdateChartStatus();
      return;
   }

   if(!m_cfg.AllowTrading) { m_log.Info("Trading disabled."); return; }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) { m_log.Info("Terminal trade not allowed."); return; }
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)) { m_log.Info("Account trade not allowed."); return; }
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
      m_log.Info("Entrada bloqueada: ATR trailing inválido para esta direção.");
      UpdateChartStatus();
      return;
   }

   // runner com TP 1:1 baseado na distância do SL
   double runner_tp = tp;
   if(sl > 0.0)
   {
      double dist = MathAbs(entry_price - sl);
      if(dist > 0.0)
         runner_tp = (dir > 0 ? entry_price + dist : entry_price - dist);
   }
   if(runner_tp > 0.0) runner_tp = NormalizeDouble(runner_tp, digits);

   int ok_count = 0;
   if(dir > 0)
   {
      if(m_broker.Buy(_Symbol, lot, sl, tp, "MAIN")) ok_count++;
      if(m_cfg.RunnerEnabled && m_cfg.NumOrders >= 2)
         if(m_broker.Buy(_Symbol, lot, sl, runner_tp, "RUNNER")) ok_count++;
   }
   else if(dir < 0)
   {
      if(m_broker.Sell(_Symbol, lot, sl, tp, "MAIN")) ok_count++;
      if(m_cfg.RunnerEnabled && m_cfg.NumOrders >= 2)
         if(m_broker.Sell(_Symbol, lot, sl, runner_tp, "RUNNER")) ok_count++;
   }

   if(ok_count > 0)
      m_log.Info(StringFormat("Opened %s x%d lot=%.2f", dir>0?"BUY":"SELL", ok_count, lot));
   else
      m_log.Error(StringFormat("Order failed: %s", dir>0?"BUY":"SELL"));

   if(ok_count > 0)
      m_last_signal_bar = bar_time; // registro do último sinal efetivado

   UpdateChartStatus();
}
