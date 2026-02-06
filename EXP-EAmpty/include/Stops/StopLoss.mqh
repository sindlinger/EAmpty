#ifndef __EA_OCO_STOPLOSS_MQH__
#define __EA_OCO_STOPLOSS_MQH__

#include "../Config/Config.mqh"

class CStopLoss
{
private:
   SConfig m_cfg;

public:
   void Init(const SConfig &cfg)
   {
      m_cfg = cfg;
   }

   // Calcula SL/TP para entrada. Retorna false se trailing ATR estiver ativo e inválido.
   bool Build(const int dir,
              const double bid,
              const double ask,
              const double point,
              const int digits,
              const double entry_price,
              const double trail_level,
              const double stop_level,
              const double spread,
              const int sl_points,
              const int tp_points,
              double &sl,
              double &tp,
              bool &sl_from_trail) const
   {
      sl = 0.0;
      tp = 0.0;
      sl_from_trail = false;

      if(m_cfg.UseTrailingATR)
      {
         if(dir > 0 && trail_level > 0.0 && trail_level < bid)
         {
            sl = trail_level;
            sl_from_trail = true;
         }
         else if(dir < 0 && trail_level > 0.0 && trail_level > ask)
         {
            sl = trail_level;
            sl_from_trail = true;
         }
         else
         {
            return false; // trailing inválido
         }
      }

      if(!sl_from_trail)
      {
         if(sl_points > 0)
         {
            if(dir > 0) sl = entry_price - sl_points * point;
            else if(dir < 0) sl = entry_price + sl_points * point;
         }

         if(sl > 0.0)
         {
            int min_pts = m_cfg.SLMinPoints;
            int max_pts = m_cfg.SLMaxPoints;
            if(min_pts < 0) min_pts = -min_pts;
            if(max_pts < 0) max_pts = -max_pts;
            double dist = MathAbs(entry_price - sl);
            if(min_pts > 0 && dist < (double)min_pts * point) dist = (double)min_pts * point;
            if(max_pts > 0 && dist > (double)max_pts * point) dist = (double)max_pts * point;
            if(dir > 0) sl = entry_price - dist;
            else if(dir < 0) sl = entry_price + dist;
         }
      }

      if(tp_points > 0)
      {
         if(dir > 0) tp = entry_price + tp_points * point;
         else if(dir < 0) tp = entry_price - tp_points * point;
      }

      // distância mínima para evitar SL/TP encostado no preço
      double min_sl_dist = stop_level + spread;
      double min_tp_dist = stop_level;

      // se SL veio do ATR e está muito perto, invalida a entrada
      if(sl_from_trail && sl > 0.0)
      {
         double dist = MathAbs(entry_price - sl);
         if(dist < min_sl_dist)
            return false;
      }

      if(dir > 0)
      {
         if(!sl_from_trail && sl > 0.0 && (entry_price - sl) < min_sl_dist)
            sl = entry_price - min_sl_dist;
         if(tp > 0.0 && (tp - entry_price) < min_tp_dist)
            tp = entry_price + min_tp_dist;
      }
      else if(dir < 0)
      {
         if(!sl_from_trail && sl > 0.0 && (sl - entry_price) < min_sl_dist)
            sl = entry_price + min_sl_dist;
         if(tp > 0.0 && (entry_price - tp) < min_tp_dist)
            tp = entry_price - min_tp_dist;
      }

      if(sl > 0.0) sl = NormalizeDouble(sl, digits);
      if(tp > 0.0) tp = NormalizeDouble(tp, digits);

      return true;
   }
};

#endif
