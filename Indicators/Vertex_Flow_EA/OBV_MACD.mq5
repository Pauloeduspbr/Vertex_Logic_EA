//+------------------------------------------------------------------+
//|                                                 OBV_MACD.mq5     |
//|                        MACD baseado em OBV (Tick ou Real)        |
//|         Histograma multi-cor: força, enfraquecimento, reversão   |
//+------------------------------------------------------------------+
#property copyright   "Nexus Confluence EA"
#property link        "https://adaptiveflow.systems"
#property version     "2.18"
#property description "MACD do OBV - Histogram + MACD Line + Signal Line"
#property description "v2.18: SYNC FIX - Apenas recalcular última barra em nova barra"
#property description "Fixed: Sincronização shift=1 para EA"

#property indicator_separate_window
#property indicator_plots   3  // Histogram + MACD + Signal
#property indicator_buffers  10
#property indicator_level1  0.0
#property indicator_levelcolor clrSilver

//--- Plot 1: Histograma com 4 cores
#property indicator_label1  "OBV Histogram"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_width1  2
#property indicator_color1  clrLime,clrRed,clrPaleGreen,clrLightPink

//--- Plot 2: MACD Line (OBV MACD)
#property indicator_label2  "OBV MACD"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrangeRed
#property indicator_width2  1
#property indicator_style2  STYLE_SOLID

//--- Plot 3: Signal Line (OBV Signal)
#property indicator_label3  "OBV Signal"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrCornflowerBlue
#property indicator_width3  1
#property indicator_style3  STYLE_SOLID

#include <MovingAverages.mqh>

//--- Inputs
input int   InpFastEMA=12;                // Fast EMA Period
input int   InpSlowEMA=26;                // Slow EMA Period
input int   InpSignalSMA=9;               // Signal SMA Period
input int   InpObvSmooth=5;               // OBV Smoothing SMA Period
input bool  InpUseTickVolume=true;        // Use Tick Volume (true) ou Real Volume (false)
input bool  InpShowMACDLine=true;         // Show MACD Line
input bool  InpShowSignalLine=true;       // Show Signal Line
input int   InpThreshPeriod=34;           // Threshold EMA period (|hist|)
input double InpThreshMult=0.6;           // Threshold multiplier (default 0.6)

//--- Buffers
// Plot buffers (visible)
double HistBuffer[];        // Histograma (MACD - Signal)
double HistColorBuffer[];   // Índice de cor
double MacdLineBuffer[];    // Linha MACD
double SignalLineBuffer[];  // Linha Signal
double ThresholdBuffer[];   // Linha de limiar

// Calculation buffers (internal)
double FastObvEmaBuffer[];
double SlowObvEmaBuffer[];
double ObvRawBuffer[];      // OBV bruto (cumulativo)
double ObvSmoothBuffer[];   // OBV suavizado (SMA)
double AbsHistCalc[];       // |histogram| para threshold

enum ENUM_PLOT_COLOR_INDEX {
   COLOR_POS_STRONG=0,  // Verde forte (hist >=0 e aumentando)
   COLOR_NEG_STRONG=1,  // Vermelho forte (hist <0 e diminuindo)
   COLOR_POS_WEAK =2,   // Verde fraco (hist >=0 mas enfraquecendo)
   COLOR_NEG_WEAK =3    // Vermelho fraco (hist <0 mas recuperando)
};

