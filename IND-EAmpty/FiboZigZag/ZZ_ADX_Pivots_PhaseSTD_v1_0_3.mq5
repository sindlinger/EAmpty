//+------------------------------------------------------------------+
//|                                                  ZigzagColor.mq5 |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
//--- indicator settings
#property indicator_chart_window
#property indicator_buffers 8
#property indicator_plots   4
#property indicator_type1   DRAW_COLOR_ZIGZAG
#property indicator_color1  clrDodgerBlue,clrRed
#define DASH_LINES 15
//--- input parameters
input int InpDepth    =10;  // Depth
input int InpDeviation=5;   // Deviation
input int InpBackstep =3;   // Back Step
input int InpAdxPeriod=2;   // ADXW Period
input string InpAdxPath="IND-EAmpty\\FiboZigZag\\ADXW_v1.0"; // ADXW path (Indicators)
input int InpPivotTol=4;    // Tolerancia do padrao 1-2-3 (quantos candles atras)
input int InpAdxMinBelowBars=3; // ADX: barras minimas abaixo antes do cruzamento
input bool InpUsePhaseStd=true; // Usar PhaseSTD como filtro extra
input string InpPhaseStdPath="IND-EAmpty\\PhaseClock-CloseStdDev\\PhaseClock-CloseStdDev_v1"; // PhaseSTD path (Indicators)
input bool InpShowPhaseWave=true; // Mostrar wave do PhaseSTD
input color InpPhaseWaveColor=clrMagenta;
input int  InpPhaseWaveWidth=1;
input string InpTextTopo="topo";
input string InpTextFundo="fundo";
input bool InpPreview=true;      // Preview na barra 0
input string InpPreviewPrefix="~"; // Prefixo do preview (barra 0)
input int InpTextOffsetPts=30;   // Offset do texto (points)
input int InpPivotLookback=500;  // Lookback para ultimo pivô no painel
input color InpTextColorTopo=clrLime;
input color InpTextColorFundo=clrTomato;
input int InpTextFont=9;
input string InpTextFontName="Consolas";
input bool InpShowStatus=true; // Mostrar status no canto do grafico
input bool InpShowStats=false;  // Mostrar estatisticas no painel/contadores
input int  InpDashX=10;
input int  InpDashY=170;
input int  InpDashFont=9;

//--- cores (cada tipo com cor propria: TRUE = acesa, FALSE = apagada)
#define COL_NOPIVOT_TRUE   C'0,200,255'
#define COL_NOPIVOT_FALSE  C'90,90,90'
#define COL_ADX_TRUE       C'0,120,255'
#define COL_ADX_FALSE      C'70,90,120'
#define COL_PATTERN_TRUE   C'255,140,0'
#define COL_PATTERN_FALSE  C'160,110,60'
#define COL_PHASE_TRUE     C'255,215,0'
#define COL_PHASE_FALSE    C'140,120,40'
#define COL_SIGNAL_TRUE    C'0,255,120'
#define COL_SIGNAL_FALSE   C'80,120,80'

// força configuração interna (ignora inputs antigos)
const bool USE_PHASE_STD = true;
const bool SHOW_PHASE_WAVE = true;
//--- indicator buffers
double ZigzagPeakBuffer[];
double ZigzagBottomBuffer[];
double ColorBuffer[];
double TopoCountBuffer[];
double FundoCountBuffer[];
double HighMapBuffer[];
double LowMapBuffer[];
double PhaseWaveBuffer[];

int    g_adx_handle = INVALID_HANDLE;
int    g_phase_handle = INVALID_HANDLE;
bool   g_phase_attached = false;
string g_phase_shortname = "FFT_PhaseClock_CLOSE_HighFFT_BarClose_v1.0";
long   g_chart_id = 0;
datetime g_last_topo_time = 0;
datetime g_last_fundo_time = 0;
string g_instance_tag = "";
datetime g_count_start_time = 0;
bool   g_count_started = false;

int ExtRecalc=3; // recounting's depth

