void CEAController::ManageRunner()
{
   if(!m_cfg.RunnerEnabled) return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double stop_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   double freeze_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * point;
   double min_dist = stop_level + freeze_level;

   int be_points = m_cfg.RunnerBEPoints;
   if(be_points <= 0) be_points = m_cfg.SLPoints;
   if(be_points <= 0) be_points = 1;

   int total = PositionsTotal();
   for(int i=total-1; i>=0; i--)
   {
      if(!m_pos.IsMine(i)) continue;
      string comment = PositionGetString(POSITION_COMMENT);
      if(comment != "RUNNER") continue;

      long type = PositionGetInteger(POSITION_TYPE);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      double profit_pts = (type == POSITION_TYPE_BUY ? (bid - open)/point : (open - ask)/point);
      if(profit_pts < be_points) continue;

      // move MAIN positions to breakeven
      for(int j=total-1; j>=0; j--)
      {
         if(!m_pos.IsMine(j)) continue;
         string c2 = PositionGetString(POSITION_COMMENT);
         if(c2 != "MAIN") continue;
         long t2 = PositionGetInteger(POSITION_TYPE);
         double open2 = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl2 = PositionGetDouble(POSITION_SL);
         double be = open2;
         if(t2 == POSITION_TYPE_BUY)
         {
            if((bid - be) < min_dist) continue;
            if(sl2 <= 0.0 || sl2 < be)
               m_broker.ModifySLTP((ulong)PositionGetInteger(POSITION_TICKET), NormalizeDouble(be, digits), PositionGetDouble(POSITION_TP));
         }
         else if(t2 == POSITION_TYPE_SELL)
         {
            if((be - ask) < min_dist) continue;
            if(sl2 <= 0.0 || sl2 > be)
               m_broker.ModifySLTP((ulong)PositionGetInteger(POSITION_TICKET), NormalizeDouble(be, digits), PositionGetDouble(POSITION_TP));
         }
      }

      // runner SL: BE + lock
      double lock = (double)m_cfg.RunnerLockPoints * point;
      double new_sl = (type == POSITION_TYPE_BUY ? open + lock : open - lock);

      // trailing a favor
      if(m_cfg.RunnerTrailStartPoints > 0 && profit_pts >= m_cfg.RunnerTrailStartPoints)
      {
         double trail = (type == POSITION_TYPE_BUY ? bid - m_cfg.RunnerTrailDistancePoints*point : ask + m_cfg.RunnerTrailDistancePoints*point);
         if(type == POSITION_TYPE_BUY && trail > new_sl) new_sl = trail;
         if(type == POSITION_TYPE_SELL && trail < new_sl) new_sl = trail;
      }

      // valida lado correto
      if(type == POSITION_TYPE_BUY)
      {
         double max_sl = bid - min_dist;
         if(max_sl <= 0.0) continue;
         if(new_sl > max_sl) new_sl = max_sl;
         if(new_sl >= bid) new_sl = bid - point;
      }
      if(type == POSITION_TYPE_SELL)
      {
         double min_sl = ask + min_dist;
         if(new_sl < min_sl) new_sl = min_sl;
         if(new_sl <= ask) new_sl = ask + point;
      }

      if(new_sl > 0.0)
      {
         bool better = false;
         if(type == POSITION_TYPE_BUY) better = (sl <= 0.0 || new_sl > sl + point);
         else if(type == POSITION_TYPE_SELL) better = (sl <= 0.0 || new_sl < sl - point);

         if(better)
         {
            double new_tp = (m_cfg.RunnerRemoveTPOnBE ? 0.0 : tp);
            m_broker.ModifySLTP((ulong)PositionGetInteger(POSITION_TICKET), NormalizeDouble(new_sl, digits), new_tp);
         }
      }
   }
}
