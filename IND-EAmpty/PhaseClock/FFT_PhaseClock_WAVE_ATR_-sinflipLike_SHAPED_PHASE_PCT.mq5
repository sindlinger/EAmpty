//+------------------------------------------------------------------+
//| ATR_FFT_PhaseClock_OLA_Causal.mq5                                |
//| - Atualiza SOMENTE a barra 0 (última) a cada tick                |
//| - FFT causal (passado -> presente)                              |
//| - Bandpass + Analítico (Hilbert no espectro)                    |
//| - Relógio com ring + ponteiro "haste" (segmentos)               |
//+------------------------------------------------------------------+
#property strict
#property indicator_separate_window
//#property indicator_digits 8
#define INDICATOR_NAME "FFT_PhaseClock_WAVE_ATR_PCT"
#property indicator_buffers 5
#property indicator_plots   3
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_label1  "ATR% 17"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrangeRed
#property indicator_label2  "ATR% 26"
#property indicator_type3   DRAW_COLOR_LINE
#property indicator_color3  clrDodgerBlue, clrRed
#property indicator_label3  "Wave ZZ"
#property indicator_width3  2



#define CLOCK_MAX_DOTS  120
#define CLOCK_MAX_HAND  64



enum FEED_SOURCE
{
   FEED_ATR = 0,
   FEED_TR,
   FEED_CLOSE,
   FEED_HL2,
   FEED_HLC3,
   FEED_OHLC4,
   FEED_VOLUME,
   FEED_TICKVOLUME
};

enum WINDOW_TYPE
{
   WIN_HANN = 0,
   WIN_SINE,
   WIN_SQRT_HANN,
   WIN_KAISER
};

enum BAND_SHAPE
{
   BAND_RECT = 0,
   BAND_GAUSS
};

enum OUTPUT_MODE
{
   OUT_SIN = 0,
   OUT_COS,
   OUT_PHASE_RAD,
   OUT_PHASE_DEG
};

// Wave shaping (para deixar "menos senoide" sem alterar a fase)
enum WAVE_SHAPE
{
   SHAPE_NONE = 0,      // saída padrão (seno/cosseno)
   SHAPE_TRIANGLE_MIX   // mistura seno/cosseno com forma triangular (mesma fase)
};

enum PAD_MODE
{
   PAD_ZERO = 0,
   PAD_MIRROR
};

// ---------------- inputs ----------------
const FEED_SOURCE  FeedSource     = FEED_ATR;
input int          AtrPeriod      = 52;
input int          AtrPeriod2     = 26;
input double       OutputScale    = 100.0; // 100 = porcentagem
input int          FFTSize        = 1024;
input WINDOW_TYPE  WindowType     = WIN_KAISER;
input double       KaiserBeta     = 8.6;

input bool         CausalWindow   = true; // janela com pico no presente (barra 0)

input bool         RemoveDC       = true;
input bool         ApplyBandpass  = true;
input int          CycleBars      = 17;
input double       BandwidthPct   = 40.0;
input BAND_SHAPE   BandShape      = BAND_GAUSS;

input OUTPUT_MODE  OutputMode     = OUT_COS;
input bool         NormalizeAmp   = false;
input PAD_MODE     PadMode        = PAD_MIRROR;

input WAVE_SHAPE   WaveShape      = SHAPE_TRIANGLE_MIX;
input double       TriangleMix    = 0.35;   // 0..1 (0 = seno/cosseno puro, 1 = triangular puro)

input bool         HoldPhaseOnLowAmp = true;
input double       LowAmpEps      = 1e-9;

// Clock visuals
input bool         ShowPhaseClock = false;
input int          ClockXOffset   = 110;     // dist da borda direita (px)
input int          ClockYOffset   = 55;      // dist do topo (px)
input int          ClockRadius    = 26;      // raio (px)

input bool         ClockShowRingDots = true;
input int          ClockRingDotsCount = 60;  // pontos no anel
input int          ClockRingDotSize   = 10;
input color        ClockRingColor     = clrSilver;

input bool         ClockShowNumbers   = true;
input int          ClockNumbersSize   = 10;
input color        ClockNumbersColor  = clrSilver;

input bool         ClockShowHand      = true;
input int          ClockHandSegments  = 9;   // quantos pontinhos formam a haste
input int          ClockHandDotSize   = 12;
input color        ClockHandColor     = clrRed;

input bool         ClockShowCenterDot = true;
input int          ClockCenterDotSize = 12;
input color        ClockCenterColor   = clrWhite;

input bool         ClockShowText      = true;

// ZigZag sobre a wave (buffer 0)
input bool         ShowWaveZigZag   = true;
input double       ZZDeviation     = 0.0;   // desvio mínimo (unidade da wave)
input int          ZZMinBars        = 3;    // barras mínimas por swing
input int          ZZLookback       = 1200; // barras analisadas
input int          ZZLongAvgCount   = 20;   // swings para média longa
input int          ZZMidAvgCount    = 10;   // swings para média média
input bool         ShowZigZagStats  = true;
input int          ZZTextXOffset    = 110;
input int          ZZTextYOffset    = 80;
input int          ZZBoxWidth       = 120;
input int          ZZBoxHeight      = 60;

// ZigZag color no preço
input bool         ShowPriceZigZag  = true;
input int          PriceZZWidth     = 2;
input color        PriceZZUpColor   = clrDodgerBlue;
input color        PriceZZDownColor = clrRed;
input int          PriceZZMaxSegments = 120;
input bool         ShowPriceZZStats = true;
input int          PriceZZTextXOffset = 20;
input int          PriceZZTextYOffset = 20;
input int          PriceZZBoxWidth    = 120;
input int          PriceZZBoxHeight   = 60;

input int          StatsBoxAlpha    = 160; // 0..255
input color        StatsBoxBgColor  = clrBlack;
input color        StatsBoxBorderColor = clrDimGray;

// ---------------- buffers ----------------
double gOut[];
double gOut2[];
double gPhaseOut[];
double gZZWave[];
double gZZWaveColor[];

