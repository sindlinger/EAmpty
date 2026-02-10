#ifndef __EA_OCO_INDICATOR_CHECKS_MQH__
#define __EA_OCO_INDICATOR_CHECKS_MQH__

#include "../EAData/EAAccess.mqh"
#include "../Monitoring/IndicatorDecision.mqh"
#include "../Monitoring/IndicatorSnapshot.mqh"

bool CheckBTickShift(const int shift, int &dir, datetime &bar_time, int &st_sig_ok)
{
   int sig_shift = shift;
   bar_time = iTime(_Symbol, m_tf, sig_shift);
   dir = 0;
   st_sig_ok = 0;

   if(sig_shift == 0 && bar_time != m_btick_cross_bar)
   {
      m_btick_cross_bar = 0;
      m_btick_cross_time = 0;
      m_btick_cross_dir = 0;
   }

   if(m_sig.Handle() == INVALID_HANDLE)
   {
      m_sig.SetLast(0.0, 0.0, false, GetLastError());
      return false;
   }

   // usa buffers de estado (2/3). Sinal só no CRUZAMENTO (estado = +1 / -1)
   double st_buy[1];
   double st_sell[1];
   if(CopyBuffer(m_sig.Handle(), 2, sig_shift, 1, st_buy) == 1 &&
      CopyBuffer(m_sig.Handle(), 3, sig_shift, 1, st_sell) == 1)
   {
      m_sig.SetLast(st_buy[0], st_sell[0], true, 0);
      if(st_buy[0] == 1.0)
      {
         dir = 1;
         st_sig_ok = 1;
         m_last_sig_shift = sig_shift;
         if(sig_shift == 0)
         {
            m_btick_cross_bar = bar_time;
            m_btick_cross_dir = dir;
            m_btick_cross_time = TimeCurrent();
         }
      }
      else if(st_sell[0] == -1.0)
      {
         dir = -1;
         st_sig_ok = 1;
         m_last_sig_shift = sig_shift;
         if(sig_shift == 0)
         {
            m_btick_cross_bar = bar_time;
            m_btick_cross_dir = dir;
            m_btick_cross_time = TimeCurrent();
         }
      }
      if(st_sig_ok == 0)
         m_last_sig_shift = sig_shift;
      // se o cruzamento ocorreu antes na barra 0, mantém válido até fechar a barra
      if(st_sig_ok == 0 && sig_shift == 0 && m_btick_cross_bar == bar_time && m_btick_cross_dir != 0)
      {
         dir = m_btick_cross_dir;
         st_sig_ok = 1;
      }
      return (st_sig_ok == 1);
   }

   // se falhar leitura, sem sinal
   m_sig.SetLast(0.0, 0.0, false, GetLastError());
   m_last_sig_shift = sig_shift;
   return false;
}

bool CheckBTick(int &dir, datetime &bar_time, int &st_sig_ok)
{
   // wrapper padrão: usa candle fechado (bar1)
   return CheckBTickShift(1, dir, bar_time, st_sig_ok);
}

bool CheckPhase(const int dir, int &st_phase_up, int &st_phase_down, int &st_phase_rule)
{
   if(!m_cfg.UsePhaseRule) return true;
   int phase_ok = 1;
   bool phase_data_ok = false;
   int max_dist = m_cfg.PhaseMaxBarsFromTurn;
   if(max_dist < 1) max_dist = 1;
   int need = max_dist + 2;
   if(need < 6) need = 6; // barras usadas para direção e "distância" da última subida/queda
   double wave[];
   ArrayResize(wave, need);
   if(m_phase_handle != INVALID_HANDLE && CopyBuffer(m_phase_handle, 0, 0, need, wave) == need)
   {
      bool series_ok = true;
      for(int i=0; i<need; i++)
      {
         if(wave[i] == EMPTY_VALUE) { series_ok = false; break; }
      }
      if(series_ok)
      {
         phase_data_ok = true;
         bool up = (wave[0] > wave[1]);
         bool down = (wave[0] < wave[1]);
         st_phase_up = up ? 1 : 0;
         st_phase_down = down ? 1 : 0;

         int dist_since_down = 9999;
         for(int i=0; i<need-1; i++)
         {
            if(wave[i] < wave[i+1]) { dist_since_down = i; break; }
         }
         int dist_since_up = 9999;
         for(int i=0; i<need-1; i++)
         {
            if(wave[i] > wave[i+1]) { dist_since_up = i; break; }
         }

         if(dir > 0)
         {
            // COMPRA: proíbe se wave descendo OU se está distante da última descida por >= N barras
            if(!up || dist_since_down >= max_dist) phase_ok = 0;
         }
         else if(dir < 0)
         {
            // VENDA: proíbe se wave subindo OU se está distante da última subida por >= N barras
            if(!down || dist_since_up >= max_dist) phase_ok = 0;
         }
         phase_ok = (phase_ok != 0);
      }
   }
   if(!phase_data_ok)
   {
      st_phase_up = 0;
      st_phase_down = 0;
      phase_ok = 0;
   }
   st_phase_rule = phase_ok;
   return (phase_ok != 0);
}

