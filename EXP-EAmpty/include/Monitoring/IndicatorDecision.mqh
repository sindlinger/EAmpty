#ifndef __EA_OCO_INDICATOR_DECISION_MQH__
#define __EA_OCO_INDICATOR_DECISION_MQH__

struct SIndicatorDecision
{
   int dir;
   datetime bar_time;
   int sig_ok;
   int sig_shift;
   int hold;
   int phase_up;
   int phase_down;
   int phase_rule;
   int zz_high;
   int zz_low;
   int zz_rule;
   int adxw_rule;
   int phase_filter;
   int sig_unique;
};

#endif
