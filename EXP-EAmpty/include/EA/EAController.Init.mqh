CEAController::CEAController()
{
   m_atrtrail_handle = INVALID_HANDLE;
   m_phase_handle = INVALID_HANDLE;
   m_pricezz_handle = INVALID_HANDLE;
   m_last_signal_bar = 0;
   m_btick_path = "IND-Btick\\BTick_v2.0.5_FFT";
   m_atrtrail_path = "ATR_Trailing_Stop_1_Buffer";
   m_phase_path = "IND-EAmpty\\PhaseClock\\FFT_PhaseClock_WAVE_ATR_-sinflipLike_SHAPED_PHASE_PCT";
   m_pricezz_path = "ZigzagColor";
   m_btick_loaded = false;
   m_atr_loaded = false;
   m_phase_loaded = false;
   m_pricezz_loaded = false;
   m_last_cross_bar = 0;
   m_last_cross_time = 0;
   m_last_cross_dir = 0;
   m_last_state_bar = 0;
   m_consec_buy3 = 0;
   m_consec_sell3 = 0;
   m_live_dir = 0;
   m_live_bar = 0;
   m_live_start = 0;
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

   if(m_cfg.AttachPhaseClock)
   {
      m_phase_handle = iCustom(_Symbol, m_tf, m_phase_path);
      if(m_phase_handle == INVALID_HANDLE)
      {
         m_log.Error("PhaseClock handle failed.");
      }
      else
      {
         int win = m_cfg.PhaseClockWindow;
         if(win < 1) win = 1;
         if(ChartIndicatorAdd(0, win, m_phase_handle))
            m_phase_loaded = true;
         else
            m_log.Error("PhaseClock ChartIndicatorAdd failed.");
      }
   }

   if(m_cfg.AttachPriceZigZag)
   {
      m_pricezz_handle = iCustom(_Symbol, m_tf, m_pricezz_path);
      if(m_pricezz_handle == INVALID_HANDLE)
      {
         m_log.Error("Price ZigZag handle failed.");
      }
      else
      {
         int win = m_cfg.PriceZigZagWindow;
         if(win < 0) win = 0;
         if(ChartIndicatorAdd(0, win, m_pricezz_handle))
            m_pricezz_loaded = true;
         else
            m_log.Error("Price ZigZag ChartIndicatorAdd failed.");
      }
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
   if(m_phase_handle != INVALID_HANDLE)
   {
      IndicatorRelease(m_phase_handle);
      m_phase_handle = INVALID_HANDLE;
   }
   if(m_pricezz_handle != INVALID_HANDLE)
   {
      IndicatorRelease(m_pricezz_handle);
      m_pricezz_handle = INVALID_HANDLE;
   }
   m_sig.Deinit();
}
