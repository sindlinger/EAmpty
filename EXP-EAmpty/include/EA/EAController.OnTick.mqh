void CEAController::OnTick()
{
   ApplyTrailing();

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
   bool use_stop_entry = false;
   int offset_pts = m_cfg.EntryOffsetPoints;
   if(offset_pts < 1) offset_pts = 1;

   if(m_cfg.StrategyPreset == 1) // PRESET_STOP_TP4_SL2
   {
      tp_points = 4;
      sl_points = 2;
      use_stop_entry = true;
   }

   double stop_price = 0.0;
   datetime expiration = 0;
   if(use_stop_entry)
   {
      int ps = PeriodSeconds(m_tf);
      if(ps <= 0) ps = PeriodSeconds(_Period);
      expiration = bar_time + ps;

      if(dir > 0)
         stop_price = ask + offset_pts * point;
      else
         stop_price = bid - offset_pts * point;
      stop_price = NormalizeDouble(stop_price, digits);
   }

   // calcula SL/TP sempre a partir do preço de entrada (mercado ou stop)
   double entry_price = (dir > 0 ? ask : bid);
   if(use_stop_entry && stop_price > 0.0)
      entry_price = stop_price;

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

   if(use_stop_entry && stop_price > 0.0)
   {
      if(dir > 0 && stop_price <= ask)
         return;
      if(dir < 0 && stop_price >= bid)
         return;
   }

   int ok_count = 0;
   for(int i=0; i<m_cfg.NumOrders; i++)
   {
      bool ok = false;
      if(dir > 0)
      {
         if(use_stop_entry && stop_price > 0.0)
            ok = m_broker.BuyStop(_Symbol, lot, stop_price, sl, tp, expiration);
         else
            ok = m_broker.Buy(_Symbol, lot, sl, tp);
      }
      else if(dir < 0)
      {
         if(use_stop_entry && stop_price > 0.0)
            ok = m_broker.SellStop(_Symbol, lot, stop_price, sl, tp, expiration);
         else
            ok = m_broker.Sell(_Symbol, lot, sl, tp);
      }

      if(ok)
      {
         ok_count++;
         m_log.Info(StringFormat("Opened %s lot=%.2f", dir>0?"BUY":"SELL", lot));
      }
      else
      {
         m_log.Error(StringFormat("Order failed: %s", dir>0?"BUY":"SELL"));
      }
   }

   if(ok_count > 0)
      m_last_signal_bar = bar_time; // registro do último sinal efetivado

   UpdateChartStatus();
}
