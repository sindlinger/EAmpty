#ifndef __EA_OCO_EA_CONTROLLER_MQH__
#define __EA_OCO_EA_CONTROLLER_MQH__

#include <Trade/Trade.mqh>
#include "../Config/Config.mqh"
#include "../Utils/Logger.mqh"
#include "../Risk/Risk.mqh"
#include "../Broker/Broker.mqh"
#include "../Positions/PositionManager.mqh"
#include "../Signals/BTickState.mqh"
#include "../Stops/StopLoss.mqh"

class CEAController
{
private:
   SConfig m_cfg;
   CLogger m_log;
   CRisk m_risk;
   CBroker m_broker;
   CPositionManager m_pos;
   CBTickState m_sig;
   CStopLoss m_slm;

   int m_atrtrail_handle;
   datetime m_last_signal_bar;
   ENUM_TIMEFRAMES m_tf;

   string m_btick_path;
   string m_atrtrail_path;
   bool m_btick_loaded;
   bool m_atr_loaded;
   datetime m_last_cross_bar;
   datetime m_last_cross_time;
   int m_last_cross_dir;
   datetime m_last_state_bar;
   int m_consec_buy3;
   int m_consec_sell3;

public:
   CEAController();

   bool Init(const SConfig &cfg);
   void Deinit();
   void OnTick();

private:
   void UpdateSeqClose(const datetime bar_time);
   void ClosePositionsByType(const long type);
   void ApplyTrailing();
   bool GetTrailLevel(const int shift, double &level);
   void UpdateChartStatus();
};

#include "EAController.Init.mqh"
#include "EAController.OnTick.mqh"
#include "EAController.Exit.mqh"
#include "EAController.Trailing.mqh"
#include "EAController.Status.mqh"

#endif
