#ifndef __EA_OCO_EADATA_MQH__
#define __EA_OCO_EADATA_MQH__

#include "../Config/ConfigAll.mqh"
#include "../Logging/LoggingAll.mqh"
#include "../Risk/RiskAll.mqh"
#include "../Indicators/IndicatorsAll.mqh"
#include "../Trading/Orders/OrdersAll.mqh"
#include "../Trading/Positions/PositionsAll.mqh"

namespace EAData
{
   extern SConfig cfg;
   extern CLogger log;
   extern CRisk risk;
   extern CExecution exec;
   extern CPositionManager pos;
   extern CBTickState sig;
   extern CStopLoss slm;

   extern int atrtrail_handle;
   extern int phase_handle;
   extern int pricezz_handle;
   extern int pricezz_attach_handle;
   extern int adxw_handle;
   extern int adxw_attach_handle;
   extern datetime last_signal_bar;
   extern int last_signal_dir;
   extern int last_sig_shift;
   extern ENUM_TIMEFRAMES tf;

   extern string btick_path;
   extern string atrtrail_path;
   extern string phase_path;
   extern string pricezz_path;
   extern string pricezz_attach_path;
   extern string adxw_path;
   extern bool btick_loaded;
   extern bool atr_loaded;
   extern bool phase_loaded;
   extern bool pricezz_loaded;
   extern datetime last_cross_bar;
   extern datetime last_cross_time;
   extern int last_cross_dir;
   extern datetime last_state_bar;
   extern datetime last_atr_block_bar;
   extern datetime btick_cross_bar;
   extern datetime btick_cross_time;
   extern int btick_cross_dir;
   extern int consec_buy3;
   extern int consec_sell3;
   extern int live_dir;
   extern datetime live_bar;
   extern datetime live_start;
   extern datetime last_price_stats_bar;
   extern ulong pos_ids[];
   extern string pos_tags[];
}

#endif