// ---------------- internals ----------------
int      gAtrHandle = INVALID_HANDLE;
int      gAtrHandle2 = INVALID_HANDLE;
int      gN = 0;
double   gWin[];
double   gMask[];
double   gLastPhase = 0.0;
bool     gMaskOk = true;
bool     gWarnedBand = false;
int      gPriceZZCount = 0;

// Subwindow onde o indicador está
int      gSubWin = -1;

// ---------------- FFT helpers ----------------
int NextPow2(int v){ int n=1; while(n < v) n <<= 1; return n; }

void FFT(double &re[], double &im[], const bool inverse)
{
   int n = ArraySize(re);
   int j = 0;
   for(int i=1; i<n; i++)
   {
      int bit = n >> 1;
      while((j & bit) != 0){ j ^= bit; bit >>= 1; }
      j ^= bit;
      if(i < j)
      {
         double tr = re[i]; re[i] = re[j]; re[j] = tr;
         double ti = im[i]; im[i] = im[j]; im[j] = ti;
      }
   }
   for(int len=2; len<=n; len<<=1)
   {
      double ang = 2.0 * M_PI / len * (inverse ? -1.0 : 1.0);
      double wlen_re = MathCos(ang);
      double wlen_im = MathSin(ang);
      for(int i=0; i<n; i+=len)
      {
         double w_re = 1.0;
         double w_im = 0.0;
         for(int k=0; k<len/2; k++)
         {
            int u = i + k;
            int v = i + k + len/2;
            double vr = re[v]*w_re - im[v]*w_im;
            double vi = re[v]*w_im + im[v]*w_re;
            re[v] = re[u] - vr;
            im[v] = im[u] - vi;
            re[u] = re[u] + vr;
            im[u] = im[u] + vi;
            double next_re = w_re*wlen_re - w_im*wlen_im;
            double next_im = w_re*wlen_im + w_im*wlen_re;
            w_re = next_re;
            w_im = next_im;
         }
      }
   }
   if(inverse)
   {
      for(int i=0; i<n; i++){ re[i] /= n; im[i] /= n; }
   }
}

// Kaiser window
double I0(double x)
{
   double ax = MathAbs(x);
   double y;
   if(ax < 3.75)
   {
      y = x/3.75; y *= y;
      return 1.0 + y*(3.5156229 + y*(3.0899424 + y*(1.2067492 + y*(0.2659732 + y*(0.0360768 + y*0.0045813)))));
   }
   y = 3.75/ax;
   return (MathExp(ax)/MathSqrt(ax))*(0.39894228 + y*(0.01328592 + y*(0.00225319 + y*(-0.00157565 + y*(0.00916281 + y*(-0.02057706 + y*(0.02635537 + y*(-0.01647633 + y*0.00392377))))))));
}

int MirrorIndex(int idx, int len)
{
   if(len <= 1) return 0;
   if(idx < 0) idx = -idx;
   if(idx >= len) idx = 2*len - 2 - idx;
   if(idx < 0) idx = 0;
   if(idx >= len) idx = len - 1;
   return idx;
}

double GetSeriesSample(const double &src_series[], int sidx, int len)
{
   if(sidx >= 0 && sidx < len) return src_series[sidx];
   if(PadMode == PAD_ZERO) return 0.0;
   int m = MirrorIndex(sidx, len);
   return src_series[m];
}

bool ValidateBandBins(const int N)
{
   if(!ApplyBandpass || CycleBars <= 0) return true;
   double f0 = 1.0 / (double)CycleBars;
   double bw = BandwidthPct / 100.0;
   if(bw < 0.05) bw = 0.05;
   if(bw > 2.0)  bw = 2.0;
   double f1 = f0*(1.0 - 0.5*bw);
   double f2 = f0*(1.0 + 0.5*bw);
   if(f1 < 1e-6) f1 = 1e-6;
   if(f2 > 0.499999) f2 = 0.499999;
   if(f2 <= f1) f2 = f1 + 1e-6;
   int half = N/2;
   for(int k=0; k<=half; k++)
   {
      double f = (double)k/(double)N;
      if(f >= f1 && f <= f2) return true;
   }
   return false;
}

double BandWeight(const double f)
{
   if(!ApplyBandpass || CycleBars <= 0) return 1.0;

   double f0 = 1.0 / (double)CycleBars;
   double bw = BandwidthPct / 100.0;
   if(bw < 0.05) bw = 0.05;
   if(bw > 2.0)  bw = 2.0;

   double f1 = f0*(1.0 - 0.5*bw);
   double f2 = f0*(1.0 + 0.5*bw);

   if(f1 < 1e-6) f1 = 1e-6;
   if(f2 > 0.499999) f2 = 0.499999;
   if(f2 <= f1) f2 = f1 + 1e-6;

   if(f < f1 || f > f2) return 0.0;
   if(BandShape == BAND_RECT) return 1.0;

   double bw2 = (f2 - f1);
   double sigma = bw2 / 2.355;
   if(sigma <= 1e-12) return 1.0;
   double d = (f - f0)/sigma;
   return MathExp(-0.5*d*d);
}

