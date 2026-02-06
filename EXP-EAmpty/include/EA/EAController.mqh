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
   int m_phase_handle;
   datetime m_last_signal_bar;
   ENUM_TIMEFRAMES m_tf;

   string m_btick_path;
   string m_atrtrail_path;
   string m_phase_path;
   bool m_btick_loaded;
   bool m_atr_loaded;
   bool m_phase_loaded;
   datetime m_last_cross_bar;
   datetime m_last_cross_time;
   int m_last_cross_dir;
   datetime m_last_state_bar;
   int m_consec_buy3;
   int m_consec_sell3;
   int m_live_dir;
   datetime m_live_bar;
   datetime m_live_start;

public:
   CEAController();

   bool Init(const SConfig &cfg);
   void Deinit();
   void OnTick();
   void OnTradeTransaction(const MqlTradeTransaction &trans,
                           const MqlTradeRequest &request,
                           const MqlTradeResult &result);

private:
   void UpdateSeqClose(const datetime bar_time);
   void ManageRunner();
   void ClosePositionsByType(const long type);
   void ApplyTrailing();
   void UpdateHedgeStops();
   bool GetTrailLevel(const int shift, double &level);
   void UpdateChartStatus();
   string DealReasonText(const long reason) const;
};

#include "EAController.Init.mqh"
#include "EAController.OnTick.mqh"
#include "EAController.Exit.mqh"
#include "EAController.Runner.mqh"
#include "EAController.Trailing.mqh"
#include "EAController.Hedge.mqh"
#include "EAController.Status.mqh"
#include "EAController.Trades.mqh"

#endif
