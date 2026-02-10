#property strict
#property version   "1.000"

#include <Trade/Trade.mqh>
#include "include/EAData/EAData.mqh"
#include "include/Config/ConfigAll.mqh"
#include "include/Entry/EntryInit.mqh"
#include "include/Entry/EntryTick.mqh"
#include "include/Entry/EntryExit.mqh"
#include "include/Entry/EntryTradeEvents.mqh"

enum EStrategyPreset
{
   PRESET_DEFAULT = 0,
   PRESET_STOP_TP4_SL2 = 1
};

input group "Strategy"
input EStrategyPreset StrategyPreset = PRESET_DEFAULT;
input int EntryOffsetPoints = 1;

input group "Trading"
input bool AllowTrading = true;
input long MagicNumber = 20260205;
input double LotSize = 0.01;
input double MaxSpreadPips = 2.0;
input int DeviationPoints = 10;
input int NumOrders = 2;

input group "Orders - MAIN"
input bool UseTrailingATR = true;
input int TPPoints = 10;
input int SLPoints = 5;
input int SLMinPoints = 0;
input int SLMaxPoints = 0;
input int CloseSeqBars = 3;

input group "Orders - RUNNER"
input bool RunnerEnabled = true;
input int RunnerBEPoints = 0;
input int RunnerLockPoints = 1;
input int RunnerTrailStartPoints = 0;
input int RunnerTrailDistancePoints = 5;
input bool RunnerRemoveTPOnBE = true;
input int RunnerSLPoints = -1;    // -1 = usar SLPoints
input int RunnerSLMinPoints = -1; // -1 = usar SLMinPoints
input int RunnerSLMaxPoints = -1; // -1 = usar SLMaxPoints
input int RunnerTPPoints = -1;    // -1 = usar TP 1:1 baseado no SL

input group "Hedge"
input bool HedgeStopEnabled = false;
input double HedgeExtraPips = 2.0;
input double HedgeCoverPercent = 100.0;
input int HedgeExpirationMinutes = 0;

input group "Indicators - Central (VPC)"
input bool AttachPhaseClock = true;
input bool BTickStateOnly = true;  // somente buffers de estado do BTick
input bool UsePhaseRule = false;    // regra da fase
input bool AttachPriceZigZag = true;
input bool UseZigZagRule = true;    // regra do ZigZag (pivôs)
input bool UseADXWRule = true;      // regra do ADXW (buffers de estado)
input bool AttachADXW = false;      // anexar ADXW no grafico

input group "Indicator - PhaseClock"
input int PhaseClockWindow = 1;
input int PhaseMaxBarsFromTurn = 4; // distancia max em barras desde a ultima virada

input group "Indicator - ZigZag"
input int PriceZigZagWindow = 0;
input bool ZigZagShowPanel = false; // painel do ZZ (status)
input bool ZigZagPreview = false;   // preview na barra 0

input group "Indicator - ADXW"
input int ADXWWindow = 2;
input int ADXWPeriod = 14;
input int ADXWBelowBars = 3;        // X candles abaixo da linha contrária (pré-cruzamento)
input double ADXWMaxValue = 5.0;    // valor maximo (DI)
input int ADXWCrossLookback = 2;    // cruzamento até 0-2 candles antes
input bool ADXWRequireBelowThreshold = true;
input bool ADXWRequireCross = true;

input group "Panels"
input bool ShowChartStatus = false;
input bool ShowEntryPanel = true;
input bool PanelShowBTick = true;
input bool PanelShowPhase = true;
input bool PanelShowZigZag = true;
input int EntryPanelX = 10;
input int EntryPanelY = 10;
input bool ShowOrdersPanel = true;
input int OrdersPanelX = 380;
input int OrdersPanelY = 90;
input int OrdersPanelColumns = 2;
input bool ShowConfigPanel = true;
input int ConfigPanelX = 380;
input int ConfigPanelY = 10;
input int MaxOpenPositions = 2; // 0 = ilimitado
input bool ShowPriceStats = true;
input int PriceStatsXOffset = 1100;
input int PriceStatsYOffset = 20;
input int PriceStatsBoxWidth = 120;
input int PriceStatsBoxHeight = 80;
input bool BarZeroHold = true; // hold SOMENTE na barra 0

input group "Logging"
input int LogLevel = 1; // 0=ERR,1=INFO,2=DEBUG
input bool PrintToJournal = true;

namespace EAData
{
   SConfig cfg;
   CLogger log;
   CRisk risk;
   CExecution exec;
   CPositionManager pos;
   CBTickState sig;
   CStopLoss slm;

