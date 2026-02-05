//+------------------------------------------------------------------+
//| BTick_v2.0.5_FFT.mq5                                            |
//| Pip/Tick direcional por lado com janela fixa de ticks            |
//| + suavização via convolução no domínio da frequência (FFT)       |
//+------------------------------------------------------------------+
#property strict
#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   4
#property version   "2.005"

#property indicator_label1  "Pip/Tick Buy (filtrado)"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_width1  2

#property indicator_label2  "Pip/Tick Sell (filtrado)"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_width2  2

#property indicator_label3  "State Buy"
#property indicator_type3   DRAW_NONE
#property indicator_color3  clrNONE

#property indicator_label4  "State Sell"
#property indicator_type4   DRAW_NONE
#property indicator_color4  clrNONE

#include "TickAggCommon.mqh"

// ---------------------
// Parâmetros de filtro
// ---------------------
input bool InpUseFFTFilter = true;  // aplica filtro FFT nos valores calculados
input int  InpSmoothLen    = 256;     // tamanho da janela (amostras) do filtro (>=2)
input double InpCrossEqualEps = 0.00001;  // diff max para considerar linhas iguais (sem cruzamento)

// OBS:
// 1) Este "smooth" é aplicado sobre o valor calculado (val_buy/val_sell) a cada tick.
// 2) Na prática, para janelas pequenas, a convolução no tempo (SMA/EMA) é mais eficiente.
//    Aqui está a versão FFT porque você pediu explicitamente "convolução no domínio da frequência".

static const int  kWindowTicks = 17;   // N ticks (por lado)

// ---------------------
// Buffers do indicador
// ---------------------
double BufBuy[];
double BufSell[];
double BufStateBuy[];
double BufStateSell[];

// ---------------------
// Estado do cálculo do indicador original
// ---------------------
static long    g_last_bar_open_msc = 0;
static bool    g_has_prev = false;
static MqlTick g_prev_tick;
static int     g_state_dir = 0; // 1=buy, -1=sell, 0=neutro (mantém até igualdade)

// janela de ticks (refs por lado)
static double  g_tick_refs_buy[];
static double  g_tick_refs_sell[];
static int     g_tick_count_buy = 0;
static int     g_tick_count_sell = 0;

// ---------------------
// Estado do filtro FFT
// ---------------------
#define PI 3.1415926535897932384626433832795

static int    g_M = 0;          // comprimento do filtro (janela)
static int    g_N = 0;          // tamanho FFT (potência de 2, >= 2*M-1)
static bool   g_fft_ready = false;

// FFT do filtro (kernel) pré-calculada: H[k]
static double g_Hre[];
static double g_Him[];

// buffers de trabalho (reutilizados para evitar alocações a cada tick)
static double g_Xre[];
static double g_Xim[];
static double g_Yre[];
static double g_Yim[];

// histórico de amostras para o filtro (uma janela por lado)
static double g_hist_buy[];
static double g_hist_sell[];
static int    g_hist_count_buy = 0;
static int    g_hist_count_sell = 0;

void SwapD(double &a, double &b)
{
   double t=a; a=b; b=t;
}

int NextPow2(const int n)
{
   int p=1;
   while(p < n) p <<= 1;
   return p;
}

// FFT in-place (Cooley–Tukey iterativo). re[] e im[] têm tamanho n (potência de 2).
void FFT(double &re[], double &im[], const int n, const bool inverse)
{
   // bit reversal
   int j=0;
   for(int i=1; i<n; i++)
   {
      int bit = (n >> 1);
      while((j & bit) != 0)
      {
         j ^= bit;
         bit >>= 1;
      }
      j ^= bit;

      if(i < j)
      {
         SwapD(re[i], re[j]);
         SwapD(im[i], im[j]);
      }
   }

   for(int len=2; len<=n; len<<=1)
   {
      const double ang = 2.0*PI/len * (inverse ? 1.0 : -1.0);
      const double wlen_re = MathCos(ang);
      const double wlen_im = MathSin(ang);

      for(int i=0; i<n; i+=len)
      {
         double w_re = 1.0;
         double w_im = 0.0;

         const int half = (len >> 1);
         for(int k=0; k<half; k++)
         {
            const int u = i + k;
            const int v = u + half;

            const double t_re = re[v]*w_re - im[v]*w_im;
            const double t_im = re[v]*w_im + im[v]*w_re;

            re[v] = re[u] - t_re;
            im[v] = im[u] - t_im;

            re[u] = re[u] + t_re;
            im[u] = im[u] + t_im;

            const double nw_re = w_re*wlen_re - w_im*wlen_im;
            const double nw_im = w_re*wlen_im + w_im*wlen_re;
            w_re = nw_re;
            w_im = nw_im;
         }
      }
   }

   if(inverse)
   {
      const double inv_n = 1.0/(double)n;
      for(int i=0; i<n; i++)
      {
         re[i] *= inv_n;
         im[i] *= inv_n;
      }
   }
}