void BuildWindowAndMask(const int N)
{
   gN = N;
   ArrayResize(gWin, N);
   ArrayResize(gMask, N);

   double denomI0 = I0(KaiserBeta);
   for(int n=0; n<N; n++)
   {
      double w = 1.0;

      if(!CausalWindow)
      {
         // janela simétrica (pico no meio da janela)
         if(WindowType == WIN_HANN)
            w = 0.5 - 0.5*MathCos(2.0*M_PI*n/(N-1));
         else if(WindowType == WIN_SINE)
            w = MathSin(M_PI*(n + 0.5)/N);
         else if(WindowType == WIN_SQRT_HANN)
         {
            double hann = 0.5 - 0.5*MathCos(2.0*M_PI*n/(N-1));
            w = MathSqrt(hann);
         }
         else
         {
            double t = (2.0*n)/(double)(N-1) - 1.0;
            double val = KaiserBeta*MathSqrt(MathMax(0.0, 1.0 - t*t));
            w = I0(val)/denomI0;
         }
      }
      else
      {
         // janela causal (pico no presente / barra 0)
         // Observação: como o cálculo pega o sample no fim da janela (re[N-1]),
         // uma janela simétrica derruba a amplitude no "agora". Esta versão evita isso.
         if(WindowType == WIN_HANN)
            w = 0.5 - 0.5*MathCos(M_PI*n/(N-1));                        // 0..1
         else if(WindowType == WIN_SINE)
            w = MathSin(0.5*M_PI*(double)n/(double)(N-1));              // 0..1
         else if(WindowType == WIN_SQRT_HANN)
         {
            double hann = 0.5 - 0.5*MathCos(M_PI*n/(N-1));
            w = MathSqrt(hann);
         }
         else
         {
            double u = (double)n/(double)(N-1);                         // 0..1
            double t = 1.0 - u;                                         // 1..0
            double val = KaiserBeta*MathSqrt(MathMax(0.0, 1.0 - t*t));
            w = I0(val)/denomI0;                                        // ~1/I0(beta)..1
         }
      }

      gWin[n] = w;
   }

   gMaskOk = ValidateBandBins(N);
   if(!gMaskOk && !gWarnedBand)
   {
      gWarnedBand = true;
      Print("?? Bandpass SEM bins p/ CycleBars=", CycleBars,
            " com FFTSize/N=", N,
            ". Ignorando bandpass (mantendo analítico) para não travar fase.");
   }

   int half = N/2;
   for(int k=0; k<N; k++)
   {
      double analytic = 0.0;
      if(k == 0) analytic = 1.0;
      else if((N % 2 == 0) && (k == half)) analytic = 1.0;
      else if(k > 0 && k < half) analytic = 2.0;
      else analytic = 0.0;

      double wband = 1.0;
      if(gMaskOk && ApplyBandpass && CycleBars > 0)
      {
         double f = (k <= half) ? (double)k/(double)N : (double)(N-k)/(double)N;
         wband = BandWeight(f);
      }

      gMask[k] = analytic * wband;
   }
}

// TR
double TrueRangeAtShift(const double &high[], const double &low[], const double &close[], int shift, int total)
{
   double h = (shift < total) ? high[shift] : high[total-1];
   double l = (shift < total) ? low[shift]  : low[total-1];
   double pc = close[ (shift+1 < total) ? (shift+1) : (total-1) ];
   double tr1 = h - l;
   double tr2 = MathAbs(h - pc);
   double tr3 = MathAbs(l - pc);
   return MathMax(tr1, MathMax(tr2, tr3));
}

bool FetchSourceSeries(const int total, const double &open[], const double &high[], const double &low[], const double &close[],
                       const long &tick_volume[], const long &volume_arr[],
                       double &src_series[], const int needN, const int atr_handle)
{
   ArrayResize(src_series, needN);
   ArraySetAsSeries(src_series, true);

   if(FeedSource == FEED_ATR)
   {
      int handle = atr_handle;
      if(handle == INVALID_HANDLE) return false;
      int got = CopyBuffer(handle, 0, 0, needN, src_series);
      return (got > 0);
   }

   for(int i=0; i<needN; i++)
   {
      double v = 0.0;
      switch(FeedSource)
      {
         case FEED_TR: v = TrueRangeAtShift(high, low, close, i, total); break;
         case FEED_CLOSE: v = (i < total) ? close[i] : close[total-1]; break;
         case FEED_HL2: v = ((i < total) ? (high[i]+low[i]) : (high[total-1]+low[total-1]))*0.5; break;
         case FEED_HLC3:
            v = (i < total) ? (high[i]+low[i]+close[i])/3.0 : (high[total-1]+low[total-1]+close[total-1])/3.0;
            break;
         case FEED_OHLC4:
            v = (i < total) ? (open[i]+high[i]+low[i]+close[i])/4.0 : (open[total-1]+high[total-1]+low[total-1]+close[total-1])/4.0;
            break;
         case FEED_VOLUME:
            v = (double)((i < total) ? volume_arr[i] : volume_arr[total-1]);
            break;
         case FEED_TICKVOLUME:
            v = (double)((i < total) ? tick_volume[i] : tick_volume[total-1]);
            break;
         default:
            v = (i < total) ? close[i] : close[total-1];
            break;
      }
      src_series[i] = v;
   }
   return true;
}

bool FetchSourceSeriesShift(const int total, const double &open[], const double &high[], const double &low[], const double &close[],
                            const long &tick_volume[], const long &volume_arr[],
                            const int shift,
                            double &src_series[], const int needN, const int atr_handle)
{
   ArrayResize(src_series, needN);
   ArraySetAsSeries(src_series, true);

   if(FeedSource == FEED_ATR)
   {
      int handle = atr_handle;
      if(handle == INVALID_HANDLE) return false;
      int got = CopyBuffer(handle, 0, shift, needN, src_series);
      return (got > 0);
   }

   for(int i=0; i<needN; i++)
   {
      int idx = i + shift;
      double v = 0.0;
      switch(FeedSource)
      {
         case FEED_TR: v = TrueRangeAtShift(high, low, close, idx, total); break;
         case FEED_CLOSE: v = (idx < total) ? close[idx] : close[total-1]; break;
         case FEED_HL2: v = ((idx < total) ? (high[idx]+low[idx]) : (high[total-1]+low[total-1]))*0.5; break;
         case FEED_HLC3:
            v = (idx < total) ? (high[idx]+low[idx]+close[idx])/3.0 : (high[total-1]+low[total-1]+close[total-1])/3.0;
            break;
         case FEED_OHLC4:
            v = (idx < total) ? (open[idx]+high[idx]+low[idx]+close[idx])/4.0 : (open[total-1]+high[total-1]+low[total-1]+close[total-1])/4.0;
            break;
         case FEED_VOLUME:
            v = (double)((idx < total) ? volume_arr[idx] : volume_arr[total-1]);
            break;
         case FEED_TICKVOLUME:
            v = (double)((idx < total) ? tick_volume[idx] : tick_volume[total-1]);
            break;
         default:
            v = (idx < total) ? close[idx] : close[total-1];
            break;
      }
      src_series[i] = v;
   }
   return true;
}