   int atrtrail_handle;
   int phase_handle;
   int pricezz_handle;
   int pricezz_attach_handle;
   int adxw_handle;
   int adxw_attach_handle;
   datetime last_signal_bar;
   int last_signal_dir;
   int last_sig_shift;
   ENUM_TIMEFRAMES tf;

   string btick_path;
   string atrtrail_path;
   string phase_path;
   string pricezz_path;
   string pricezz_attach_path;
   string adxw_path;
   bool btick_loaded;
   bool atr_loaded;
   bool phase_loaded;
   bool pricezz_loaded;
   datetime last_cross_bar;
   datetime last_cross_time;
   int last_cross_dir;
   datetime last_state_bar;
   datetime last_atr_block_bar;
   datetime btick_cross_bar;
   datetime btick_cross_time;
   int btick_cross_dir;
   int consec_buy3;
   int consec_sell3;
   int live_dir;
   datetime live_bar;
   datetime live_start;
   datetime last_price_stats_bar;
   ulong pos_ids[];
   string pos_tags[];
}

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
   cfg.RunnerSLPoints = RunnerSLPoints;
   cfg.RunnerSLMinPoints = RunnerSLMinPoints;
   cfg.RunnerSLMaxPoints = RunnerSLMaxPoints;
   cfg.RunnerTPPoints = RunnerTPPoints;
   cfg.HedgeStopEnabled = HedgeStopEnabled;
   cfg.HedgeExtraPips = HedgeExtraPips;
   cfg.HedgeCoverPercent = HedgeCoverPercent;
   cfg.HedgeExpirationMinutes = HedgeExpirationMinutes;
   cfg.AttachPhaseClock = AttachPhaseClock;
   cfg.BTickStateOnly = BTickStateOnly;
   cfg.PhaseClockWindow = PhaseClockWindow;
   cfg.PhaseMaxBarsFromTurn = PhaseMaxBarsFromTurn;
   cfg.UsePhaseRule = UsePhaseRule;
   cfg.AttachPriceZigZag = AttachPriceZigZag;
   cfg.PriceZigZagWindow = PriceZigZagWindow;
   cfg.ZigZagShowPanel = ZigZagShowPanel;
   cfg.ZigZagPreview = ZigZagPreview;
   cfg.UseZigZagRule = UseZigZagRule;
   cfg.UseADXWRule = UseADXWRule;
   cfg.AttachADXW = AttachADXW;
   cfg.ADXWWindow = ADXWWindow;
   cfg.ADXWPeriod = ADXWPeriod;
   cfg.ADXWBelowBars = ADXWBelowBars;
   cfg.ADXWMaxValue = ADXWMaxValue;
   cfg.ADXWCrossLookback = ADXWCrossLookback;
   cfg.ADXWRequireBelowThreshold = ADXWRequireBelowThreshold;
   cfg.ADXWRequireCross = ADXWRequireCross;
   cfg.SignalShift = 0; // bar0 fixo; BarZeroHold controla uso de bar1 no início
   cfg.ShowChartStatus = ShowChartStatus;
   cfg.ShowEntryPanel = ShowEntryPanel;
   cfg.PanelShowBTick = PanelShowBTick;
   cfg.PanelShowPhase = PanelShowPhase;
   cfg.PanelShowZigZag = PanelShowZigZag;
   cfg.EntryPanelX = EntryPanelX;
   cfg.EntryPanelY = EntryPanelY;
   cfg.ShowOrdersPanel = ShowOrdersPanel;
   cfg.OrdersPanelX = OrdersPanelX;
   cfg.OrdersPanelY = OrdersPanelY;
   cfg.OrdersPanelColumns = OrdersPanelColumns;
   cfg.ShowConfigPanel = ShowConfigPanel;
   cfg.ConfigPanelX = ConfigPanelX;
   cfg.ConfigPanelY = ConfigPanelY;
   cfg.MaxOpenPositions = MaxOpenPositions;
   cfg.ShowPriceStats = ShowPriceStats;
   cfg.PriceStatsXOffset = PriceStatsXOffset;
   cfg.PriceStatsYOffset = PriceStatsYOffset;
   cfg.PriceStatsBoxWidth = PriceStatsBoxWidth;
   cfg.PriceStatsBoxHeight = PriceStatsBoxHeight;
   cfg.BarZeroHold = BarZeroHold;
   cfg.LogLevel = LogLevel;
   cfg.PrintToJournal = PrintToJournal;

   if(!EntryInit(cfg))
      return INIT_FAILED;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EntryExit();
}

void OnTick()
{
   EntryTick();
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   EntryTradeEvents(trans, request, result);
}