bool CheckZigZag(const int dir, int &st_zz_high, int &st_zz_low, int &st_zz_rule)
{
   if(!m_cfg.UseZigZagRule) return true;
   int pivot_ok = 1;
   int pivot_dir = 0; // 1=topo, -1=fundo
   if(m_pricezz_handle != INVALID_HANDLE)
   {
      int bars = Bars(_Symbol, m_tf);
      int lookback = MathMin(bars - 1, 200);
      if(lookback < 2)
         pivot_ok = 0;
      else
      {
         double peaks[];
         double bottoms[];
         ArraySetAsSeries(peaks, true);
         ArraySetAsSeries(bottoms, true);
         if(CopyBuffer(m_pricezz_handle, 0, 0, lookback, peaks) <= 0 ||
            CopyBuffer(m_pricezz_handle, 1, 0, lookback, bottoms) <= 0)
         {
            pivot_ok = 0;
         }
         else
         {
            for(int i=0; i<lookback; i++)
            {
               if(peaks[i] > 0.0)
               {
                  pivot_dir = 1;
                  break;
               }
               if(bottoms[i] < 0.0)
               {
                  pivot_dir = -1;
                  break;
               }
            }

            if(pivot_dir == 0)
               pivot_ok = 0;
            else if(dir > 0)
               pivot_ok = (pivot_dir == -1) ? 1 : 0; // compra só em pivô de baixa
            else if(dir < 0)
               pivot_ok = (pivot_dir == 1) ? 1 : 0;  // venda só em pivô de alta
         }
      }
   }
   else
   {
      pivot_ok = 0;
   }
   if(pivot_dir != 0)
   {
      st_zz_high = (pivot_dir == 1) ? 1 : 0;   // topo
      st_zz_low = (pivot_dir == -1) ? 1 : 0;   // fundo
   }
   st_zz_rule = (pivot_ok != 0);
   return (pivot_ok != 0);
}

// ADXW: único sinal com expiração; estado +1/-1 vale por até 2 barras (expira depois disso)
bool CheckADXW(const int dir, const int shift, int &st_adx_rule)
{
   if(!m_cfg.UseADXWRule)
   {
      st_adx_rule = -1;
      return true;
   }
   st_adx_rule = 0;
   if(m_adxw_handle == INVALID_HANDLE)
      return false;

   // Expiração: considera sinal no shift atual e nas próximas 2 barras (total 3 barras)
   int max_shift = shift + 2;
   for(int s = shift; s <= max_shift; s++)
   {
      double st_buy[1];
      double st_sell[1];
      if(CopyBuffer(m_adxw_handle, 3, s, 1, st_buy) != 1 ||
         CopyBuffer(m_adxw_handle, 4, s, 1, st_sell) != 1)
         continue;

      if(dir > 0 && st_buy[0] == 1.0)
      {
         st_adx_rule = 1;
         return true;
      }
      if(dir < 0 && st_sell[0] == -1.0)
      {
         st_adx_rule = 1;
         return true;
      }
   }
   st_adx_rule = 0;
   return false;
}

inline bool FinalizeIndicatorDecision(const SIndicatorDecision &out,
                                      const bool allow)
{
   Monitoring::UpdateIndicatorSnapshot(out, m_sig.LastBuy(), m_sig.LastSell());
   return allow;
}

