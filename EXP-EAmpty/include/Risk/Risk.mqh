#ifndef __EA_OCO_RISK_MQH__
#define __EA_OCO_RISK_MQH__

class CRisk
{
public:
   double NormalizeLot(const string symbol, const double lot)
   {
      double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      if(step <= 0.0) step = min_lot;

      double v = lot;
      if(v < min_lot) v = min_lot;
      if(v > max_lot) v = max_lot;
      int steps = (int)MathFloor((v - min_lot) / step + 0.5);
      double out = min_lot + steps * step;
      if(out < min_lot) out = min_lot;
      if(out > max_lot) out = max_lot;
      return out;
   }

   double SpreadPips(const string symbol)
   {
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      if(bid <= 0.0 || ask <= 0.0) return 0.0;
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      double pip = point * ((digits == 3 || digits == 5) ? 10.0 : 1.0);
      return (ask - bid) / pip;
   }

   bool SpreadOk(const string symbol, const double max_spread_pips)
   {
      if(max_spread_pips <= 0.0) return true;
      return (SpreadPips(symbol) <= max_spread_pips);
   }
};

#endif
