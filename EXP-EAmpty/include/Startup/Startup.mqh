#ifndef __EA_OCO_STARTUP_MQH__
#define __EA_OCO_STARTUP_MQH__

#include "../EAData/EAAccess.mqh"
#include "../Display/DisplayPanel.mqh"
#include "../Indicators/IndicatorLoader.mqh"
#include "../Monitoring/IndicatorSnapshot.mqh"

void InitRuntimeData()
{
   Monitoring::ResetIndicatorSnapshot();
   m_atrtrail_handle = INVALID_HANDLE;
   m_phase_handle = INVALID_HANDLE;
   m_pricezz_handle = INVALID_HANDLE;
   m_pricezz_attach_handle = INVALID_HANDLE;
   m_adxw_handle = INVALID_HANDLE;
   m_adxw_attach_handle = INVALID_HANDLE;
   m_last_signal_bar = 0;
   m_last_signal_dir = 0;
   m_last_sig_shift = 0;
   m_btick_path = "IND-EAmpty\\BTickOldVersion\\BTick_ATRNorm_vZERO";
   m_atrtrail_path = "ATR_Trailing_Stop_1_Buffer";
   m_phase_path = "IND-EAmpty\\PhaseClock-CloseStdDev\\PhaseClock-CloseStdDev_v1";
   m_pricezz_path = "IND-EAmpty\\FiboZigZag\\ZZ_ADX_Pivots_PhaseSTD_v1_0_3"; // filtro (PhaseSTD)
   m_pricezz_attach_path = "IND-EAmpty\\FiboZigZag\\ZZ_ADX_Pivots_PhaseSTD_v1_0_3";   // visual (PhaseSTD)
   m_adxw_path = "IND-EAmpty\\FiboZigZag\\ADXW_v1.0";
   m_btick_loaded = false;
   m_atr_loaded = false;
   m_phase_loaded = false;
   m_pricezz_loaded = false;
   m_last_cross_bar = 0;
   m_last_cross_time = 0;
   m_last_cross_dir = 0;
   m_last_state_bar = 0;
   m_last_atr_block_bar = 0;
   m_btick_cross_bar = 0;
   m_btick_cross_time = 0;
   m_btick_cross_dir = 0;
   m_consec_buy3 = 0;
   m_consec_sell3 = 0;
   m_live_dir = 0;
   m_live_bar = 0;
   m_live_start = 0;
   m_last_price_stats_bar = 0;
}

bool EA_Init(const SConfig &cfg)
{
   InitRuntimeData();
   m_cfg = cfg;
   m_log.Init(m_cfg.LogLevel, m_cfg.PrintToJournal);
   m_exec.Init(m_cfg.MagicNumber, m_cfg.DeviationPoints);
   m_pos.Init(_Symbol, m_cfg.MagicNumber);
   m_slm.Init(m_cfg);
   m_tf = (ENUM_TIMEFRAMES)_Period;

   return InitIndicators();
}

void EA_Deinit()
{
   DeletePriceStatsObjects();
   DeleteEntryPanel();
   DeleteConfigPanel();
   ReleaseIndicators();
}

#endif
