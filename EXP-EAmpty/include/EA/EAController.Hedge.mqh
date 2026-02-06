void CEAController::UpdateHedgeStops()
{
   if(!m_cfg.HedgeStopEnabled) return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   int stop_level_pts = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   int freeze_level_pts = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double min_dist = (double)(stop_level_pts + freeze_level_pts) * point;

   int dg = digits;
   double pip = point * ((dg == 3 || dg == 5) ? 10.0 : 1.0);
   double extra = m_cfg.HedgeExtraPips * pip;
   if(extra < 0.0) extra = 0.0;
   double offset = min_dist + extra;

   // collect existing hedge orders
   int total_orders = OrdersTotal();
   ulong hedge_orders[];
   ArrayResize(hedge_orders, 0);
   for(int i=0; i<total_orders; i++)
   {
      ulong ot = OrderGetTicket(i);
      if(ot == 0) continue;
      if(!OrderSelect(ot)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != m_cfg.MagicNumber) continue;
      string cmt = OrderGetString(ORDER_COMMENT);
      if(StringFind(cmt, "HEDGE:") != 0) continue;
      int n = ArraySize(hedge_orders);
      ArrayResize(hedge_orders, n+1);
      hedge_orders[n] = ot;
   }

   // for each position, ensure hedge pending exists and matches
   int total_pos = PositionsTotal();
   for(int i=0; i<total_pos; i++)
   {
      if(!m_pos.IsMine(i)) continue;
      ulong pos_ticket = (ulong)PositionGetInteger(POSITION_TICKET);
      long type = PositionGetInteger(POSITION_TYPE);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double vol = PositionGetDouble(POSITION_VOLUME);
      if(sl <= 0.0) continue;
      if(offset <= 0.0) continue;

      double stop_dist = MathAbs(open - sl);
      if(stop_dist <= 0.0) continue;

      double cover = m_cfg.HedgeCoverPercent;
      if(cover < 0.0) cover = 0.0;
      double hedge_lot = vol * (stop_dist / offset) * (cover / 100.0);
      hedge_lot = m_risk.NormalizeLot(_Symbol, hedge_lot);
      if(hedge_lot <= 0.0) continue;

      double price = 0.0;
      double tp = sl;
      ENUM_ORDER_TYPE otype = ORDER_TYPE_BUY_STOP;
      if(type == POSITION_TYPE_BUY)
      {
         // SELL STOP before SL
         price = sl + offset;
         otype = ORDER_TYPE_SELL_STOP;
         if((bid - price) < (double)stop_level_pts * point) continue;
      }
      else if(type == POSITION_TYPE_SELL)
      {
         // BUY STOP before SL
         price = sl - offset;
         otype = ORDER_TYPE_BUY_STOP;
         if((price - ask) < (double)stop_level_pts * point) continue;
      }
      price = NormalizeDouble(price, digits);
      tp = NormalizeDouble(tp, digits);

      datetime exp = 0;
      if(m_cfg.HedgeExpirationMinutes > 0)
         exp = TimeCurrent() + (datetime)(m_cfg.HedgeExpirationMinutes * 60);

      string comment = StringFormat("HEDGE:%I64u", pos_ticket);

      // find existing hedge order for this position
      ulong existing = 0;
      for(int k=0; k<ArraySize(hedge_orders); k++)
      {
         ulong ot = hedge_orders[k];
         if(!OrderSelect(ot)) continue;
         string cmt = OrderGetString(ORDER_COMMENT);
         if(cmt == comment)
         {
            existing = ot;
            break;
         }
      }

      bool need_new = true;
      if(existing > 0 && OrderSelect(existing))
      {
         ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         double op = OrderGetDouble(ORDER_PRICE_OPEN);
         double otp = OrderGetDouble(ORDER_TP);
         double ov = OrderGetDouble(ORDER_VOLUME_INITIAL);
         if(t == otype && MathAbs(op - price) < point && MathAbs(otp - tp) < point && MathAbs(ov - hedge_lot) < 1e-8)
         {
            need_new = false;
         }
         else
         {
            m_broker.DeleteOrder(existing);
         }
      }

      if(need_new)
      {
         if(otype == ORDER_TYPE_BUY_STOP)
            m_broker.BuyStop(_Symbol, hedge_lot, price, 0.0, tp, exp);
         else if(otype == ORDER_TYPE_SELL_STOP)
            m_broker.SellStop(_Symbol, hedge_lot, price, 0.0, tp, exp);
      }
   }

   // delete hedge orders without position
   for(int k=0; k<ArraySize(hedge_orders); k++)
   {
      ulong ot = hedge_orders[k];
      if(!OrderSelect(ot)) continue;
      string cmt = OrderGetString(ORDER_COMMENT);
      if(StringFind(cmt, "HEDGE:") != 0) continue;
      string idstr = StringSubstr(cmt, 6);
      ulong pt = (ulong)StringToInteger(idstr);
      if(pt == 0) { m_broker.DeleteOrder(ot); continue; }
      if(!PositionSelectByTicket(pt))
      {
         m_broker.DeleteOrder(ot);
      }
   }
}