// Inicializa o filtro: kernel = média móvel simples (boxcar) de tamanho M.
// Você pode trocar o kernel por um sinc+janela (low-pass mais "bonito") se quiser.
bool InitFFTFilter(const int M)
{
   g_fft_ready = false;

   if(M < 2)
      return false;

   g_M = M;

   // Para convolução linear via FFT: N >= (len(x)+len(h)-1).
   // Aqui vamos convolver uma janela de tamanho M com um kernel de tamanho M,
   // então N >= 2*M-1. Usamos a próxima potência de 2 por simplicidade.
   g_N = NextPow2(2*g_M);

   ArrayResize(g_Hre, g_N);
   ArrayResize(g_Him, g_N);
   ArrayResize(g_Xre, g_N);
   ArrayResize(g_Xim, g_N);
   ArrayResize(g_Yre, g_N);
   ArrayResize(g_Yim, g_N);

   // kernel: SMA (1/M)
   for(int i=0; i<g_N; i++)
   {
      g_Hre[i] = 0.0;
      g_Him[i] = 0.0;
   }
   const double w = 1.0/(double)g_M;
   for(int i=0; i<g_M; i++)
      g_Hre[i] = w;

   // FFT do kernel (pré-cálculo)
   FFT(g_Hre, g_Him, g_N, false);

   // limpa históricos
   ArrayResize(g_hist_buy, 0);
   ArrayResize(g_hist_sell, 0);
   g_hist_count_buy = 0;
   g_hist_count_sell = 0;

   g_fft_ready = true;
   return true;
}

void PushSample(double &arr[], int &count, const int maxn, const double v)
{
   if(maxn <= 0) return;

   if(count < maxn)
   {
      ArrayResize(arr, count + 1);
      arr[count] = v;
      count++;
      return;
   }

   // shift esquerda
   for(int i=1; i<count; i++)
      arr[i-1] = arr[i];
   arr[count-1] = v;
}

// Retorna o valor filtrado (SMA via convolução FFT) usando o histórico (tamanho M).
double FFTFilterFromHist(const double &hist[], const int count)
{
   if(!g_fft_ready || count < g_M)
      return EMPTY_VALUE;

   // monta X (janela de tamanho M) e faz zero-padding até N
   for(int i=0; i<g_N; i++)
   {
      g_Xre[i] = 0.0;
      g_Xim[i] = 0.0;
   }

   // hist[0] é o mais antigo; hist[M-1] é o mais recente
   for(int i=0; i<g_M; i++)
      g_Xre[i] = hist[i];

   // X = FFT(x)
   FFT(g_Xre, g_Xim, g_N, false);

   // Y = X * H
   for(int k=0; k<g_N; k++)
   {
      const double xr = g_Xre[k];
      const double xi = g_Xim[k];
      const double hr = g_Hre[k];
      const double hi = g_Him[k];

      g_Yre[k] = xr*hr - xi*hi;
      g_Yim[k] = xr*hi + xi*hr;
   }

   // y = IFFT(Y)
   FFT(g_Yre, g_Yim, g_N, true);

   // Para kernel simétrico (SMA), o valor "atual" sai em y[M-1]
   return g_Yre[g_M-1];
}

// ---------------------
// Funções do indicador original
// ---------------------
void PushTickRef(double &arr[], int &count, const int maxn, const double ref)
{
   if(maxn <= 0) return;
   if(count < maxn)
   {
      ArrayResize(arr, count + 1);
      arr[count] = ref;
      count++;
      return;
   }
   for(int i=1; i<count; i++)
      arr[i-1] = arr[i];
   arr[count-1] = ref;
}

