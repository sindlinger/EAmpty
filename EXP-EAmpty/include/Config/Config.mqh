#ifndef __EA_OCO_CONFIG_MQH__
#define __EA_OCO_CONFIG_MQH__

#include <Trade/Trade.mqh>

struct SConfig
{
   int StrategyPreset;
   int EntryOffsetPoints;

   bool AllowTrading;
   long MagicNumber;
   double LotSize;
   double MaxSpreadPips;
   int DeviationPoints;
   int NumOrders;

   bool UseTrailingATR;
   int TPPoints;
   int SLPoints;
   int SLMinPoints;
   int SLMaxPoints;
   int CloseSeqBars;
   bool RunnerEnabled;
   int RunnerBEPoints;
   int RunnerLockPoints;
   int RunnerTrailStartPoints;
   int RunnerTrailDistancePoints;
   bool RunnerRemoveTPOnBE;

   bool HedgeStopEnabled;
   double HedgeExtraPips;
   double HedgeCoverPercent;
   int HedgeExpirationMinutes;
   bool AttachPhaseClock;
   int PhaseClockWindow;

   int LogLevel;
   bool PrintToJournal;
};

#endif