//+------------------------------------------------------------------+
//| OnInit                                                          |
//+------------------------------------------------------------------+
int OnInit()
{
   // ═══════════════════════════════════════════════════════════════
   // Buffer mapping: 3 visible plots + 7 calculation buffers
   // Plot index 0: Histogram (buffers 0+1: data + color index)
   // Plot index 1: MACD Line (buffer 2: visible)
   // Plot index 2: Signal Line (buffer 3: visible)
   // Buffer 4: Threshold (calculation - EA reads)
   // Buffers 5-9: Calculation buffers
   // ═══════════════════════════════════════════════════════════════
   
   // Plot index 0 (Plot 1 in properties): Histogram with color index
   SetIndexBuffer(0, HistBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, HistColorBuffer, INDICATOR_COLOR_INDEX);
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_HISTOGRAM);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 2);
   PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 4);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, clrLime);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, clrRed);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, clrPaleGreen);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 3, clrLightPink);
   PlotIndexSetString(0, PLOT_LABEL, "OBV Histogram");
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   
   // Plot index 1 (Plot 2 in properties): MACD Line (OBV MACD - laranja)
   SetIndexBuffer(2, MacdLineBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, clrOrangeRed);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, 1);
   PlotIndexSetInteger(1, PLOT_LINE_STYLE, STYLE_SOLID);
   PlotIndexSetString(1, PLOT_LABEL, "OBV MACD");
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   // Plot index 2 (Plot 3 in properties): Signal Line (azul)
   SetIndexBuffer(3, SignalLineBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, clrCornflowerBlue);
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, 1);
   PlotIndexSetInteger(2, PLOT_LINE_STYLE, STYLE_SOLID);
   PlotIndexSetString(2, PLOT_LABEL, "OBV Signal");
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   // Buffer 4: Threshold (calculation only - EA reads this)
   SetIndexBuffer(4, ThresholdBuffer, INDICATOR_CALCULATIONS);

   // Calculation buffers (INDICATOR_CALCULATIONS)
   SetIndexBuffer(5, FastObvEmaBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, SlowObvEmaBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, ObvRawBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(8, ObvSmoothBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(9, AbsHistCalc, INDICATOR_CALCULATIONS);

   string short_name = StringFormat("OBV MACD (%d,%d,%d,%d)", 
                                    InpFastEMA, InpSlowEMA, InpSignalSMA, InpObvSmooth);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnCalculate                                                     |
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
   if(rates_total < MathMax(InpSlowEMA + InpSignalSMA + 2, InpObvSmooth + 2))
      return(0);

   // ✅ FIX v2.18: Apenas recalcular última barra em NOVA BARRA, não a cada tick
   int start = prev_calculated;
   if(start <= 0)
   {
      ArrayInitialize(HistBuffer, 0.0);
      ArrayInitialize(HistColorBuffer, 0.0);
      ArrayInitialize(MacdLineBuffer, EMPTY_VALUE);
      ArrayInitialize(SignalLineBuffer, EMPTY_VALUE);
      // ✅ v2.50 CRITICAL FIX: DO NOT initialize ThresholdBuffer to zero!
      // It causes overflow when calculating EMA from zero base
      // ArrayInitialize(ThresholdBuffer, 0.0);  // REMOVED
      ArrayInitialize(FastObvEmaBuffer, 0.0);
      ArrayInitialize(SlowObvEmaBuffer, 0.0);
      ArrayInitialize(ObvRawBuffer, 0.0);
      ArrayInitialize(ObvSmoothBuffer, 0.0);
      ArrayInitialize(AbsHistCalc, 0.0);
      start = 1; // OBV começa da barra 1
   }
   else
   {
      // ✅ FIX v2.18: Calcular apenas barra atual (shift=0)
      // Barra fechada (shift=1) JÁ FOI CALCULADA no OnCalculate anterior
      start = rates_total - 1; // Apenas última barra
   }

   // ═══════════════════════════════════════════════════════════════
   // STEP 1: Calculate RAW OBV (cumulative)
   // ═══════════════════════════════════════════════════════════════
   for(int i = start; i < rates_total; ++i)
   {
      double delta = 0.0;
      double vol = InpUseTickVolume ? (double)tick_volume[i] : (double)volume[i];
      
      if(close[i] > close[i-1])
         delta = vol;
      else if(close[i] < close[i-1])
         delta = -vol;
      
      ObvRawBuffer[i] = ObvRawBuffer[i-1] + delta;
   }

   // ═══════════════════════════════════════════════════════════════
   // STEP 2: Smooth OBV with SMA if configured
   // ═══════════════════════════════════════════════════════════════
   if(InpObvSmooth > 1)
      SimpleMAOnBuffer(rates_total, prev_calculated, 0, InpObvSmooth, ObvRawBuffer, ObvSmoothBuffer);
   else
      ArrayCopy(ObvSmoothBuffer, ObvRawBuffer, 0, 0, WHOLE_ARRAY);

   // ═══════════════════════════════════════════════════════════════
   // STEP 3: Calculate EMAs on OBV (use smoothed OBV directly)
   // ═══════════════════════════════════════════════════════════════
   // ✅ FIX: Always ensure EMA buffers are initialized at position 0
   if(prev_calculated == 0)
   {
      FastObvEmaBuffer[0] = ObvSmoothBuffer[0];
      SlowObvEmaBuffer[0] = ObvSmoothBuffer[0];
   }
   else if(FastObvEmaBuffer[0] == 0.0 && ObvSmoothBuffer[0] != 0.0)
   {
      // ✅ FIX CRITICAL: If EMA buffers are zeroed but OBV exists, reinitialize
      FastObvEmaBuffer[0] = ObvSmoothBuffer[0];
      SlowObvEmaBuffer[0] = ObvSmoothBuffer[0];
   }
   
   double kFast = 2.0 / (InpFastEMA + 1.0);
   double kSlow = 2.0 / (InpSlowEMA + 1.0);
   
   for(int i = start; i < rates_total; ++i)
   {
      FastObvEmaBuffer[i] = FastObvEmaBuffer[i-1] + kFast * (ObvSmoothBuffer[i] - FastObvEmaBuffer[i-1]);
      SlowObvEmaBuffer[i] = SlowObvEmaBuffer[i-1] + kSlow * (ObvSmoothBuffer[i] - SlowObvEmaBuffer[i-1]);
      MacdLineBuffer[i] = FastObvEmaBuffer[i] - SlowObvEmaBuffer[i];
   }

   // ═══════════════════════════════════════════════════════════════
   // STEP 4: Calculate Signal Line (SMA of MACD)
   // ═══════════════════════════════════════════════════════════════
   SimpleMAOnBuffer(rates_total, prev_calculated, 0, InpSignalSMA, MacdLineBuffer, SignalLineBuffer);

   // ═══════════════════════════════════════════════════════════════
   // STEP 5: Calculate Histogram and Color Index
   // FIXED: Ensure first bar gets a valid color (not 0 default)
   // ═══════════════════════════════════════════════════════════════
   for(int i = start; i < rates_total; ++i)
   {
      double hist = MacdLineBuffer[i] - SignalLineBuffer[i];
      HistBuffer[i] = hist;
      AbsHistCalc[i] = MathAbs(hist);
      
      int color_index = 0;
      
      if(i == 0)
      {
         // First bar: use sign only
         color_index = (hist >= 0.0) ? COLOR_POS_STRONG : COLOR_NEG_STRONG;
      }
      else
      {
         double prev_hist = HistBuffer[i-1];
         
         if(hist >= 0.0)
         {
            // Positive histogram (above zero)
            if(hist > prev_hist)
               color_index = COLOR_POS_STRONG;  // 0: Strong green (increasing)
            else
               color_index = COLOR_POS_WEAK;    // 2: Weak green (weakening)
         }
         else
         {
            // Negative histogram (below zero)
            if(hist < prev_hist)
               color_index = COLOR_NEG_STRONG;  // 1: Strong red (decreasing)
            else
               color_index = COLOR_NEG_WEAK;    // 3: Weak red (recovering)
         }
      }
      
      HistColorBuffer[i] = (double)color_index;
   }

   // ═══════════════════════════════════════════════════════════════
   // STEP 6: Calculate Threshold = EMA(|hist| * mult)
   // ✅ v2.50 CRITICAL FIX: Proper initialization to prevent overflow
   // ═══════════════════════════════════════════════════════════════
   
   if(InpThreshPeriod <= 1)
   {
      // No smoothing - use direct value
      for(int i = start; i < rates_total; ++i)
         ThresholdBuffer[i] = AbsHistCalc[i] * InpThreshMult;
   }
   else
   {
      // ✅ v2.50 FIX: Initialize ThresholdBuffer[0] if not set
      if(prev_calculated == 0 || ThresholdBuffer[0] == 0.0)
      {
         // Seed with first non-zero value or minimal threshold
         ThresholdBuffer[0] = MathMax(AbsHistCalc[0] * InpThreshMult, 0.00001);
      }
      
      // EMA of (|hist| * multiplier)
      double kT = 2.0 / (InpThreshPeriod + 1.0);
      for(int i = MathMax(start, 1); i < rates_total; ++i)  // ✅ Start from 1 minimum
      {
         double scaled_input = AbsHistCalc[i] * InpThreshMult;
         ThresholdBuffer[i] = ThresholdBuffer[i-1] + kT * (scaled_input - ThresholdBuffer[i-1]);
         
         // ✅ v2.50: Sanity check - prevent insane values
         if(ThresholdBuffer[i] > 1e9 || ThresholdBuffer[i] < 0)
         {
            ThresholdBuffer[i] = MathMax(scaled_input, 0.00001);  // Reset to current value
         }
      }
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
