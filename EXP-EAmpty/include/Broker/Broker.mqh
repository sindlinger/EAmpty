#ifndef __EA_OCO_BROKER_MQH__
#define __EA_OCO_BROKER_MQH__

#include <Trade/Trade.mqh>

class CBroker
{
private:
   CTrade m_trade;
   long m_magic;
   int m_deviation;

public:
   void Init(const long magic, const int deviation_points)
   {
      m_magic = magic;
      m_deviation = deviation_points;
      m_trade.SetExpertMagicNumber(m_magic);
      m_trade.SetDeviationInPoints(m_deviation);
   }

   bool Buy(const string symbol, const double lots, const double sl, const double tp, const string comment = "")
   {
      return m_trade.Buy(lots, symbol, 0.0, sl, tp, comment);
   }

   bool Sell(const string symbol, const double lots, const double sl, const double tp, const string comment = "")
   {
      return m_trade.Sell(lots, symbol, 0.0, sl, tp, comment);
   }

   bool BuyStop(const string symbol, const double lots, const double price,
                const double sl, const double tp,
                const datetime expiration)
   {
      if(expiration > 0)
         return m_trade.BuyStop(lots, price, symbol, sl, tp, ORDER_TIME_SPECIFIED, expiration);
      return m_trade.BuyStop(lots, price, symbol, sl, tp, ORDER_TIME_GTC, 0);
   }

   bool SellStop(const string symbol, const double lots, const double price,
                 const double sl, const double tp,
                 const datetime expiration)
   {
      if(expiration > 0)
         return m_trade.SellStop(lots, price, symbol, sl, tp, ORDER_TIME_SPECIFIED, expiration);
      return m_trade.SellStop(lots, price, symbol, sl, tp, ORDER_TIME_GTC, 0);
   }

   bool DeleteOrder(const ulong ticket)
   {
      if(ticket == 0) return false;
      return m_trade.OrderDelete(ticket);
   }

   bool ModifySL(const ulong ticket, const double sl)
   {
      if(ticket == 0) return false;
      if(!PositionSelectByTicket(ticket)) return false;

      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double cur_sl = PositionGetDouble(POSITION_SL);
      if(cur_sl > 0.0 && MathAbs(sl - cur_sl) < point) return true;

      long type = PositionGetInteger(POSITION_TYPE);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double min_dist = (SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) +
                         SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL)) * point;

      if(sl > 0.0)
      {
         if(type == POSITION_TYPE_BUY)
         {
            if(sl >= bid) return true;
            if((bid - sl) < min_dist) return true;
         }
         else if(type == POSITION_TYPE_SELL)
         {
            if(sl <= ask) return true;
            if((sl - ask) < min_dist) return true;
         }
      }

      return m_trade.PositionModify(ticket, sl, 0.0);
   }

   bool ModifySLTP(const ulong ticket, const double sl, const double tp)
   {
      if(ticket == 0) return false;
      if(!PositionSelectByTicket(ticket)) return false;

      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double cur_sl = PositionGetDouble(POSITION_SL);
      if(cur_sl > 0.0 && MathAbs(sl - cur_sl) < point) return true;

      long type = PositionGetInteger(POSITION_TYPE);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double min_dist = (SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) +
                         SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL)) * point;

      if(sl > 0.0)
      {
         if(type == POSITION_TYPE_BUY)
         {
            if(sl >= bid) return true;
            if((bid - sl) < min_dist) return true;
         }
         else if(type == POSITION_TYPE_SELL)
         {
            if(sl <= ask) return true;
            if((sl - ask) < min_dist) return true;
         }
      }

      return m_trade.PositionModify(ticket, sl, tp);
   }

   bool ClosePosition(const ulong ticket)
   {
      if(ticket == 0) return false;
      return m_trade.PositionClose(ticket);
   }
};

#endif
