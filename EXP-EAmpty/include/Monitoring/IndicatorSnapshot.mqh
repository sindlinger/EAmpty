#ifndef __EA_OCO_INDICATOR_SNAPSHOT_MQH__
#define __EA_OCO_INDICATOR_SNAPSHOT_MQH__

#include "IndicatorDecision.mqh"

namespace Monitoring
{
   struct SIndicatorSnapshot
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
      double btick_buy;
      double btick_sell;
      datetime updated_at;
   };

   static SIndicatorSnapshot g_ind_snapshot;

   inline void ResetIndicatorSnapshot()
   {
      g_ind_snapshot.dir = 0;
      g_ind_snapshot.bar_time = 0;
      g_ind_snapshot.sig_ok = -1;
      g_ind_snapshot.sig_shift = -1;
      g_ind_snapshot.hold = -1;
      g_ind_snapshot.phase_up = -1;
      g_ind_snapshot.phase_down = -1;
      g_ind_snapshot.phase_rule = -1;
      g_ind_snapshot.zz_high = -1;
      g_ind_snapshot.zz_low = -1;
      g_ind_snapshot.zz_rule = -1;
      g_ind_snapshot.adxw_rule = -1;
      g_ind_snapshot.phase_filter = -1;
      g_ind_snapshot.sig_unique = -1;
      g_ind_snapshot.btick_buy = 0.0;
      g_ind_snapshot.btick_sell = 0.0;
      g_ind_snapshot.updated_at = 0;
   }

   inline void UpdateIndicatorSnapshot(const SIndicatorDecision &dec,
                                       const double btick_buy,
                                       const double btick_sell)
   {
      g_ind_snapshot.dir = dec.dir;
      g_ind_snapshot.bar_time = dec.bar_time;
      g_ind_snapshot.sig_ok = dec.sig_ok;
      g_ind_snapshot.sig_shift = dec.sig_shift;
      g_ind_snapshot.hold = dec.hold;
      g_ind_snapshot.phase_up = dec.phase_up;
      g_ind_snapshot.phase_down = dec.phase_down;
      g_ind_snapshot.phase_rule = dec.phase_rule;
      g_ind_snapshot.zz_high = dec.zz_high;
      g_ind_snapshot.zz_low = dec.zz_low;
      g_ind_snapshot.zz_rule = dec.zz_rule;
      g_ind_snapshot.adxw_rule = dec.adxw_rule;
      g_ind_snapshot.phase_filter = dec.phase_filter;
      g_ind_snapshot.sig_unique = dec.sig_unique;
      g_ind_snapshot.btick_buy = btick_buy;
      g_ind_snapshot.btick_sell = btick_sell;
      g_ind_snapshot.updated_at = TimeCurrent();
   }

   inline void GetIndicatorSnapshot(SIndicatorSnapshot &out)
   {
      out = g_ind_snapshot;
   }
}

#endif