bool ComputeBar0Phase(const int total,
                      const double &open[], const double &high[], const double &low[], const double &close[],
                      const long &tick_volume[], const long &volume_arr[],
                      const int atr_handle,
                      double &out_value, double &out_phase)
{
   int N = gN;
   if(N <= 32) return false;

   double src_series[];
   if(!FetchSourceSeries(total, open, high, low, close, tick_volume, volume_arr, src_series, N, atr_handle))
      return false;

   double re[], im[];
   ArrayResize(re, N);
   ArrayResize(im, N);

   double mean = 0.0;
   // chrono: re[0]=mais antigo ... re[N-1]=mais recente (barra 0)
   for(int n=0; n<N; n++)
   {
      int sidx = (N-1 - n);
      double x = GetSeriesSample(src_series, sidx, N);
      re[n] = x; im[n] = 0.0;
      mean += x;
   }
   mean = (N>0 ? mean/(double)N : 0.0);

   for(int n=0; n<N; n++)
   {
      double x = re[n];
      if(RemoveDC) x -= mean;
      x *= gWin[n];
      re[n] = x;
      im[n] = 0.0;
   }

   FFT(re, im, false);
   for(int k=0; k<N; k++)
   {
      double m = gMask[k];
      re[k] *= m;
      im[k] *= m;
   }
   FFT(re, im, true);

   double are = re[N-1];
   double aim = im[N-1];
   if(!MathIsValidNumber(are)) are = 0.0;
   if(!MathIsValidNumber(aim)) aim = 0.0;

   double phase = MathArctan2(aim, are);
   double amp   = MathSqrt(are*are + aim*aim);

   if(HoldPhaseOnLowAmp && amp < LowAmpEps)
      phase = gLastPhase;

   gLastPhase = phase;
   out_phase = phase;

   double s = MathSin(phase);
   double c = MathCos(phase);

   if(OutputMode == OUT_PHASE_RAD)
      out_value = phase;
   else if(OutputMode == OUT_PHASE_DEG)
      out_value = phase * 180.0 / M_PI;
   else
   {
      // Saída em forma de onda (sin/cos). Podemos "waveshapar" sem mexer na fase.
      double base = (OutputMode == OUT_COS ? c : s);
      double shaped = base;

      if(WaveShape == SHAPE_TRIANGLE_MIX)
      {
         double mix = TriangleMix;
         if(mix < 0.0) mix = 0.0;
         if(mix > 1.0) mix = 1.0;

         // Forma triangular com a MESMA fase (picos/vales e cruzamentos no mesmo lugar)
         // tri = (2/pi)*asin(sin(x)) é o triângulo clássico; cos é apenas um sin deslocado.
         double tri = (OutputMode == OUT_COS)
                      ? (2.0/M_PI) * MathArcsin(MathCos(phase))
                      : (2.0/M_PI) * MathArcsin(MathSin(phase));

         shaped = (1.0 - mix) * base + mix * tri;
      }

      out_value = NormalizeAmp ? shaped : (shaped * amp);
   }

   if(!MathIsValidNumber(out_value)) out_value = 0.0;
   return true;
}

bool ComputePhaseAtShift(const int total,
                         const double &open[], const double &high[], const double &low[], const double &close[],
                         const long &tick_volume[], const long &volume_arr[],
                         const int shift,
                         const int atr_handle,
                         double &out_value, double &out_phase)
{
   int N = gN;
   if(N <= 32) return false;

   double src_series[];
   if(!FetchSourceSeriesShift(total, open, high, low, close, tick_volume, volume_arr, shift, src_series, N, atr_handle))
      return false;

   double re[], im[];
   ArrayResize(re, N);
   ArrayResize(im, N);

   double mean = 0.0;
   for(int n=0; n<N; n++)
   {
      int sidx = (N-1 - n);
      double x = GetSeriesSample(src_series, sidx, N);
      re[n] = x; im[n] = 0.0;
      mean += x;
   }
   mean = (N>0 ? mean/(double)N : 0.0);

   for(int n=0; n<N; n++)
   {
      double x = re[n];
      if(RemoveDC) x -= mean;
      x *= gWin[n];
      re[n] = x;
      im[n] = 0.0;
   }

   FFT(re, im, false);
   for(int k=0; k<N; k++)
   {
      double m = gMask[k];
      re[k] *= m;
      im[k] *= m;
   }
   FFT(re, im, true);

   double are = re[N-1];
   double aim = im[N-1];
   if(!MathIsValidNumber(are)) are = 0.0;
   if(!MathIsValidNumber(aim)) aim = 0.0;

   double phase = MathArctan2(aim, are);
   double amp   = MathSqrt(are*are + aim*aim);

   if(HoldPhaseOnLowAmp && amp < LowAmpEps)
      phase = gLastPhase;

   gLastPhase = phase;
   out_phase = phase;

   double s = MathSin(phase);
   double c = MathCos(phase);

   if(OutputMode == OUT_PHASE_RAD)
      out_value = phase;
   else if(OutputMode == OUT_PHASE_DEG)
      out_value = phase * 180.0 / M_PI;
   else
   {
      double base = (OutputMode == OUT_COS ? c : s);
      double shaped = base;

      if(WaveShape == SHAPE_TRIANGLE_MIX)
      {
         double mix = TriangleMix;
         if(mix < 0.0) mix = 0.0;
         if(mix > 1.0) mix = 1.0;

         double tri = (2.0/M_PI) * MathAsin(base);
         shaped = (1.0 - mix) * base + mix * tri;
      }

      out_value = shaped;
   }
   return true;
}

