void CEAController::UpdateSeqClose(const datetime bar_time)
{
   if(m_cfg.CloseSeqBars <= 0) return;
   if(bar_time == 0) return;
   if(bar_time == m_last_state_bar) return;

   double b = m_sig.LastBuy();
   double s = m_sig.LastSell();

   if(b == 3.0) m_consec_buy3++;
   else m_consec_buy3 = 0;

   if(s == -3.0) m_consec_sell3++;
   else m_consec_sell3 = 0;

   m_last_state_bar = bar_time;

   if(m_consec_buy3 >= m_cfg.CloseSeqBars)
      ClosePositionsByType(POSITION_TYPE_BUY);
   if(m_consec_sell3 >= m_cfg.CloseSeqBars)
      ClosePositionsByType(POSITION_TYPE_SELL);
}

void CEAController::ClosePositionsByType(const long type)
{
   int total = PositionsTotal();
   for(int i=total-1; i>=0; i--)
   {
      if(!m_pos.IsMine(i)) continue;
      long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype != type) continue;
      ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
      if(ticket == 0) continue;
      if(m_broker.ClosePosition(ticket))
         m_log.Info(StringFormat("Closed %s ticket=%I64u by seq", type==POSITION_TYPE_BUY?"BUY":"SELL", ticket));
   }
}
