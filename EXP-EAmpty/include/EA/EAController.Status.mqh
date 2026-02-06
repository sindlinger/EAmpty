void CEAController::UpdateChartStatus()
{
   if(!m_cfg.ShowChartStatus) return;
   string btick_file = m_btick_path + ".mq5";
   string atr_file = m_atrtrail_path + ".mq5";
   string ph_file = m_phase_path + ".mq5";
   string zz_file = m_pricezz_path + ".mq5";
   string s1 = StringFormat("ATR carregado no arquivo \"%s\": %s", atr_file, m_atr_loaded ? "OK" : "FAIL");
   string s2 = StringFormat("BTick carregado no arquivo \"%s\": %s", btick_file, m_btick_loaded ? "OK" : "FAIL");
   string s3 = StringFormat("PhaseClock carregado no arquivo \"%s\": %s", ph_file, m_phase_loaded ? "OK" : "FAIL");
   string s4 = StringFormat("ZigZag carregado no arquivo \"%s\": %s", zz_file, m_pricezz_loaded ? "OK" : "FAIL");
   string s5 = "Cruzamento BUY: -";
   if(m_last_cross_dir == 1)
   {
      string t_cross = TimeToString(m_last_cross_time, TIME_SECONDS);
      string t_bar = TimeToString(m_last_cross_bar, TIME_DATE|TIME_MINUTES);
      string t_now = TimeToString(TimeCurrent(), TIME_SECONDS);
      s5 = StringFormat("Cruzamento BUY às %s, na barra %s, agora %s", t_cross, t_bar, t_now);
   }
   string s6 = m_sig.DebugText();
   Comment(s1 + "\n" + s2 + "\n" + s3 + "\n" + s4 + "\n" + s5 + "\n" + s6);
}