// ---------------- CLOCK (arrumado) ----------------
string gObjPrefix = INDICATOR_NAME + "_";

string ClockNumName(const int idx){ return gObjPrefix + StringFormat("NUM_%d", idx); }
string ClockDotName(const int idx){ return gObjPrefix + StringFormat("RING_%d", idx); }
string ClockHandSegName(const int idx){ return gObjPrefix + StringFormat("HAND_%d", idx); }
string ClockCenterName(){ return gObjPrefix + "CENTER"; }
string ClockTextName(){ return gObjPrefix + "TEXT"; }
string ZZTextName(const int idx){ return gObjPrefix + StringFormat("ZZTEXT_%d", idx); }
string ZZBoxName(){ return gObjPrefix + "ZZBOX"; }
string PriceZZTextName(const int idx){ return gObjPrefix + StringFormat("PZTXT_%d", idx); }
string PriceZZBoxName(){ return gObjPrefix + "PZBOX"; }
string PriceZZName(const int idx){ return gObjPrefix + StringFormat("PZZ_%d", idx); }

void EnsureSubWin()
{
   if(gSubWin >= 0) return;
   gSubWin = ChartWindowFind(0, INDICATOR_NAME);
   if(gSubWin < 0) gSubWin = 1; // fallback: primeiro subwindow
}

void SetLabel(const string name, const int xdist, const int ydist, const color col, const int fsz, const string text)
{
   EnsureSubWin();
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, gSubWin, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, xdist);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, ydist);
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fsz);
   ObjectSetString (0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString (0, name, OBJPROP_TEXT, text);
}

void SetLabelWin(const string name, const int win, const int xdist, const int ydist, const color col, const int fsz, const string text)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, win, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, xdist);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, ydist);
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fsz);
   ObjectSetString (0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString (0, name, OBJPROP_TEXT, text);
}

void SetBoxWin(const string name, const int win, const int xdist, const int ydist, const int w, const int h, const color bg, const color border)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, win, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, xdist);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, ydist);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_COLOR, border);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void DeleteClockObjects()
{
   for(int i=0;i<12;i++) ObjectDelete(0, ClockNumName(i));
   for(int i=0;i<CLOCK_MAX_DOTS;i++) ObjectDelete(0, ClockDotName(i));
   for(int i=0;i<CLOCK_MAX_HAND;i++) ObjectDelete(0, ClockHandSegName(i));
   ObjectDelete(0, ClockCenterName());
   ObjectDelete(0, ClockTextName());
}

void DeleteZZText()
{
   for(int i=0;i<8;i++) ObjectDelete(0, ZZTextName(i));
   ObjectDelete(0, ZZBoxName());
}

void DeletePriceZZText()
{
   for(int i=0;i<8;i++) ObjectDelete(0, PriceZZTextName(i));
   ObjectDelete(0, PriceZZBoxName());
}

void DeletePriceZZ()
{
   int total = ObjectsTotal(0, 0, -1);
   for(int i=total-1; i>=0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, gObjPrefix + "PZZ_") == 0)
         ObjectDelete(0, name);
   }
}

void UpdatePhaseClock(const double phase)
{
   if(!ShowPhaseClock){ DeleteClockObjects(); return; }

   EnsureSubWin();

   double ang = phase;
   if(ang < 0.0) ang += 2.0*M_PI;

   const int baseX = ClockXOffset;
   const int baseY = ClockYOffset;

   // Ring dots (o "círculo" de verdade)
   if(ClockShowRingDots)
   {
      int dots = ClockRingDotsCount;
      if(dots < 12) dots = 12;
      if(dots > CLOCK_MAX_DOTS) dots = CLOCK_MAX_DOTS;

      for(int i=0; i<dots; i++)
      {
         double a = -M_PI/2.0 + (2.0*M_PI)*(double)i/(double)dots;
         int dx = (int)MathRound(ClockRadius*MathCos(a));
         int dy = (int)MathRound(ClockRadius*MathSin(a));
         SetLabel(ClockDotName(i), baseX - dx, baseY + dy, ClockRingColor, ClockRingDotSize, "•");
      }
      // apaga sobras se diminuiu dots
      for(int i=dots; i<CLOCK_MAX_DOTS; i++)
         ObjectDelete(0, ClockDotName(i));
   }
   else
   {
      for(int i=0;i<CLOCK_MAX_DOTS;i++) ObjectDelete(0, ClockDotName(i));
   }

   // Números
   if(ClockShowNumbers)
   {
      int rnum = ClockRadius + 14;
      for(int i=0; i<12; i++)
      {
         int num = (i==0 ? 12 : i);
         double a = -M_PI/2.0 + (2.0*M_PI)*(double)i/12.0;
         int dx = (int)MathRound(rnum*MathCos(a));
         int dy = (int)MathRound(rnum*MathSin(a));
         SetLabel(ClockNumName(i), baseX - dx, baseY + dy, ClockNumbersColor, ClockNumbersSize, IntegerToString(num));
      }
   }
   else
   {
      for(int i=0;i<12;i++) ObjectDelete(0, ClockNumName(i));
   }

   // Ponteiro como "haste" (segmentos de pontos)
   if(ClockShowHand)
   {
      int segs = ClockHandSegments;
      if(segs < 3) segs = 3;
      if(segs > CLOCK_MAX_HAND) segs = CLOCK_MAX_HAND;

      // direção: ponteiro aponta para ang, mas ring está com 12h em -pi/2.
      // Aqui ang já está nesse sistema (0..2pi a partir do atan2).
      // Vamos girar para "12h" ficar em cima.
      double a = ang; // já ok com o relógio que desenhamos

      // comprimento interno (não encostar na borda)
      double L = (double)(ClockRadius - 2);
      double ux = MathCos(a);
      double uy = -MathSin(a);

      for(int s=1; s<=segs; s++)
      {
         double t = (double)s/(double)segs;     // 0..1
         int dx = (int)MathRound(L*t*ux);
         int dy = (int)MathRound(L*t*uy);
         SetLabel(ClockHandSegName(s-1), baseX - dx, baseY + dy, ClockHandColor, ClockHandDotSize, "•");
      }
      for(int s=segs; s<CLOCK_MAX_HAND; s++)
         ObjectDelete(0, ClockHandSegName(s));
   }
   else
   {
      for(int s=0;s<CLOCK_MAX_HAND;s++) ObjectDelete(0, ClockHandSegName(s));
   }

   // Ponto central
   if(ClockShowCenterDot)
      SetLabel(ClockCenterName(), baseX, baseY, ClockCenterColor, ClockCenterDotSize, "•");
   else
      ObjectDelete(0, ClockCenterName());

   // Texto (quadrante + grau)
   if(ClockShowText)
   {
      int quad = 1;
      if(ang >= M_PI/2.0 && ang < M_PI) quad = 2;
      else if(ang >= M_PI && ang < 3.0*M_PI/2.0) quad = 3;
      else if(ang >= 3.0*M_PI/2.0) quad = 4;

      string txt = StringFormat("Q%d  %.0f°", quad, ang*180.0/M_PI);
      SetLabel(ClockTextName(), baseX + 55, baseY + (ClockRadius + 18), clrWhite, 10, txt);
   }
   else
   {
      ObjectDelete(0, ClockTextName());
   }
}