double NetFromTickRefs(const double &arr[], const int count, const bool is_buy)
{
   if(count < 2) return EMPTY_VALUE;
   double pip = PipSize();
   if(is_buy)
      return (arr[count-1] - arr[0]) / pip;   // direcional
   return (arr[0] - arr[count-1]) / pip;      // direcional
}

int OnInit()
{
   SetIndexBuffer(0, BufBuy, INDICATOR_DATA);
   SetIndexBuffer(1, BufSell, INDICATOR_DATA);
   SetIndexBuffer(2, BufStateBuy, INDICATOR_DATA);
   SetIndexBuffer(3, BufStateSell, INDICATOR_DATA);
   ArraySetAsSeries(BufBuy, true);
   ArraySetAsSeries(BufSell, true);
   ArraySetAsSeries(BufStateBuy, true);
   ArraySetAsSeries(BufStateSell, true);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   IndicatorSetString(INDICATOR_SHORTNAME, "Pip/Tick Window (FFT smooth)");

   // inicializa filtro (se habilitado)
   if(InpUseFFTFilter)
      InitFFTFilter(InpSmoothLen);

   return INIT_SUCCEEDED;
}

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
   if(rates_total < 2) return 0;

   if(prev_calculated == 0)
   {
      for(int i=0;i<rates_total;i++)
      {
         BufBuy[i]=EMPTY_VALUE;
         BufSell[i]=EMPTY_VALUE;
         BufStateBuy[i]=0.0;
         BufStateSell[i]=0.0;
      }
      g_last_bar_open_msc = 0;
      g_has_prev = false;
      ArrayResize(g_tick_refs_buy, 0);
      ArrayResize(g_tick_refs_sell, 0);
      g_tick_count_buy = 0;
      g_tick_count_sell = 0;
      g_state_dir = 0;

      // reseta também o filtro
      if(InpUseFFTFilter)
         InitFFTFilter(InpSmoothLen);
      else
      {
         g_fft_ready = false;
         g_hist_count_buy = 0;
         g_hist_count_sell = 0;
         ArrayResize(g_hist_buy, 0);
         ArrayResize(g_hist_sell, 0);
      }
   }

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return rates_total;

   const int ps = PeriodSecondsSafe();
   const long bar_open_msc = BarOpenMsc((long)tick.time_msc, ps);
   const bool new_bar = (g_last_bar_open_msc != 0 && bar_open_msc != g_last_bar_open_msc);
   if(new_bar)
   {
      g_has_prev = false;
      g_last_bar_open_msc = bar_open_msc;
   }
   else if(g_last_bar_open_msc == 0)
   {
      g_last_bar_open_msc = bar_open_msc;
   }

   if(g_has_prev && g_prev_tick.bid > 0.0 && g_prev_tick.ask > 0.0 &&
      tick.bid > 0.0 && tick.ask > 0.0 &&
      SameBarMsc((long)g_prev_tick.time_msc, (long)tick.time_msc, ps))
   {
      const double pip = PipSize();
      const bool ask_changed = ((tick.flags & TICK_FLAG_ASK) != 0) || (tick.ask != g_prev_tick.ask);
      const bool bid_changed = ((tick.flags & TICK_FLAG_BID) != 0) || (tick.bid != g_prev_tick.bid);
      double dAskPips = 0.0;
      double dBidPips = 0.0;
      if(ask_changed)
         dAskPips = (tick.ask - g_prev_tick.ask) / pip;
      if(bid_changed)
         dBidPips = (tick.bid - g_prev_tick.bid) / pip;

      const bool ask_up = (dAskPips > 0.0);
      const bool ask_down = (dAskPips < 0.0);
      const bool ask_eq = (!ask_changed || dAskPips == 0.0);
      const bool bid_up = (dBidPips > 0.0);
      const bool bid_down = (dBidPips < 0.0);
      const bool bid_eq = (!bid_changed || dBidPips == 0.0);

      const bool buy_hit =
         (ask_up && (bid_up || bid_eq)) ||
         (bid_up && ask_eq);

      const bool sell_hit =
         (ask_down && (bid_down || bid_eq)) ||
         (bid_down && ask_eq);

      double buy_ref = 0.0;
      double sell_ref = 0.0;
      if(buy_hit)
         buy_ref = (ask_up ? tick.ask : tick.bid);
      if(sell_hit)
         sell_ref = (bid_down ? tick.bid : tick.ask);

      if(buy_hit)
      {
         PushTickRef(g_tick_refs_buy, g_tick_count_buy, kWindowTicks, buy_ref);
      }
      if(sell_hit)
      {
         PushTickRef(g_tick_refs_sell, g_tick_count_sell, kWindowTicks, sell_ref);
      }
   }

   g_prev_tick = tick;
   g_has_prev = true;

   double net_buy = NetFromTickRefs(g_tick_refs_buy, g_tick_count_buy, true);
   double net_sell = NetFromTickRefs(g_tick_refs_sell, g_tick_count_sell, false);
   double val_buy = (g_tick_count_buy >= kWindowTicks ? (net_buy / (double)g_tick_count_buy) : EMPTY_VALUE);
   double val_sell = (g_tick_count_sell >= kWindowTicks ? (net_sell / (double)g_tick_count_sell) : EMPTY_VALUE);

   if(!InpUseFFTFilter)
   {
      BufBuy[0] = val_buy;
      BufSell[0] = val_sell;
      return rates_total;
   }

   // Aplica filtro (FFT) no valor calculado
   double out_buy = EMPTY_VALUE;
   double out_sell = EMPTY_VALUE;

   if(val_buy != EMPTY_VALUE)
   {
      PushSample(g_hist_buy, g_hist_count_buy, InpSmoothLen, val_buy);
      out_buy = FFTFilterFromHist(g_hist_buy, g_hist_count_buy);
   }

   if(val_sell != EMPTY_VALUE)
   {
      PushSample(g_hist_sell, g_hist_count_sell, InpSmoothLen, val_sell);
      out_sell = FFTFilterFromHist(g_hist_sell, g_hist_count_sell);
   }

   BufBuy[0] = out_buy;
   BufSell[0] = out_sell;

   // Estado: somente em candle fechado (bar1 vs bar2).
   // +1/-1 no cruzamento; depois +2/+3 (ou -2/-3) conforme sobe/desce.
   if(new_bar && rates_total >= 3)
   {
      double b1 = BufBuy[1];
      double s1 = BufSell[1];
      double b2 = BufBuy[2];
      double s2 = BufSell[2];
      bool ok_state = (b1 != EMPTY_VALUE && s1 != EMPTY_VALUE && b2 != EMPTY_VALUE && s2 != EMPTY_VALUE);
      double st_buy = 0.0;
      double st_sell = 0.0;
      if(ok_state)
      {
         double eps = InpCrossEqualEps;
         if(eps < 0.0) eps = -eps;
         double diff1 = b1 - s1;
         double diff2 = b2 - s2;
         bool above1 = (diff1 > eps);
         bool below1 = (diff1 < -eps);

         // cruzamento por mudança de lado (mantém direção anterior mesmo se igualar)
         if(above1 && g_state_dir != 1)
         {
            g_state_dir = 1;
            st_buy = 1.0;
         }
         else if(below1 && g_state_dir != -1)
         {
            g_state_dir = -1;
            st_sell = -1.0;
         }
         else if(above1 && g_state_dir == 1)
         {
            // depois de +1: +2 se subindo/estável, +3 se descendo
            if(diff1 >= diff2) st_buy = 2.0;
            else st_buy = 3.0;
         }
         else if(below1 && g_state_dir == -1)
         {
            // depois de -1: -2 se descendo/estável, -3 se subindo
            if(diff1 <= diff2) st_sell = -2.0;
            else st_sell = -3.0;
         }
         else
         {
            // igualdade (dentro do eps): estado neutro explícito
            st_buy = 4.0;
            st_sell = -4.0;
         }
      }
      BufStateBuy[1] = st_buy;
      BufStateSell[1] = st_sell;
   }
   // Espelha o último estado no candle atual para aparecer no Data Window.
   BufStateBuy[0] = BufStateBuy[1];
   BufStateSell[0] = BufStateSell[1];

   return rates_total;
}
//+------------------------------------------------------------------+