bool IndicatorsAuthorizeEntry(SIndicatorDecision &out)
{
   out.dir = 0;
   out.bar_time = 0;
   out.sig_ok = -1;
   out.sig_shift = -1;
   out.hold = -1;
   out.phase_up = -1;
   out.phase_down = -1;
   out.phase_rule = -1;
   out.zz_high = -1;
   out.zz_low = -1;
   out.zz_rule = -1;
   out.adxw_rule = -1;
   out.phase_filter = -1;
   out.sig_unique = -1;

   datetime bar0_time = iTime(_Symbol, m_tf, 0);

   // Regras (em palavras simples):
   // 1) Bar0: BTick cruza (+1/-1).
   // 2) Se essa condição ficar válida por >= metade do tempo da bar0, entra na bar0.
   // 3) Se não ficar válida por metade da bar0, NÃO entra na bar0.
   // 4) Bar1: se o cruzamento ainda existir, entra na bar1.
   // 5) Se na bar1 não houver cruzamento, não entra.

   // avalia bar0
   int dir0 = 0;
   int st_sig0 = 0;
   int st_adx0 = -1;
   datetime bar_time0 = 0;
   bool sig0 = CheckBTickShift(0, dir0, bar_time0, st_sig0);
   bool cond0 = sig0;

   // regra autorizativa: SOMENTE para sinal na barra 0
   if(m_cfg.BarZeroHold)
   {
      int bar_sec = PeriodSeconds(m_tf);
      if(bar_sec > 0 && bar0_time > 0)
      {
         int elapsed_bar = (int)(TimeCurrent() - bar0_time);
         if(m_btick_cross_time > 0 && m_btick_cross_bar == bar0_time)
            elapsed_bar = (int)(TimeCurrent() - m_btick_cross_time);
         out.hold = (elapsed_bar < (bar_sec / 2)) ? 0 : 1;
      }
      else
      {
         out.hold = 1;
      }
   }
   else
   {
      out.hold = 1;
   }

   // se é bar0 e ainda não passou metade do tempo, aguarda
   if(m_cfg.BarZeroHold && cond0 && out.hold == 0)
   {
      out.dir = dir0;
      out.bar_time = bar_time0;
      out.sig_ok = st_sig0;
      out.sig_shift = 0;
      m_last_sig_shift = 0;

      // atualiza regras para o painel (não libera entrada antes de 1/2 da barra)
      if(m_cfg.UseADXWRule)
         CheckADXW(out.dir, out.sig_shift, out.adxw_rule);
      if(m_cfg.UsePhaseRule)
         CheckPhase(out.dir, out.phase_up, out.phase_down, out.phase_rule);
      if(m_cfg.UseZigZagRule)
         CheckZigZag(out.dir, out.zz_high, out.zz_low, out.zz_rule);

      return FinalizeIndicatorDecision(out, false);
   }

   // escolhe bar0 se condição válida (e passou a metade, se for o caso)
   if(cond0)
   {
      out.dir = dir0;
      out.bar_time = bar_time0;
      out.sig_ok = st_sig0;
      out.sig_shift = 0;
      m_last_sig_shift = 0;
   }
   else
   {
      // avalia bar1
      int dir1 = 0;
      int st_sig1 = 0;
      int st_adx1 = -1;
      datetime bar_time1 = 0;
      bool sig1 = CheckBTickShift(1, dir1, bar_time1, st_sig1);
      bool cond1 = sig1;

      if(!cond1)
      {
         out.sig_ok = (sig1 ? st_sig1 : 0);
         out.sig_shift = (sig1 ? 1 : -1);
         return FinalizeIndicatorDecision(out, false);
      }

      out.dir = dir1;
      out.bar_time = bar_time1;
      out.sig_ok = st_sig1;
      out.sig_shift = 1;
      m_last_sig_shift = 1;
   }

   if(out.dir == 0)
      return FinalizeIndicatorDecision(out, false);

   int phase_ok = CheckPhase(out.dir, out.phase_up, out.phase_down, out.phase_rule) ? 1 : 0;
   int zigzag_ok = CheckZigZag(out.dir, out.zz_high, out.zz_low, out.zz_rule) ? 1 : 0;
   int adxw_ok = CheckADXW(out.dir, out.sig_shift, out.adxw_rule) ? 1 : 0;
   const bool any_rule = (m_cfg.UsePhaseRule || m_cfg.UseZigZagRule || m_cfg.UseADXWRule);

   int rules_ok = 1;
   if(any_rule)
   {
      if(m_cfg.UsePhaseRule) rules_ok = (rules_ok && (phase_ok != 0));
      if(m_cfg.UseZigZagRule) rules_ok = (rules_ok && (zigzag_ok != 0));
      if(m_cfg.UseADXWRule) rules_ok = (rules_ok && (adxw_ok != 0));
      out.phase_filter = (rules_ok ? 1 : 0);
   }
   else
   {
      out.phase_filter = 1; // sem regras ativas => não filtra
   }

   if(out.phase_filter == 0)
      return FinalizeIndicatorDecision(out, false);

   if(out.dir != 0)
   {
      m_last_cross_dir = out.dir;
      m_last_cross_bar = out.bar_time;
      m_last_cross_time = TimeCurrent();
   }
   // evita repetir a mesma execução do sinal (mesmo bar_time e direção)
   if(out.dir != 0 && m_last_signal_bar == out.bar_time && m_last_signal_dir == out.dir)
   {
      out.sig_unique = 0;
      return FinalizeIndicatorDecision(out, false);
   }
   out.sig_unique = 1;

   return FinalizeIndicatorDecision(out, true);
}

#endif