// ---------------- ZigZag helpers ----------------
void DrawPriceZigZag(const int pivots, const int &pidx[], const int &pdir[], const datetime &time[], const double &high[], const double &low[])
{
   if(!ShowPriceZigZag) { DeletePriceZZ(); gPriceZZCount = 0; return; }
   if(pivots < 2) return;

   int start = 0;
   int total_segs = pivots - 1;
   if(PriceZZMaxSegments > 0 && total_segs > PriceZZMaxSegments)
      start = total_segs - PriceZZMaxSegments;

   int seg = 0;
   for(int k=start; k<pivots-1; k++)
   {
      int i1 = pidx[k];
      int i2 = pidx[k+1];
      if(i1 < 0 || i2 < 0) continue;
      if(i1 == i2) continue;

      double p1 = (pdir[k] > 0 ? high[i1] : low[i1]);
      double p2 = (pdir[k+1] > 0 ? high[i2] : low[i2]);
      color col = (p2 >= p1 ? PriceZZUpColor : PriceZZDownColor);

      string name = PriceZZName(seg++);
      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_TREND, 0, time[i1], p1, time[i2], p2);
      else
      {
         ObjectMove(0, name, 0, time[i1], p1);
         ObjectMove(0, name, 1, time[i2], p2);
      }
      ObjectSetInteger(0, name, OBJPROP_COLOR, col);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, PriceZZWidth);
      ObjectSetInteger(0, name, OBJPROP_RAY, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }

   // remove segmentos antigos não usados
   for(int i=seg; i<gPriceZZCount; i++)
      ObjectDelete(0, PriceZZName(i));
   gPriceZZCount = seg;
}

void UpdateZZStats(const int pivots, const int &pidx[], const int &pdir[])
{
   if(!ShowZigZagStats){ DeleteZZText(); DeletePriceZZText(); return; }
   EnsureSubWin();

   int last = pivots - 1;
   int prev = pivots - 2;

   int curr_len = (last >= 0 ? pidx[last] : 0);
   int prev_len = (prev >= 0 ? (pidx[prev] - pidx[last]) : 0);

   // médias
   int total_swings = MathMax(0, pivots - 1);
   double sum_long = 0.0, sum_mid = 0.0;
   int count_long = 0, count_mid = 0;

   double sum_up = 0.0, sum_dn = 0.0;
   int count_up = 0, count_dn = 0;

   for(int k=0; k<total_swings; k++)
   {
      int len = pidx[k] - pidx[k+1];
      if(len <= 0) continue;
      if(count_long < ZZLongAvgCount){ sum_long += len; count_long++; }
      if(count_mid < ZZMidAvgCount){ sum_mid += len; count_mid++; }

      if(pdir[k] < 0 && pdir[k+1] > 0) { sum_up += len; count_up++; }
      else if(pdir[k] > 0 && pdir[k+1] < 0) { sum_dn += len; count_dn++; }
   }

   double avg_long = (count_long > 0 ? sum_long / count_long : 0.0);
   double avg_mid  = (count_mid > 0 ? sum_mid / count_mid : 0.0);
   double avg_up   = (count_up > 0 ? sum_up / count_up : 0.0);
   double avg_dn   = (count_dn > 0 ? sum_dn / count_dn : 0.0);

   // barras por ciclo (aprox) = 2 * swing médio
   double curr_cycle = (double)curr_len * 2.0;
   double prev_cycle = (double)prev_len * 2.0;
   double long_cycle = avg_long * 2.0;
   double mid_cycle  = avg_mid * 2.0;

   double next_top = -1.0;
   double next_bot = -1.0;
   if(last >= 0)
   {
      if(pdir[last] < 0) // último pivot é fundo -> subindo
      {
         if(avg_up > 0) next_top = avg_up - curr_len;
         if(avg_up > 0 && avg_dn > 0) next_bot = avg_up + avg_dn - curr_len;
      }
      else if(pdir[last] > 0) // último pivot é topo -> caindo
      {
         if(avg_dn > 0) next_bot = avg_dn - curr_len;
         if(avg_up > 0 && avg_dn > 0) next_top = avg_dn + avg_up - curr_len;
      }
   }

   int y = ZZTextYOffset;
   string l1 = StringFormat("A:%.0f  P:%.0f", curr_cycle, prev_cycle);
   string l2 = StringFormat("L:%.0f  M:%.0f", long_cycle, mid_cycle);
   string l3 = (next_top >= 0 ? StringFormat("U %.0f", next_top) : "U -");
   string l4 = (next_bot >= 0 ? StringFormat("D %.0f", next_bot) : "D -");

   color bg = ColorToARGB(StatsBoxBgColor, StatsBoxAlpha);
   SetBoxWin(ZZBoxName(), gSubWin, ZZTextXOffset - 6, ZZTextYOffset - 6, ZZBoxWidth, ZZBoxHeight, bg, StatsBoxBorderColor);
   SetLabel(ZZTextName(0), ZZTextXOffset, y, clrWhite, 10, l1);
   SetLabel(ZZTextName(1), ZZTextXOffset, y + 14, clrSilver, 10, l2);
   SetLabel(ZZTextName(2), ZZTextXOffset, y + 28, clrDodgerBlue, 10, l3);
   SetLabel(ZZTextName(3), ZZTextXOffset, y + 42, clrRed, 10, l4);

   if(ShowPriceZZStats)
   {
      SetBoxWin(PriceZZBoxName(), 0, PriceZZTextXOffset - 6, PriceZZTextYOffset - 6, PriceZZBoxWidth, PriceZZBoxHeight, bg, StatsBoxBorderColor);
      SetLabelWin(PriceZZTextName(0), 0, PriceZZTextXOffset, PriceZZTextYOffset, clrWhite, 10, l1);
      SetLabelWin(PriceZZTextName(1), 0, PriceZZTextXOffset, PriceZZTextYOffset + 14, clrSilver, 10, l2);
      SetLabelWin(PriceZZTextName(2), 0, PriceZZTextXOffset, PriceZZTextYOffset + 28, clrDodgerBlue, 10, l3);
      SetLabelWin(PriceZZTextName(3), 0, PriceZZTextXOffset, PriceZZTextYOffset + 42, clrRed, 10, l4);
   }
   else
   {
      DeletePriceZZText();
   }
}

