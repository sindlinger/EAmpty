CEAController::CEAController()
{
   m_atrtrail_handle = INVALID_HANDLE;
   m_last_signal_bar = 0;
   m_btick_path = "IND-Btick\\BTick_v2.0.5_FFT";
   m_atrtrail_path = "ATR_Trailing_Stop_1_Buffer";
   m_btick_loaded = false;
   m_atr_loaded = false;
   m_last_cross_bar = 0;
   m_last_cross_time = 0;
   m_last_cross_dir = 0;
   m_last_state_bar = 0;
   m_consec_buy3 = 0;
   m_consec_sell3 = 0;
}

bool CEAController::Init(const SConfig &cfg)
{
   m_cfg = cfg;
   m_log.Init(m_cfg.LogLevel, m_cfg.PrintToJournal);
   m_broker.Init(m_cfg.MagicNumber, m_cfg.DeviationPoints);
   m_pos.Init(_Symbol, m_cfg.MagicNumber);
   m_slm.Init(m_cfg);
   m_tf = (ENUM_TIMEFRAMES)_Period;

   m_btick_loaded = m_sig.Init(_Symbol, m_btick_path, m_tf);
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

   return true;
}

void CEAController::Deinit()
{
   if(m_atrtrail_handle != INVALID_HANDLE)
   {
      IndicatorRelease(m_atrtrail_handle);
      m_atrtrail_handle = INVALID_HANDLE;
   }
   m_sig.Deinit();
}
