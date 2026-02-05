#property strict
#property version   "1.000"

#include <Trade/Trade.mqh>
#include "include/EA/EAController.mqh"
#include "include/Config/Config.mqh"

enum EStrategyPreset
{
   PRESET_DEFAULT = 0,
   PRESET_STOP_TP4_SL2 = 1
};

input EStrategyPreset StrategyPreset = PRESET_DEFAULT;
input int EntryOffsetPoints = 1;

input bool AllowTrading = true;
input long MagicNumber = 20260205;
input double LotSize = 0.01;
input double MaxSpreadPips = 2.0;
input int DeviationPoints = 10;
input int NumOrders = 2;

input bool UseTrailingATR = true;
input int TPPoints = 10;
input int SLPoints = 5;
input int SLMinPoints = 0;
input int SLMaxPoints = 0;
input int CloseSeqBars = 3;
input bool RunnerEnabled = true;
input int RunnerBEPoints = 0;
input int RunnerLockPoints = 1;
input int RunnerTrailStartPoints = 0;
input int RunnerTrailDistancePoints = 5;
input bool RunnerRemoveTPOnBE = true;

input int LogLevel = 1; // 0=ERR,1=INFO,2=DEBUG
input bool PrintToJournal = true;

static CEAController g_engine;

int OnInit()
{
   SConfig cfg;
   cfg.StrategyPreset = (int)StrategyPreset;
   cfg.EntryOffsetPoints = EntryOffsetPoints;
   cfg.AllowTrading = AllowTrading;
   cfg.MagicNumber = MagicNumber;
   cfg.LotSize = LotSize;
   cfg.MaxSpreadPips = MaxSpreadPips;
   cfg.DeviationPoints = DeviationPoints;
   cfg.NumOrders = NumOrders;
   cfg.UseTrailingATR = UseTrailingATR;
   cfg.TPPoints = TPPoints;
   cfg.SLPoints = SLPoints;
   cfg.SLMinPoints = SLMinPoints;
   cfg.SLMaxPoints = SLMaxPoints;
   cfg.CloseSeqBars = CloseSeqBars;
   cfg.RunnerEnabled = RunnerEnabled;
   cfg.RunnerBEPoints = RunnerBEPoints;
   cfg.RunnerLockPoints = RunnerLockPoints;
   cfg.RunnerTrailStartPoints = RunnerTrailStartPoints;
   cfg.RunnerTrailDistancePoints = RunnerTrailDistancePoints;
   cfg.RunnerRemoveTPOnBE = RunnerRemoveTPOnBE;
   cfg.LogLevel = LogLevel;
   cfg.PrintToJournal = PrintToJournal;

   if(!g_engine.Init(cfg))
      return INIT_FAILED;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   g_engine.Deinit();
}

void OnTick()
{
   g_engine.OnTick();
}
