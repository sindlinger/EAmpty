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
      return m_trade.PositionModify(ticket, sl, 0.0);
   }

   bool ModifySLTP(const ulong ticket, const double sl, const double tp)
   {
      if(ticket == 0) return false;
      return m_trade.PositionModify(ticket, sl, tp);
   }

   bool ClosePosition(const ulong ticket)
   {
      if(ticket == 0) return false;
      return m_trade.PositionClose(ticket);
   }
};

#endif
