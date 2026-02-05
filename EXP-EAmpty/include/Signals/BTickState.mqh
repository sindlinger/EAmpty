#ifndef __EA_OCO_SIGNAL_BTICK_MQH__
#define __EA_OCO_SIGNAL_BTICK_MQH__

class CBTickState
{
private:
   int m_handle;
   string m_path;
   string m_symbol;
   ENUM_TIMEFRAMES m_tf;
   double m_last_buy;
   double m_last_sell;
   int m_last_err;
   bool m_last_ok;

public:
   CBTickState() : m_handle(INVALID_HANDLE), m_last_buy(0.0), m_last_sell(0.0), m_last_err(0), m_last_ok(false) {}

   bool Init(const string symbol, const string path, const ENUM_TIMEFRAMES tf)
   {
      m_symbol = symbol;
      m_path = path;
      m_tf = tf;
      if(m_handle != INVALID_HANDLE)
         IndicatorRelease(m_handle);
      m_handle = iCustom(m_symbol, m_tf, m_path);
      m_last_ok = false;
      m_last_err = 0;
      return (m_handle != INVALID_HANDLE);
   }

   void Deinit()
   {
      if(m_handle != INVALID_HANDLE)
      {
         IndicatorRelease(m_handle);
         m_handle = INVALID_HANDLE;
      }
   }

   bool GetSignal(int &dir, datetime &bar_time)
   {
      dir = 0;
      bar_time = iTime(m_symbol, m_tf, 0);
      if(m_handle == INVALID_HANDLE) { m_last_ok = false; m_last_err = GetLastError(); return false; }

      double st_buy[1];
      double st_sell[1];
      if(CopyBuffer(m_handle, 2, 0, 1, st_buy) != 1) { m_last_ok = false; m_last_err = GetLastError(); return false; }
      if(CopyBuffer(m_handle, 3, 0, 1, st_sell) != 1) { m_last_ok = false; m_last_err = GetLastError(); return false; }

      m_last_buy = st_buy[0];
      m_last_sell = st_sell[0];
      m_last_ok = true;
      m_last_err = 0;

      if(st_buy[0] == 1.0)
         dir = 1;
      else if(st_sell[0] == -1.0)
         dir = -1;
      else
         dir = 0;

      return true;
   }

   double LastBuy() const { return m_last_buy; }
   double LastSell() const { return m_last_sell; }

   string DebugText() const
   {
      string ok = m_last_ok ? "OK" : "FAIL";
      return StringFormat("BTick buf: buy=%.6f sell=%.6f %s err=%d", m_last_buy, m_last_sell, ok, m_last_err);
   }
};

#endif
