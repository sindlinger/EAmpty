#ifndef __EA_OCO_INDICATOR_LOADER_MQH__
#define __EA_OCO_INDICATOR_LOADER_MQH__

#include "../EAData/EAAccess.mqh"
#include "../Display/DisplayPanel.mqh"

void RemoveIndicatorsByMatch(const int win, const string token)
{
   int total = ChartIndicatorsTotal(0, win);
   for(int i=total-1; i>=0; i--)
   {
      string name = ChartIndicatorName(0, win, i);
      if(StringFind(name, token) >= 0)
         ChartIndicatorDelete(0, win, name);
   }
}

bool InitIndicators()
{
   m_btick_loaded = m_sig.Init(_Symbol, m_btick_path, m_tf, m_cfg.SignalShift, m_cfg.BTickStateOnly);
   if(!m_btick_loaded)
   {
      m_log.Error("BTick iCustom handle failed.");
      return false;
   }

   if(m_cfg.UseTrailingATR)
   {
      m_atrtrail_handle = iCustom(_Symbol, m_tf, m_atrtrail_path);
      if(m_atrtrail_handle == INVALID_HANDLE)
      {
         m_log.Error("ATR trailing handle failed.");
         return false;
      }
      m_atr_loaded = true;
   }

   if(!m_cfg.UsePhaseRule && !m_cfg.AttachPhaseClock)
      RemoveIndicatorsByMatch(m_cfg.PhaseClockWindow, "PhaseClock");

   if(!m_cfg.UseZigZagRule && !m_cfg.AttachPriceZigZag)
      RemoveIndicatorsByMatch(m_cfg.PriceZigZagWindow, "ZZ_ADX_Pivots");

   if(!m_cfg.AttachADXW)
   {
      RemoveIndicatorsByMatch(m_cfg.ADXWWindow, "ADX Wilder");
      RemoveIndicatorsByMatch(m_cfg.ADXWWindow, "ADXW");
   }

   if(m_cfg.UsePhaseRule || m_cfg.AttachPhaseClock)
   {
      m_phase_handle = iCustom(_Symbol, m_tf, m_phase_path);
      if(m_phase_handle == INVALID_HANDLE)
      {
         m_log.Error("PhaseClock handle failed.");
      }
      else
      {
         if(m_cfg.AttachPhaseClock)
         {
            int win = m_cfg.PhaseClockWindow;
            if(win < 1) win = 1;
            if(ChartIndicatorAdd(0, win, m_phase_handle))
               m_phase_loaded = true;
            else
               m_log.Error("PhaseClock ChartIndicatorAdd failed.");
         }
      }
   }

   if(m_cfg.UseZigZagRule || m_cfg.AttachPriceZigZag)
   {
      // sem inputs: usa a configuração interna do indicador
      m_pricezz_handle = iCustom(_Symbol, m_tf, m_pricezz_path);
      if(m_pricezz_handle == INVALID_HANDLE)
      {
         m_log.Error("Price ZigZag handle failed.");
      }
      else if(m_cfg.AttachPriceZigZag)
      {
         m_pricezz_attach_handle = m_pricezz_handle;
         int win = m_cfg.PriceZigZagWindow;
         if(win < 0) win = 0;
         if(ChartIndicatorAdd(0, win, m_pricezz_attach_handle))
            m_pricezz_loaded = true;
         else
            m_log.Error("Price ZigZag ChartIndicatorAdd failed.");
      }
   }

   if(m_cfg.UseADXWRule || m_cfg.AttachADXW)
   {
      // sem inputs: usa a configuração interna do indicador
      m_adxw_handle = iCustom(_Symbol, m_tf, m_adxw_path);
      if(m_adxw_handle == INVALID_HANDLE)
         m_log.Error("ADXW handle failed.");
   }

   if(m_cfg.AttachADXW)
   {
      if(m_adxw_handle == INVALID_HANDLE)
      {
         m_log.Error("ADXW attach handle failed.");
      }
      else
      {
         m_adxw_attach_handle = m_adxw_handle;
         int win = m_cfg.ADXWWindow;
         if(win < 0) win = 0;
         if(!ChartIndicatorAdd(0, win, m_adxw_attach_handle))
            m_log.Error("ADXW ChartIndicatorAdd failed.");
      }
   }

   return true;
}

void ReleaseIndicators()
{
   if(m_atrtrail_handle != INVALID_HANDLE)
   {
      IndicatorRelease(m_atrtrail_handle);
      m_atrtrail_handle = INVALID_HANDLE;
   }
   if(m_phase_handle != INVALID_HANDLE)
   {
      IndicatorRelease(m_phase_handle);
      m_phase_handle = INVALID_HANDLE;
   }
   if(m_pricezz_attach_handle != INVALID_HANDLE && m_pricezz_attach_handle != m_pricezz_handle)
   {
      IndicatorRelease(m_pricezz_attach_handle);
      m_pricezz_attach_handle = INVALID_HANDLE;
   }
   if(m_pricezz_handle != INVALID_HANDLE)
   {
      IndicatorRelease(m_pricezz_handle);
      m_pricezz_handle = INVALID_HANDLE;
      m_pricezz_attach_handle = INVALID_HANDLE;
   }
   if(m_adxw_attach_handle != INVALID_HANDLE && m_adxw_attach_handle != m_adxw_handle)
   {
      IndicatorRelease(m_adxw_attach_handle);
      m_adxw_attach_handle = INVALID_HANDLE;
   }
   if(m_adxw_handle != INVALID_HANDLE)
   {
      IndicatorRelease(m_adxw_handle);
      m_adxw_handle = INVALID_HANDLE;
      m_adxw_attach_handle = INVALID_HANDLE;
   }
   m_sig.Deinit();
}

#endif
