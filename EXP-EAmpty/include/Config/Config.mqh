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
   int RunnerSLPoints;     // -1 = usar SLPoints
   int RunnerSLMinPoints;  // -1 = usar SLMinPoints
   int RunnerSLMaxPoints;  // -1 = usar SLMaxPoints
   int RunnerTPPoints;     // -1 = usar 1:1 (baseado no SL)

   bool HedgeStopEnabled;
   double HedgeExtraPips;
   double HedgeCoverPercent;
   int HedgeExpirationMinutes;
   bool AttachPhaseClock;
   bool BTickStateOnly;
   int PhaseClockWindow;
   int PhaseMaxBarsFromTurn;
   bool UsePhaseRule;
   bool AttachPriceZigZag;
   int PriceZigZagWindow;
   bool ZigZagShowPanel;
   bool ZigZagPreview;
   bool UseZigZagRule;
   bool UseADXWRule;
   bool AttachADXW;
   int ADXWWindow;
   int ADXWPeriod;
   int ADXWBelowBars;
   double ADXWMaxValue;
   int ADXWCrossLookback;
   bool ADXWRequireBelowThreshold;
   bool ADXWRequireCross;
   int SignalShift; // 0=bar 0, 1=bar 1 (closed bar)
   bool ShowChartStatus;
   bool ShowEntryPanel;
   bool PanelShowBTick;
   bool PanelShowPhase;
   bool PanelShowZigZag;
   int EntryPanelX;
   int EntryPanelY;
   bool ShowOrdersPanel;
   int OrdersPanelX;
   int OrdersPanelY;
   int OrdersPanelColumns;
   bool ShowConfigPanel;
   int ConfigPanelX;
   int ConfigPanelY;
   int MaxOpenPositions;
   bool ShowPriceStats;
   int PriceStatsXOffset;
   int PriceStatsYOffset;
   int PriceStatsBoxWidth;
   int PriceStatsBoxHeight;
   bool BarZeroHold;

   int LogLevel;
   bool PrintToJournal;
};

#endif
