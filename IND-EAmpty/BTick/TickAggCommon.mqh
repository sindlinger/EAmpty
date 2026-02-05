// Common helpers for bar timing and pip size
#ifndef __TICK_AGG_COMMON_MQH__
#define __TICK_AGG_COMMON_MQH__

double PipSize()
{
   int d = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(d == 3 || d == 5) return _Point * 10.0;
   return _Point;
}

int PeriodSecondsSafe()
{
   int ps = PeriodSeconds(_Period);
   if(ps <= 0) ps = Period() * 60;
   if(ps <= 0) ps = 60;
   return ps;
}

long BarOpenMsc(const long tick_msc, const int period_sec)
{
   const long period_ms = (long)period_sec * 1000L;
   if(period_ms <= 0) return 0;
   return (tick_msc / period_ms) * period_ms;
}

bool SameBarMsc(const long t1_msc, const long t2_msc, const int period_sec)
{
   if(t1_msc <= 0 || t2_msc <= 0) return false;
   return (BarOpenMsc(t1_msc, period_sec) == BarOpenMsc(t2_msc, period_sec));
}

#endif