enum EnSearchMode
  {
   Extremum=0, // searching for the first extremum
   Peak=1,     // searching for the next ZigZag peak
   Bottom=-1   // searching for the next ZigZag bottom
  };
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0,ZigzagPeakBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,ZigzagBottomBuffer,INDICATOR_DATA);
   SetIndexBuffer(2,ColorBuffer,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(3,TopoCountBuffer,INDICATOR_DATA);
   SetIndexBuffer(4,FundoCountBuffer,INDICATOR_DATA);
   SetIndexBuffer(5,HighMapBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(6,LowMapBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(7,PhaseWaveBuffer,INDICATOR_DATA);
   PlotIndexSetInteger(1,PLOT_DRAW_TYPE,DRAW_NONE);
   PlotIndexSetInteger(2,PLOT_DRAW_TYPE,DRAW_NONE);
   PlotIndexSetString(1,PLOT_LABEL,"TopoCount");
   PlotIndexSetString(2,PLOT_LABEL,"FundoCount");
   PlotIndexSetInteger(3,PLOT_DRAW_TYPE,DRAW_NONE);
   PlotIndexSetString(3,PLOT_LABEL,"PhaseSTD Wave");
//--- set accuracy
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
//--- name for DataWindow and indicator subwindow label
   string short_name=StringFormat("ZZ_ADX_Pivots_PhaseSTD v1.0.3 (%d,%d,%d)",InpDepth,InpDeviation,InpBackstep);
   IndicatorSetString(INDICATOR_SHORTNAME,short_name);
   PlotIndexSetString(0,PLOT_LABEL,short_name);
//--- set an empty value
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,0.0);
   PlotIndexSetDouble(1,PLOT_EMPTY_VALUE,0.0);
   PlotIndexSetDouble(2,PLOT_EMPTY_VALUE,0.0);
   PlotIndexSetDouble(3,PLOT_EMPTY_VALUE,EMPTY_VALUE);

   // ADXW handle
   g_adx_handle = iCustom(_Symbol, _Period, InpAdxPath, InpAdxPeriod);

   if(USE_PHASE_STD || SHOW_PHASE_WAVE)
     {
      g_phase_handle = iCustom(_Symbol, _Period, InpPhaseStdPath);
      if(SHOW_PHASE_WAVE && g_phase_handle != INVALID_HANDLE)
        {
         int w = ChartWindowFind(0, g_phase_shortname);
         if(w < 0)
           {
            int win_total = (int)ChartGetInteger(0, CHART_WINDOWS_TOTAL);
            int subwin_try[3];
            subwin_try[0] = win_total;
            subwin_try[1] = (win_total > 1 ? win_total-1 : 1);
            subwin_try[2] = 1;
            bool attached = false;
            for(int si=0; si<3 && !attached; si++)
              {
               if(subwin_try[si] < 0) continue;
               if(ChartIndicatorAdd(0, subwin_try[si], g_phase_handle))
                 {
                  attached = true;
                  g_phase_attached = true;
                  ChartRedraw(0);
                 }
              }
            if(!attached)
              {
               int err = GetLastError();
               Print("PhaseSTD: ChartIndicatorAdd falhou. Err=", err);
               ResetLastError();
              }
           }
         else
           {
            g_phase_attached = true;
           }
        }
     }


   g_instance_tag = IntegerToString((int)ChartID()) + "_" + IntegerToString((int)GetTickCount());

   if(InpShowStatus)
      DashEnsure();
   DeleteLegacyLabels();
   g_count_started = false;
   g_count_start_time = 0;
  }

void OnDeinit(const int reason)
  {
   if(g_adx_handle != INVALID_HANDLE)
     {
      IndicatorRelease(g_adx_handle);
      g_adx_handle = INVALID_HANDLE;
     }
   if(g_phase_attached)
     {
      int w = ChartWindowFind(0, g_phase_shortname);
      if(w >= 0)
         ChartIndicatorDelete(0, w, g_phase_shortname);
      g_phase_attached = false;
     }
   if(g_phase_handle != INVALID_HANDLE)
     {
      IndicatorRelease(g_phase_handle);
      g_phase_handle = INVALID_HANDLE;
     }
   DeletePreviewAll();
   if(InpShowStatus)
      DashDeleteAll();
   DeleteLegacyLabels();
  }
//+------------------------------------------------------------------+
//| ZigZag calculation                                               |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if(rates_total<100)
      return(0);
   bool series = ArrayGetAsSeries(close);
//---
   int    i,start=0;
   int    extreme_counter=0,extreme_search=Extremum;
   int    shift,back=0,last_high_pos=0,last_low_pos=0;
   double val=0,res=0;
   double cur_low=0,cur_high=0,last_high=0,last_low=0;
//--- initializing
   if(prev_calculated==0)
     {
      ArrayInitialize(ZigzagPeakBuffer,0.0);
      ArrayInitialize(ZigzagBottomBuffer,0.0);
      ArrayInitialize(TopoCountBuffer,0.0);
      ArrayInitialize(FundoCountBuffer,0.0);
      ArrayInitialize(HighMapBuffer,0.0);
      ArrayInitialize(LowMapBuffer,0.0);
      ArrayInitialize(PhaseWaveBuffer,EMPTY_VALUE);

      //--- start calculation from bar number InpDepth
      start=InpDepth-1;
     }
//--- ZigZag was already calculated before
   if(prev_calculated>0)
     {
      i=rates_total-1;
      //--- searching for the third extremum from the last uncompleted bar
      while(extreme_counter<ExtRecalc && i>rates_total -100)
        {
         res=(ZigzagPeakBuffer[i]+ZigzagBottomBuffer[i]);
         //---
         if(res!=0)
            extreme_counter++;
         i--;
        }
      i++;
      start=i;
      //--- what type of exremum we search for
      if(LowMapBuffer[i]!=0)
        {
         cur_low=LowMapBuffer[i];
         extreme_search=Peak;
        }
      else
        {
         cur_high=HighMapBuffer[i];
         extreme_search=Bottom;
        }
      //--- clear indicator values
      for(i=start+1; i<rates_total && !IsStopped(); i++)
        {
         ZigzagPeakBuffer[i]  =0.0;
         ZigzagBottomBuffer[i]=0.0;
         LowMapBuffer[i]      =0.0;
         HighMapBuffer[i]     =0.0;
        }
     }
//--- searching for high and low extremes
   for(shift=start; shift<rates_total && !IsStopped(); shift++)
     {
      //--- low
      val=Lowest(low,InpDepth,shift);
      if(val==last_low)
         val=0.0;
      else
        {
         last_low=val;
         if((low[shift]-val)>(InpDeviation*_Point))
            val=0.0;
         else
           {
            for(back=InpBackstep; back>=1; back--)
              {
               res=LowMapBuffer[shift-back];
               //---
               if((res!=0) && (res>val))
                  LowMapBuffer[shift-back]=0.0;
              }
           }
        }
      if(low[shift]==val)
         LowMapBuffer[shift]=val;
      else
         LowMapBuffer[shift]=0.0;
      //--- high
      val=Highest(high,InpDepth,shift);
      if(val==last_high)
         val=0.0;
      else
        {
         last_high=val;
         if((val-high[shift])>(InpDeviation*_Point))
            val=0.0;
         else
           {
            for(back=InpBackstep; back>=1; back--)
              {
               res=HighMapBuffer[shift-back];
               //---
               if((res!=0) && (res<val))
                  HighMapBuffer[shift-back]=0.0;
              }
           }
        }
      if(high[shift]==val)
         HighMapBuffer[shift]=val;
      else
         HighMapBuffer[shift]=0.0;
     }
//--- set last values
   if(extreme_search==0) // undefined values
     {
      last_low=0;
      last_high=0;
     }
   else
     {
      last_low=cur_low;
      last_high=cur_high;
     }
//--- final selection of extreme points for ZigZag
   for(shift=start; shift<rates_total && !IsStopped(); shift++)
     {
      res=0.0;
      switch(extreme_search)
        {
         case Extremum:
            if(last_low==0 && last_high==0)
              {
               if(HighMapBuffer[shift]!=0)
                 {
                  last_high=high[shift];
                  last_high_pos=shift;
                  extreme_search=-1;
                  ZigzagPeakBuffer[shift]=last_high;
                  ColorBuffer[shift]=0;
                  res=1;
                 }
               if(LowMapBuffer[shift]!=0)
                 {
                  last_low=low[shift];
                  last_low_pos=shift;
                  extreme_search=1;
                  ZigzagBottomBuffer[shift]=last_low;
                  ColorBuffer[shift]=1;
                  res=1;
                 }
              }
            break;
         case Peak:
            if(LowMapBuffer[shift]!=0.0 && LowMapBuffer[shift]<last_low &&
               HighMapBuffer[shift]==0.0)
              {
               ZigzagBottomBuffer[last_low_pos]=0.0;
               last_low_pos=shift;
               last_low=LowMapBuffer[shift];
               ZigzagBottomBuffer[shift]=last_low;
               ColorBuffer[shift]=1;
               res=1;
              }
            if(HighMapBuffer[shift]!=0.0 && LowMapBuffer[shift]==0.0)
              {
               last_high=HighMapBuffer[shift];
               last_high_pos=shift;
               ZigzagPeakBuffer[shift]=last_high;
               ColorBuffer[shift]=0;
               extreme_search=Bottom;
               res=1;
              }
            break;
         case Bottom:
            if(HighMapBuffer[shift]!=0.0 &&
               HighMapBuffer[shift]>last_high &&
               LowMapBuffer[shift]==0.0)
              {
               ZigzagPeakBuffer[last_high_pos]=0.0;
               last_high_pos=shift;
               last_high=HighMapBuffer[shift];
               ZigzagPeakBuffer[shift]=last_high;
               ColorBuffer[shift]=0;
              }
            if(LowMapBuffer[shift]!=0.0 && HighMapBuffer[shift]==0.0)
              {
               last_low=LowMapBuffer[shift];
               last_low_pos=shift;
               ZigzagBottomBuffer[shift]=last_low;
               ColorBuffer[shift]=1;
               extreme_search=Peak;
              }
            break;
         default:
            return(rates_total);
        }
     }

   // PhaseSTD buffers completos para filtro/painel
   double ph_wave[], ph_up[], ph_low[];
   bool have_phase = false;
   int phase_count = 0;
   if((USE_PHASE_STD || SHOW_PHASE_WAVE) && g_phase_handle != INVALID_HANDLE)
     {
      ArrayResize(ph_wave, rates_total);
      ArrayResize(ph_up, rates_total);
      ArrayResize(ph_low, rates_total);
      ArraySetAsSeries(ph_wave, true);
      ArraySetAsSeries(ph_up, true);
      ArraySetAsSeries(ph_low, true);
      int gotw = CopyBuffer(g_phase_handle, 0, 0, rates_total, ph_wave);
      int gotu = CopyBuffer(g_phase_handle, 5, 0, rates_total, ph_up);
      int gotl = CopyBuffer(g_phase_handle, 6, 0, rates_total, ph_low);
      phase_count = MathMin(gotw, MathMin(gotu, gotl));
      have_phase = (phase_count > 0);
     }
      if(SHOW_PHASE_WAVE)
     {
      if(have_phase)
        {
         int lim = MathMin(rates_total, phase_count);
         for(int i=0; i<lim; i++)
            PhaseWaveBuffer[i] = ph_wave[i];
         for(int i=lim; i<rates_total; i++)
            PhaseWaveBuffer[i] = EMPTY_VALUE;
        }
      else
        {
         ArrayInitialize(PhaseWaveBuffer, EMPTY_VALUE);
        }
     }
   else
     {
      if(prev_calculated==0)
         ArrayInitialize(PhaseWaveBuffer, EMPTY_VALUE);
     }

//--- Contagem de barras desde o ultimo pivô (Data Window) + estatísticas
   int total_top=0, total_bottom=0, hit_top=0, hit_bottom=0;
   int eval_top=0, eval_bottom=0;
   int sum_top=0, sum_bottom=0;
   int runs_top=0, runs_bottom=0;
   double avg_top=0.0, avg_bottom=0.0;
   double hit_top_rate=0.0, hit_bottom_rate=0.0;
   static bool last_show_stats=false;

   if(InpShowStats)
     {
      if(!g_count_started)
        {
         g_count_start_time = time[IdxSeries(0, rates_total, series)];
         g_count_started = true;
        }
      ArrayInitialize(TopoCountBuffer,0.0);
      ArrayInitialize(FundoCountBuffer,0.0);
      int dir = 0; // 1 = fundo (alta), -1 = topo (baixa)
      int cnt = 0;
      int bad_cnt = 0;
      double pivot_close = 0.0;

      // ADX buffers completos para estatística de sinais (não mexe no pivô)
      double pdi_all[], ndi_all[];
      bool have_adx = false;
      if(g_adx_handle != INVALID_HANDLE)
        {
         ArrayResize(pdi_all, rates_total);
         ArrayResize(ndi_all, rates_total);
         ArraySetAsSeries(pdi_all, true);
         ArraySetAsSeries(ndi_all, true);
         int got1 = CopyBuffer(g_adx_handle, 1, 0, rates_total, pdi_all);
         int got2 = CopyBuffer(g_adx_handle, 2, 0, rates_total, ndi_all);
         have_adx = (got1 > 0 && got2 > 0);
        }

      for(int s=rates_total-1; s>=1; s--)
        {
         int k = IdxSeries(s, rates_total, series);
         if(time[k] < g_count_start_time)
            continue;
         // Detecta sinal histórico (topo/fundo) usando as mesmas regras do pivô
         bool sig_top = false;
         bool sig_bottom = false;
         if(have_adx)
           {
            int tol = InpPivotTol;
            if(tol < 1) tol = 1;
            int min_bars = InpAdxMinBelowBars;
            if(min_bars < 1) min_bars = 1;
            if(s+tol+1 < rates_total && s+min_bars+1 < rates_total)
              {
               bool curr_is_pivot = (ZigzagPeakBuffer[k] != 0.0 || ZigzagBottomBuffer[k] != 0.0);
               if(!curr_is_pivot)
                 {
                  bool piv_high=false, piv_low=false;
                  for(int off=1; off<=tol; off++)
                    {
                     int p = s + off;
                     if(p+1 >= rates_total || p-1 < 0) continue;
                     int kp = IdxSeries(p, rates_total, series);
                     int kp1 = IdxSeries(p+1, rates_total, series);
                     int km1 = IdxSeries(p-1, rates_total, series);
                     if(high[kp1] < high[kp] && high[km1] < high[kp]) piv_high = true;
                     if(low[kp1]  > low[kp]  && low[km1]  > low[kp])  piv_low  = true;
                     if(piv_high || piv_low) break;
                    }

                  bool cross_up = (pdi_all[s] > ndi_all[s] && pdi_all[s+1] <= ndi_all[s+1]);
                  bool cross_dn = (ndi_all[s] > pdi_all[s] && ndi_all[s+1] <= ndi_all[s+1]);
                  bool pre_up = AdxBelowForBars(pdi_all, ndi_all, s, min_bars);
                  bool pre_dn = AdxBelowForBars(ndi_all, pdi_all, s, min_bars);
                  bool candle_top_ok = (close[k] < open[k]);    // topo só em candle de baixa
                  bool candle_bottom_ok = (close[k] > open[k]); // fundo só em candle de alta

                  bool phase_top_ok = !USE_PHASE_STD;
                  bool phase_bottom_ok = !USE_PHASE_STD;
                  if(USE_PHASE_STD)
                    {
                     if(have_phase && s < phase_count)
                       {
                        double w = ph_wave[s];
                        double up = ph_up[s];
                        double lo = ph_low[s];
                        if(w != EMPTY_VALUE && up != EMPTY_VALUE && lo != EMPTY_VALUE)
                          {
                           phase_top_ok = (w > up);
                           phase_bottom_ok = (w < lo);
                          }
                        else
                          {
                           phase_top_ok = false;
                           phase_bottom_ok = false;
                          }
                       }
                     else
                       {
                        phase_top_ok = false;
                        phase_bottom_ok = false;
                       }
                    }

                  sig_bottom = (cross_up && piv_low && pre_up && candle_bottom_ok && phase_bottom_ok);
                  sig_top = (cross_dn && piv_high && pre_dn && candle_top_ok && phase_top_ok);
                 }
              }
           }
         if(sig_top && sig_bottom)
           {
            sig_top = false;
            sig_bottom = false;
           }
         if(sig_top)
           {
            FinalizeRunStats(dir, cnt, runs_top, runs_bottom, sum_top, sum_bottom);
            total_top++;
            if(s > 0)
              {
               int k_next = IdxSeries(s-1, rates_total, series);
               eval_top++;
               if(close[k_next] < close[k]) hit_top++;
              }
            dir = -1;
            cnt = 1;
            bad_cnt = 0;
            pivot_close = close[k];
            TopoCountBuffer[k] = -cnt;
            FundoCountBuffer[k] = 0.0;
           }
         else if(sig_bottom)
           {
            FinalizeRunStats(dir, cnt, runs_top, runs_bottom, sum_top, sum_bottom);
            total_bottom++;
            if(s > 0)
              {
               int k_next = IdxSeries(s-1, rates_total, series);
               eval_bottom++;
               if(close[k_next] > close[k]) hit_bottom++;
              }
            dir = 1;
            cnt = 1;
            bad_cnt = 0;
            pivot_close = close[k];
            FundoCountBuffer[k] = cnt;
            TopoCountBuffer[k] = 0.0;
           }
         else
           {
            if(dir == 1)
              {
               // invalida se fechar abaixo do close do pivô de fundo por 2 fechamentos seguidos
               if(close[k] < pivot_close) bad_cnt++; else bad_cnt = 0;
               if(bad_cnt >= 2)
                 {
                  FinalizeRunStats(dir, cnt, runs_top, runs_bottom, sum_top, sum_bottom);
                  dir = 0;
                  cnt = 0;
                  bad_cnt = 0;
                  FundoCountBuffer[k] = 0.0;
                  TopoCountBuffer[k] = 0.0;
                 }
               else
                 {
                  cnt++;
                  FundoCountBuffer[k] = cnt;
                 }
              }
            else if(dir == -1)
              {
               // invalida se fechar acima do close do pivô de topo por 2 fechamentos seguidos
               if(close[k] > pivot_close) bad_cnt++; else bad_cnt = 0;
               if(bad_cnt >= 2)
                 {
                  FinalizeRunStats(dir, cnt, runs_top, runs_bottom, sum_top, sum_bottom);
                  dir = 0;
                  cnt = 0;
                  bad_cnt = 0;
                  FundoCountBuffer[k] = 0.0;
                  TopoCountBuffer[k] = 0.0;
                 }
               else
                 {
                  cnt++;
                  TopoCountBuffer[k] = -cnt;
                 }
              }
           }
        }
      FinalizeRunStats(dir, cnt, runs_top, runs_bottom, sum_top, sum_bottom);
      avg_top = (runs_top>0 ? (double)sum_top/runs_top : 0.0);
      avg_bottom = (runs_bottom>0 ? (double)sum_bottom/runs_bottom : 0.0);
      hit_top_rate = (eval_top>0 ? 100.0*hit_top/eval_top : 0.0);
      hit_bottom_rate = (eval_bottom>0 ? 100.0*hit_bottom/eval_bottom : 0.0);
     }
   else
     {
      if(prev_calculated==0 || last_show_stats)
        {
         ArrayInitialize(TopoCountBuffer,0.0);
         ArrayInitialize(FundoCountBuffer,0.0);
        }
      g_count_started = false;
      g_count_start_time = 0;
     }
   last_show_stats = InpShowStats;
//--- ADX cross confirmation
   bool status_ok = false;
   bool s_no_pivot=false, s_cross_up=false, s_cross_dn=false, s_piv_low=false, s_piv_high=false, s_up=false, s_dn=false;
   bool s_adx_pre_up=false, s_adx_pre_dn=false;
   bool s_candle_top_ok=false, s_candle_bottom_ok=false;
   bool s_phase_top_ok=false, s_phase_bottom_ok=false;
   bool s_pivot_high0=false, s_pivot_low0=false, s_has_pivot=false;
   double s_buf0_val=0.0, s_buf1_val=0.0;
   int s_last_high_shift=-1, s_last_low_shift=-1;
   double s_last_high=0.0, s_last_low=0.0;
   string s_last_high_time="", s_last_low_time="";

   if(rates_total > 0)
     {
      int i0 = IdxSeries(0, rates_total, series);
      s_buf0_val = ZigzagPeakBuffer[i0];
      s_buf1_val = ZigzagBottomBuffer[i0];
      s_pivot_high0 = (s_buf0_val != 0.0);
      s_pivot_low0  = (s_buf1_val != 0.0);
      s_has_pivot   = (s_pivot_high0 || s_pivot_low0);

      int lookback = InpPivotLookback;
      if(lookback < 1) lookback = 1;
      if(lookback > rates_total-1) lookback = rates_total-1;
      for(int s=0; s<=lookback; s++)
        {
         int k = IdxSeries(s, rates_total, series);
         if(s_last_high_shift == -1 && ZigzagPeakBuffer[k] != 0.0)
           {
            s_last_high_shift = s;
            s_last_high = ZigzagPeakBuffer[k];
            s_last_high_time = TimeToString(time[k], TIME_DATE|TIME_MINUTES);
           }
         if(s_last_low_shift == -1 && ZigzagBottomBuffer[k] != 0.0)
           {
            s_last_low_shift = s;
            s_last_low = ZigzagBottomBuffer[k];
            s_last_low_time = TimeToString(time[k], TIME_DATE|TIME_MINUTES);
           }
         if(s_last_high_shift != -1 && s_last_low_shift != -1) break;
        }
     }

   if(g_adx_handle != INVALID_HANDLE)
     {
      double pdi[], ndi[];
      int need = rates_total;
      ArrayResize(pdi, need);
      ArrayResize(ndi, need);
      ArraySetAsSeries(pdi, true);
      ArraySetAsSeries(ndi, true);

      int got1 = CopyBuffer(g_adx_handle, 1, 0, need, pdi); // +DI
      int got2 = CopyBuffer(g_adx_handle, 2, 0, need, ndi); // -DI
      int min_bars = InpAdxMinBelowBars;
      if(min_bars < 1) min_bars = 1;
      if(got1 > min_bars+1 && got2 > min_bars+1)
        {
         // --- Só avalia a BARRA 0 para painel (tempo real) ---
         int i=0;
         int tol = InpPivotTol;
         if(tol < 1) tol = 1;
         if(i+tol+1 < rates_total)
           {
            // status (barra 0)
            int i0 = IdxSeries(i, rates_total, series);
            bool curr_is_pivot = (ZigzagPeakBuffer[i0] != 0.0 || ZigzagBottomBuffer[i0] != 0.0);
            s_no_pivot = !curr_is_pivot;
            s_candle_top_ok = (close[i0] < open[i0]);    // topo só em candle de baixa
            s_candle_bottom_ok = (close[i0] > open[i0]); // fundo só em candle de alta

            s_piv_high = false;
            s_piv_low  = false;
            for(int off=1; off<=tol; off++)
              {
               int p = i + off;
               if(p+1 >= rates_total || p-1 < 0) continue;
               int kp = IdxSeries(p, rates_total, series);
               int kp1 = IdxSeries(p+1, rates_total, series);
               int km1 = IdxSeries(p-1, rates_total, series);
               if(high[kp1] < high[kp] && high[km1] < high[kp]) s_piv_high = true;
               if(low[kp1]  > low[kp]  && low[km1]  > low[kp])  s_piv_low  = true;
               if(s_piv_high || s_piv_low) break;
              }

            s_cross_up = (pdi[i] > ndi[i] && pdi[i+1] <= ndi[i+1]);
            s_cross_dn = (ndi[i] > pdi[i] && ndi[i+1] <= pdi[i+1]);

            s_adx_pre_up = AdxBelowForBars(pdi, ndi, i, min_bars);
            s_adx_pre_dn = AdxBelowForBars(ndi, pdi, i, min_bars);

            s_phase_top_ok = !USE_PHASE_STD;
            s_phase_bottom_ok = !USE_PHASE_STD;
            if(USE_PHASE_STD)
              {
               if(have_phase && i < phase_count)
                 {
                  double w = ph_wave[i];
                  double up = ph_up[i];
                  double lo = ph_low[i];
                  if(w != EMPTY_VALUE && up != EMPTY_VALUE && lo != EMPTY_VALUE)
                    {
                     s_phase_top_ok = (w > up);
                     s_phase_bottom_ok = (w < lo);
                    }
                  else
                    {
                     s_phase_top_ok = false;
                     s_phase_bottom_ok = false;
                    }
                 }
               else
                 {
                  s_phase_top_ok = false;
                  s_phase_bottom_ok = false;
                 }
              }

            s_up = (s_no_pivot && s_cross_up && s_piv_low && s_adx_pre_up && s_candle_bottom_ok && s_phase_bottom_ok);
            s_dn = (s_no_pivot && s_cross_dn && s_piv_high && s_adx_pre_dn && s_candle_top_ok && s_phase_top_ok);
            status_ok = true;
           }
        }
     }

   // --- SINAL DEFINITIVO: só no fechamento do candle 0 (isto é, quando virar candle) ---
   static datetime last_bar_time = 0;
   if(rates_total > 3 && time[IdxSeries(0, rates_total, series)] != last_bar_time)
     {
      last_bar_time = time[IdxSeries(0, rates_total, series)];
      int i=1; // último candle fechado
      int tol = InpPivotTol;
      if(tol < 1) tol = 1;
      if(g_adx_handle != INVALID_HANDLE && i+tol+1 < rates_total)
        {
         double pdi0[], ndi0[];
         ArrayResize(pdi0, i+tol+2);
         ArrayResize(ndi0, i+tol+2);
         ArraySetAsSeries(pdi0, true);
         ArraySetAsSeries(ndi0, true);
         int got1b = CopyBuffer(g_adx_handle, 1, 0, i+tol+2, pdi0);
         int got2b = CopyBuffer(g_adx_handle, 2, 0, i+tol+2, ndi0);
         int min_bars = InpAdxMinBelowBars;
         if(min_bars < 1) min_bars = 1;
         if(got1b > i+min_bars+1 && got2b > i+min_bars+1)
           {
            int i1 = IdxSeries(i, rates_total, series);
            bool candle_top_ok = (close[i1] < open[i1]);    // topo só em candle de baixa
            bool candle_bottom_ok = (close[i1] > open[i1]); // fundo só em candle de alta
            bool curr_is_pivot = (ZigzagPeakBuffer[i1] != 0.0 || ZigzagBottomBuffer[i1] != 0.0);
            if(!curr_is_pivot)
              {
               bool pivot_high = false;
               bool pivot_low  = false;
               for(int off=1; off<=tol; off++)
                 {
                  int p = i + off;
                  if(p+1 >= rates_total || p-1 < 0) continue;
                  int kp = IdxSeries(p, rates_total, series);
                  int kp1 = IdxSeries(p+1, rates_total, series);
                  int km1 = IdxSeries(p-1, rates_total, series);
                  if(high[kp1] < high[kp] && high[km1] < high[kp]) pivot_high = true;
                  if(low[kp1]  > low[kp]  && low[km1]  > low[kp])  pivot_low  = true;
                  if(pivot_high || pivot_low) break;
                 }

               bool cross_up = (pdi0[i] > ndi0[i] && pdi0[i+1] <= ndi0[i+1]);
               bool cross_dn = (ndi0[i] > pdi0[i] && ndi0[i+1] <= pdi0[i+1]);
               bool pre_up = AdxBelowForBars(pdi0, ndi0, i, min_bars);
               bool pre_dn = AdxBelowForBars(ndi0, pdi0, i, min_bars);

               bool phase_top_ok = !USE_PHASE_STD;
               bool phase_bottom_ok = !USE_PHASE_STD;
               if(USE_PHASE_STD)
                 {
                  if(have_phase && i < phase_count)
                    {
                     double w = ph_wave[i];
                     double up = ph_up[i];
                     double lo = ph_low[i];
                     if(w != EMPTY_VALUE && up != EMPTY_VALUE && lo != EMPTY_VALUE)
                       {
                        phase_top_ok = (w > up);
                        phase_bottom_ok = (w < lo);
                       }
                     else
                       {
                        phase_top_ok = false;
                        phase_bottom_ok = false;
                       }
                    }
                  else
                    {
                     phase_top_ok = false;
                     phase_bottom_ok = false;
                    }
                 }

               datetime t0 = time[i1];
               if(cross_up && pivot_low && pre_up && candle_bottom_ok && phase_bottom_ok)
                 {
                  if(g_last_fundo_time != t0)
                    {
                     double p = low[i1] - InpTextOffsetPts * _Point;
                     CreateSignalText("FUNDO", t0, p, InpTextFundo, InpTextColorFundo);
                     g_last_fundo_time = t0;
                    }
                 }
               else if(cross_dn && pivot_high && pre_dn && candle_top_ok && phase_top_ok)
                 {
                  if(g_last_topo_time != t0)
                    {
                     double p = high[i1] + InpTextOffsetPts * _Point;
                     CreateSignalText("TOPO", t0, p, InpTextTopo, InpTextColorTopo);
                     g_last_topo_time = t0;
                    }
                 }
              }
           }
        }
     }

   if(InpShowStatus)
     {
      DashEnsure();
      string dash_title = "ZZ_ADX_Pivots_PhaseSTD v1.0.3 | Painel Compra/Venda | ADX=" + IntegerToString(InpAdxPeriod) + " | Tol=" + IntegerToString(InpPivotTol);
      dash_title += (InpShowStats ? " | Stats=ON" : " | Stats=OFF");
      DashSet(0, dash_title, clrSilver);
      DashSet(1, "TOPO (baixa)", clrSilver);
      DashSet(2, "SINAL TOPO: " + string(s_dn?"TRUE":"FALSE"), s_dn?COL_SIGNAL_TRUE:COL_SIGNAL_FALSE);
      DashSet(3, "FUNDO (alta)", clrSilver);
      DashSet(4, "SINAL FUNDO: " + string(s_up?"TRUE":"FALSE"), s_up?COL_SIGNAL_TRUE:COL_SIGNAL_FALSE);
      DashSet(5, "", clrSilver);
      DashSet(6, "", clrSilver);
      DashSet(7, "", clrSilver);
      DashSet(8, "", clrSilver);
      DashSet(9, "", clrSilver);
      DashSet(10, "", clrSilver);
      DashSet(11, "", clrSilver);
      DashSet(12, "", clrSilver);
      DashSet(13, "", clrSilver);
      DashSet(14, "", clrSilver);
     }

   // --- PREVIEW (barra 0): pode pintar/repintar, mas não fixa ---
   if(rates_total > 0)
     {
      int i0 = IdxSeries(0, rates_total, series);
      if(!InpPreview)
        {
         UpdatePreviewText("FUNDO", false, time[i0], low[i0], InpTextFundo, InpTextColorFundo);
         UpdatePreviewText("TOPO",  false, time[i0], high[i0], InpTextTopo, InpTextColorTopo);
        }
      else if(status_ok)
        {
         string txt_f = InpPreviewPrefix + InpTextFundo;
         string txt_t = InpPreviewPrefix + InpTextTopo;
         double p_f = low[i0] - InpTextOffsetPts * _Point;
         double p_t = high[i0] + InpTextOffsetPts * _Point;
         UpdatePreviewText("FUNDO", s_up, time[i0], p_f, txt_f, InpTextColorFundo);
         UpdatePreviewText("TOPO",  s_dn, time[i0], p_t, txt_t, InpTextColorTopo);
        }
      else
        {
         UpdatePreviewText("FUNDO", false, time[i0], low[i0], InpTextFundo, InpTextColorFundo);
         UpdatePreviewText("TOPO",  false, time[i0], high[i0], InpTextTopo, InpTextColorTopo);
        }
     }

//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
//| Get highest value for range                                      |
//+------------------------------------------------------------------+
double Highest(const double&array[],int count,int start)
  {
   double res=array[start];
//---
   for(int i=start-1; i>start-count && i>=0; i--)
      if(res<array[i])
         res=array[i];
//---
   return(res);
  }
//+------------------------------------------------------------------+
//| Get lowest value for range                                       |
//+------------------------------------------------------------------+
double Lowest(const double&array[],int count,int start)
  {
   double res=array[start];
//---
   for(int i=start-1; i>start-count && i>=0; i--)
      if(res>array[i])
         res=array[i];
//---
   return(res);
  }
//+------------------------------------------------------------------+
bool AdxBelowForBars(const double &fast[], const double &slow[], const int i, const int min_bars)
{
   if(min_bars <= 0) return true;
   for(int n=1; n<=min_bars; n++)
     {
      if(!(fast[i+n] < slow[i+n])) return false;
     }
   return true;
}
//+------------------------------------------------------------------+
void FinalizeRunStats(const int rdir,
                      const int rlen,
                      int &runs_top,
                      int &runs_bottom,
                      int &sum_top,
                      int &sum_bottom)
  {
   if(rlen <= 0) return;
   if(rdir == -1)
     {
      runs_top++;
      sum_top += rlen;
     }
   else if(rdir == 1)
     {
      runs_bottom++;
      sum_bottom += rlen;
     }
  }
//+------------------------------------------------------------------+
int IdxSeries(const int s, const int rates_total, const bool series)
{
   if(series) return s;
   return (rates_total - 1 - s);
}
string DashPrefix()
{
   return "ZZADX_STATUS_" + g_instance_tag + "_";
}

void DeleteLegacyLabels()
{
   int total = ObjectsTotal(0, 0, -1);
   for(int i=total-1; i>=0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, "Label") != 0) continue;
      if(ObjectGetInteger(0, name, OBJPROP_TYPE) != OBJ_LABEL) continue;
      ObjectDelete(0, name);
   }
}