int BuildWaveZigZag(const int rates_total, const double &wave[], int &pivots, int &pidx[], int &pdir[])
{
   pivots = 0;
   int maxbars = rates_total - 1;
   if(ZZLookback > 0 && maxbars > ZZLookback) maxbars = ZZLookback;
   if(maxbars < 2) return 0;

   ArrayResize(pidx, 0);
   ArrayResize(pdir, 0);

   int last_idx = maxbars;
   double last_val = wave[last_idx];
   int last_dir = 0;

   for(int i=maxbars-1; i>=0; i--)
   {
      double v = wave[i];
      if(v == EMPTY_VALUE) continue;

      if(last_dir == 0)
      {
         if(v >= last_val + ZZDeviation){ last_dir = 1; last_idx = i; last_val = v; }
         else if(v <= last_val - ZZDeviation){ last_dir = -1; last_idx = i; last_val = v; }
         else
         {
            if(v > last_val){ last_idx = i; last_val = v; }
            if(v < last_val){ last_idx = i; last_val = v; }
         }
      }
      else if(last_dir > 0) // subindo
      {
         if(v > last_val){ last_idx = i; last_val = v; }
         if(v <= last_val - ZZDeviation && (last_idx - i) >= ZZMinBars)
         {
            int n = ArraySize(pidx);
            ArrayResize(pidx, n+1);
            ArrayResize(pdir, n+1);
            pidx[n] = last_idx;
            pdir[n] = 1; // topo
            last_dir = -1;
            last_idx = i;
            last_val = v;
         }
      }
      else // descendo
      {
         if(v < last_val){ last_idx = i; last_val = v; }
         if(v >= last_val + ZZDeviation && (last_idx - i) >= ZZMinBars)
         {
            int n = ArraySize(pidx);
            ArrayResize(pidx, n+1);
            ArrayResize(pdir, n+1);
            pidx[n] = last_idx;
            pdir[n] = -1; // fundo
            last_dir = 1;
            last_idx = i;
            last_val = v;
         }
      }
   }

   // adiciona último pivot (corrente)
   int n = ArraySize(pidx);
   ArrayResize(pidx, n+1);
   ArrayResize(pdir, n+1);
   pidx[n] = last_idx;
   pdir[n] = (last_dir >= 0 ? 1 : -1);

   pivots = ArraySize(pidx);
   return pivots;
}

void FillWaveZigZag(const int pivots, const int &pidx[], const int &pdir[], const double &wave[])
{
   ArrayInitialize(gZZWave, EMPTY_VALUE);
   ArrayInitialize(gZZWaveColor, 0.0);
   if(!ShowWaveZigZag || pivots < 2) return;

   for(int k=0; k<pivots-1; k++)
   {
      int i1 = pidx[k];
      int i2 = pidx[k+1];
      if(i1 < i2) { int tmp=i1; i1=i2; i2=tmp; }
      if(i1 == i2) continue;
      double v1 = wave[i1];
      double v2 = wave[i2];
      int color_idx = (v2 >= v1 ? 0 : 1);
      int span = i1 - i2;
      for(int i=i1; i>=i2; i--)
      {
         double t = (double)(i1 - i) / (double)span;
         gZZWave[i] = v1 + (v2 - v1) * t;
         gZZWaveColor[i] = (double)color_idx;
      }
   }
}

