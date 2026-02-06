void CEAController::ApplyTrailing()
{
   if(!m_cfg.UseTrailingATR) return;
   if(m_atrtrail_handle == INVALID_HANDLE) return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double stop_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   double freeze_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * point;
   double min_dist = stop_level + freeze_level;

   double trail = 0.0;
   if(!GetTrailLevel(0, trail)) return;

   int total = PositionsTotal();
   for(int i=0; i<total; i++)
   {
      if(!m_pos.IsMine(i)) continue;
      string cmt = PositionGetString(POSITION_COMMENT);
      if(cmt == "RUNNER") continue; // runner usa trailing em pontos
      ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
      long type = PositionGetInteger(POSITION_TYPE);
      double sl = PositionGetDouble(POSITION_SL);

      if(type == POSITION_TYPE_BUY)
      {
         if(trail <= 0.0) continue;
         double max_sl = bid - min_dist;
         if(max_sl <= 0.0) continue;
         double new_sl = trail;
         if(new_sl > max_sl) new_sl = max_sl;
         if(new_sl <= 0.0 || new_sl >= bid) continue;
         double new_sl_n = NormalizeDouble(new_sl, digits);
         if(sl > 0.0 && MathAbs(new_sl_n - sl) < point) continue;
         if(sl == 0.0 || new_sl_n > sl + point)
         {
            if(m_broker.ModifySL(ticket, new_sl_n))
               m_log.Info(StringFormat("Trailing BUY ticket=%I64u sl=%.5f", ticket, new_sl_n));
         }
      }
      else if(type == POSITION_TYPE_SELL)
      {
         if(trail <= 0.0) continue;
         double min_sl = ask + min_dist;
         double new_sl = trail;
         if(new_sl < min_sl) new_sl = min_sl;
         if(new_sl <= 0.0 || new_sl <= ask) continue;
         double new_sl_n = NormalizeDouble(new_sl, digits);
         if(sl > 0.0 && MathAbs(new_sl_n - sl) < point) continue;
         if(sl == 0.0 || new_sl_n < sl - point)
         {
            if(m_broker.ModifySL(ticket, new_sl_n))
               m_log.Info(StringFormat("Trailing SELL ticket=%I64u sl=%.5f", ticket, new_sl_n));
         }
      }
   }
}

bool CEAController::GetTrailLevel(const int shift, double &level)
{
   level = 0.0;
   if(m_atrtrail_handle == INVALID_HANDLE) return false;
   double buf[1];
   if(CopyBuffer(m_atrtrail_handle, 0, shift, 1, buf) != 1) return false;
   level = buf[0];
   if(level == EMPTY_VALUE) return false;
   return true;
}