void DashEnsure()
{
   g_chart_id = ChartID();
   string pfx = DashPrefix();
   for(int i=0; i<DASH_LINES; i++)
     {
      string name = pfx + "L" + IntegerToString(i);
      if(ObjectFind(g_chart_id, name) >= 0) continue;
      if(!ObjectCreate(g_chart_id, name, OBJ_LABEL, 0, 0, 0)) continue;
      ObjectSetInteger(g_chart_id, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(g_chart_id, name, OBJPROP_XDISTANCE, InpDashX);
      ObjectSetInteger(g_chart_id, name, OBJPROP_YDISTANCE, InpDashY + i*(InpDashFont+2));
      ObjectSetInteger(g_chart_id, name, OBJPROP_FONTSIZE, InpDashFont);
      ObjectSetString(g_chart_id, name, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(g_chart_id, name, OBJPROP_BACK, false);
     }
}

void DashSet(const int idx, const string text, const color c)
{
   string name = DashPrefix() + "L" + IntegerToString(idx);
   if(ObjectFind(g_chart_id, name) < 0) return;
   ObjectSetString(g_chart_id, name, OBJPROP_TEXT, text);
   ObjectSetInteger(g_chart_id, name, OBJPROP_COLOR, c);
}

string SigName(const string kind, const datetime t)
{
   return "ZZADX_SIG_" + g_instance_tag + "_" + kind + "_" + TimeToString(t, TIME_DATE|TIME_MINUTES|TIME_SECONDS);
}

string PreviewName(const string kind)
{
   return "ZZADX_PREVIEW_" + g_instance_tag + "_" + kind;
}

void UpdatePreviewText(const string kind, const bool show, const datetime t, const double price, const string txt, const color c)
{
   g_chart_id = ChartID();
   string name = PreviewName(kind);
   if(!show)
     {
      if(ObjectFind(g_chart_id, name) >= 0)
         ObjectDelete(g_chart_id, name);
      return;
     }
   if(ObjectFind(g_chart_id, name) < 0)
     {
      if(!ObjectCreate(g_chart_id, name, OBJ_TEXT, 0, t, price)) return;
     }
   else
     {
      ObjectMove(g_chart_id, name, 0, t, price);
     }
   ObjectSetString(g_chart_id, name, OBJPROP_TEXT, txt);
   ObjectSetInteger(g_chart_id, name, OBJPROP_COLOR, c);
   ObjectSetInteger(g_chart_id, name, OBJPROP_FONTSIZE, InpTextFont);
   ObjectSetString(g_chart_id, name, OBJPROP_FONT, InpTextFontName);
   ObjectSetInteger(g_chart_id, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(g_chart_id, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(g_chart_id, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(g_chart_id, name, OBJPROP_BACK, false);
}

void CreateSignalText(const string kind, const datetime t, const double price, const string txt, const color c)
{
   g_chart_id = ChartID();
   string name = SigName(kind, t);
   if(ObjectFind(g_chart_id, name) >= 0) return;
   if(!ObjectCreate(g_chart_id, name, OBJ_TEXT, 0, t, price)) return;
   ObjectSetString(g_chart_id, name, OBJPROP_TEXT, txt);
   ObjectSetInteger(g_chart_id, name, OBJPROP_COLOR, c);
   ObjectSetInteger(g_chart_id, name, OBJPROP_FONTSIZE, InpTextFont);
   ObjectSetString(g_chart_id, name, OBJPROP_FONT, InpTextFontName);
   ObjectSetInteger(g_chart_id, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(g_chart_id, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(g_chart_id, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(g_chart_id, name, OBJPROP_BACK, false);
}

void DashDeleteAll()
{
   g_chart_id = ChartID();
   string pfx = DashPrefix();
   int total = ObjectsTotal(g_chart_id, 0, -1);
   for(int i=total-1; i>=0; i--)
     {
      string name = ObjectName(g_chart_id, i, 0, -1);
      if(StringFind(name, pfx) == 0)
         ObjectDelete(g_chart_id, name);
   }
}

void DeletePreviewAll()
{
   g_chart_id = ChartID();
   string name_top = PreviewName("TOPO");
   string name_fundo = PreviewName("FUNDO");
   if(ObjectFind(g_chart_id, name_top) >= 0)
      ObjectDelete(g_chart_id, name_top);
   if(ObjectFind(g_chart_id, name_fundo) >= 0)
      ObjectDelete(g_chart_id, name_fundo);
}