// ---------------- MT5 lifecycle ----------------
int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME, INDICATOR_NAME);
   SetIndexBuffer(0, gOut, INDICATOR_DATA);
   SetIndexBuffer(1, gOut2, INDICATOR_DATA);
   SetIndexBuffer(2, gPhaseOut, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, gZZWave, INDICATOR_DATA);
   SetIndexBuffer(4, gZZWaveColor, INDICATOR_COLOR_INDEX);
   ArraySetAsSeries(gOut, true);
   ArraySetAsSeries(gOut2, true);
   ArraySetAsSeries(gPhaseOut, true);
   ArraySetAsSeries(gZZWave, true);
   ArraySetAsSeries(gZZWaveColor, true);
   IndicatorSetInteger(INDICATOR_DIGITS, 8);

   int N = NextPow2(MathMax(32, FFTSize));
   BuildWindowAndMask(N);

   if(FeedSource == FEED_ATR)
   {
      gAtrHandle = iATR(_Symbol, _Period, AtrPeriod);
      gAtrHandle2 = iATR(_Symbol, _Period, AtrPeriod2);
      if(gAtrHandle == INVALID_HANDLE || gAtrHandle2 == INVALID_HANDLE)
      {
         Print("Erro: nao conseguiu criar iATR.");
         return INIT_FAILED;
      }
   }

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, N);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, N);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, 0);
   PlotIndexSetInteger(2, PLOT_COLOR_INDEXES, 2);
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, 2);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(gAtrHandle != INVALID_HANDLE)
      IndicatorRelease(gAtrHandle);
   if(gAtrHandle2 != INVALID_HANDLE)
      IndicatorRelease(gAtrHandle2);
   DeleteClockObjects();
   DeleteZZText();
   DeletePriceZZ();
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime& time[],
                const double& open[],
                const double& high[],
                const double& low[],
                const double& close[],
                const long& tick_volume[],
                const long& volume[],
                const int& spread[])
{
   int N = gN;
   if(rates_total < N || N <= 32)
   {
      UpdatePhaseClock(gLastPhase);
      return rates_total;
   }

   static datetime s_last_bar = 0;
   static double s_prev_out = 0.0;
   static double s_prev_out2 = 0.0;
   static double s_prev_ph = 0.0;

   if(rates_total > 1 && time[0] != s_last_bar)
   {
      if(s_last_bar != 0)
      {
         int maxshift = rates_total - 1;
         if(ZZLookback > 0 && maxshift > ZZLookback) maxshift = ZZLookback;
         for(int i=maxshift; i>=2; i--)
         {
            gOut[i] = gOut[i-1];
            gOut2[i] = gOut2[i-1];
            gPhaseOut[i] = gPhaseOut[i-1];
         }
         gOut[1] = s_prev_out;
         gOut2[1] = s_prev_out2;
         gPhaseOut[1] = s_prev_ph;
      }
      s_last_bar = time[0];
   }

   // rebuild se parâmetros mudaram
   static int lastFFT = -1, lastCycle = -1;
   static WINDOW_TYPE lastWin = (WINDOW_TYPE)-1;
   static double lastBW = -1.0, lastBeta = -1.0;
   static BAND_SHAPE lastBandShape = (BAND_SHAPE)-1;
   static bool lastBand = false;

   if(lastFFT != FFTSize || lastCycle != CycleBars || lastWin != WindowType ||
      lastBW != BandwidthPct || lastBeta != KaiserBeta || lastBandShape != BandShape || lastBand != ApplyBandpass)
   {
      int NN = NextPow2(MathMax(32, FFTSize));
      BuildWindowAndMask(NN);

      lastFFT = FFTSize;
      lastCycle = CycleBars;
      lastWin = WindowType;
      lastBW = BandwidthPct;
      lastBeta = KaiserBeta;
      lastBandShape = BandShape;
      lastBand = ApplyBandpass;

      PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, gN);
      PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, gN);
      PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, 0);
   }

   double outv=0.0, ph=0.0;
   double outv2=0.0, ph2=0.0;
   double base_price = (rates_total > 0 ? close[0] : 0.0);
   double pct_scale = (base_price != 0.0 ? (OutputScale / base_price) : OutputScale);
   bool ok1 = ComputeBar0Phase(rates_total, open, high, low, close, tick_volume, volume, gAtrHandle, outv, ph);
   bool ok2 = ComputeBar0Phase(rates_total, open, high, low, close, tick_volume, volume, gAtrHandle2, outv2, ph2);
   if(ok1)
   {
      gOut[0] = outv * pct_scale;        // <-- somente barra 0
      gPhaseOut[0] = ph;
      UpdatePhaseClock(ph);
   }
   else
   {
      gOut[0] = 0.0;
      gPhaseOut[0] = gLastPhase;
      UpdatePhaseClock(gLastPhase);
   }
   if(ok2)
      gOut2[0] = outv2 * pct_scale;
   else
      gOut2[0] = 0.0;

   // ZigZag/contagens: backfill no início + atualiza em nova barra
   static datetime last_zz_time = 0;
   bool need_zz = false;

   if(prev_calculated == 0 && rates_total > 1)
   {
      int maxfill = rates_total - 1;
      if(ZZLookback > 0 && maxfill > ZZLookback) maxfill = ZZLookback;
      for(int i=maxfill; i>=0; i--)
      {
         double ov=0.0, phv=0.0;
         double ov2=0.0, phv2=0.0;
         bool okbf1 = ComputePhaseAtShift(rates_total, open, high, low, close, tick_volume, volume, i, gAtrHandle, ov, phv);
         bool okbf2 = ComputePhaseAtShift(rates_total, open, high, low, close, tick_volume, volume, i, gAtrHandle2, ov2, phv2);
         double basep = (i < rates_total ? close[i] : close[rates_total-1]);
         double scale = (basep != 0.0 ? (OutputScale / basep) : OutputScale);
         gOut[i] = (okbf1 ? ov * scale : 0.0);
         gOut2[i] = (okbf2 ? ov2 * scale : 0.0);
         gPhaseOut[i] = (okbf1 ? phv : gLastPhase);
      }
      need_zz = true;
      last_zz_time = time[0];
   }

   if(rates_total > 1 && time[0] != last_zz_time)
   {
      last_zz_time = time[0];
      need_zz = true;
   }

   if(need_zz)
   {
      static int zz_idx[];
      static int zz_dir[];
      int zz_pivots = 0;
      BuildWaveZigZag(rates_total, gOut, zz_pivots, zz_idx, zz_dir);
      FillWaveZigZag(zz_pivots, zz_idx, zz_dir, gOut);
      UpdateZZStats(zz_pivots, zz_idx, zz_dir);
      DrawPriceZigZag(zz_pivots, zz_idx, zz_dir, time, high, low);
   }

   s_prev_out = gOut[0];
   s_prev_out2 = gOut2[0];
   s_prev_ph = gPhaseOut[0];

   return rates_total;
}
