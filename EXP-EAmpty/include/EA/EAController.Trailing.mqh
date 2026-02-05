void CEAController::ApplyTrailing()
{
   if(!m_cfg.UseTrailingATR) return;
   if(m_atrtrail_handle == INVALID_HANDLE) return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   double trail = 0.0;
   if(!GetTrailLevel(0, trail)) return;

   int total = PositionsTotal();
   for(int i=0; i<total; i++)
   {
      if(!m_pos.IsMine(i)) continue;
      ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
      long type = PositionGetInteger(POSITION_TYPE);
      double sl = PositionGetDouble(POSITION_SL);

      if(type == POSITION_TYPE_BUY)
      {
         double new_sl = trail;
         if(new_sl <= 0.0 || new_sl >= bid) continue;
         if(sl == 0.0 || new_sl > sl + point)
         {
            if(m_broker.ModifySL(ticket, NormalizeDouble(new_sl, digits)))
               m_log.Info(StringFormat("Trailing BUY ticket=%I64u sl=%.5f", ticket, new_sl));
         }
      }
      else if(type == POSITION_TYPE_SELL)
      {
         double new_sl = trail;
         if(new_sl <= 0.0 || new_sl <= ask) continue;
         if(sl == 0.0 || new_sl < sl - point)
         {
            if(m_broker.ModifySL(ticket, NormalizeDouble(new_sl, digits)))
               m_log.Info(StringFormat("Trailing SELL ticket=%I64u sl=%.5f", ticket, new_sl));
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
