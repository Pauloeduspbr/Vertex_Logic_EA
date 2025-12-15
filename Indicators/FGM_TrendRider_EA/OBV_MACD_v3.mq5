//+------------------------------------------------------------------+
//|                                                 OBV_MACD_v3.mq5  |
//|                        MACD baseado em OBV (Tick ou Real)        |
//|      Versão Otimizada para Alta Performance e Sincronia com EA   |
//+------------------------------------------------------------------+
#property copyright   "Nexus Confluence EA"
#property link        "https://adaptiveflow.systems"
#property version     "3.00"
#property description "OBV MACD - Logic Refactored for EA Stability"
#property description "Fixed: Data Gap handling on cumulative arrays"
#property description "Fixed: Array index out of range protections"

#property indicator_separate_window
#property indicator_plots   3
#property indicator_buffers 10 

//--- Visual Settings
#property indicator_level1  0.0
#property indicator_levelcolor clrSilver

// Plot 1: Histogram
#property indicator_label1  "OBV Histogram"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_width1  2
#property indicator_color1  clrLime,clrRed,clrPaleGreen,clrLightPink

// Plot 2: MACD Line
#property indicator_label2  "OBV MACD"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrangeRed
#property indicator_width2  1
#property indicator_style2  STYLE_SOLID

// Plot 3: Signal Line
#property indicator_label3  "OBV Signal"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrCornflowerBlue
#property indicator_width3  1
#property indicator_style3  STYLE_SOLID

#include <MovingAverages.mqh>

//--- Inputs
input int    InpFastEMA        = 12;    // Fast EMA Period
input int    InpSlowEMA        = 26;    // Slow EMA Period
input int    InpSignalSMA      = 9;     // Signal SMA Period
input int    InpObvSmooth      = 5;     // OBV Smoothing SMA Period
input bool   InpUseTickVolume  = true;  // Use Tick Volume (true) or Real (false)
input int    InpThreshPeriod   = 34;    // Threshold EMA period
input double InpThreshMult     = 0.6;   // Threshold multiplier

//--- Buffers
double HistBuffer[];        // 0: Data
double HistColorBuffer[];   // 1: Color Index
double MacdLineBuffer[];    // 2: MACD Line
double SignalLineBuffer[];  // 3: Signal Line
double ThresholdBuffer[];   // 4: EA Reading Buffer

// Internal Calculation Buffers
double FastObvEmaBuffer[];  // 5
double SlowObvEmaBuffer[];  // 6
double ObvRawBuffer[];      // 7
double ObvSmoothBuffer[];   // 8
double AbsHistCalc[];       // 9

// Enum for Colors
enum ENUM_PLOT_COLOR_INDEX {
   COLOR_POS_STRONG=0, 
   COLOR_NEG_STRONG=1, 
   COLOR_POS_WEAK =2, 
   COLOR_NEG_WEAK =3 
};

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   // Mapping Buffers
   SetIndexBuffer(0, HistBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, HistColorBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, MacdLineBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, SignalLineBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, ThresholdBuffer, INDICATOR_CALCULATIONS); // EA reads this
   
   SetIndexBuffer(5, FastObvEmaBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, SlowObvEmaBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, ObvRawBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(8, ObvSmoothBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(9, AbsHistCalc, INDICATOR_CALCULATIONS);

   // Plot Configuration
   PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 4);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   // Naming
   string short_name = StringFormat("OBV_MACD(%d,%d,%d)", InpFastEMA, InpSlowEMA, InpSignalSMA);
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnCalculate                                                      |
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
   // 1. Basic Validation
   if(rates_total < MathMax(InpSlowEMA, InpThreshPeriod) + 2)
      return(0);

   // 2. Loop Management (The most critical part for Synchronization)
   int start;
   
   if(prev_calculated == 0)
   {
      // First run or full recalculation
      ArrayInitialize(HistBuffer, 0.0);
      ArrayInitialize(MacdLineBuffer, 0.0);
      ArrayInitialize(SignalLineBuffer, 0.0);
      ArrayInitialize(ThresholdBuffer, 0.0);
      ArrayInitialize(ObvRawBuffer, 0.0);
      
      start = 1; // Start at 1 because OBV depends on i-1
      
      // Seed the first value for OBV
      double vol = InpUseTickVolume ? (double)tick_volume[0] : (double)volume[0];
      ObvRawBuffer[0] = vol; 
   }
   else
   {
      // Incremental update. 
      // We go back 1 bar to handle the "Open Bar" correctly and ensure no gap.
      start = prev_calculated - 1;
   }

   // --- STEP 1: OBV Calculation (Cumulative) ---
   // Logic: Close > PrevClose => +Vol, Close < PrevClose => -Vol
   for(int i = start; i < rates_total; i++)
   {
      // Safety check for index 0
      if(i == 0) {
         double vol = InpUseTickVolume ? (double)tick_volume[0] : (double)volume[0];
         ObvRawBuffer[0] = vol; 
         continue; 
      }

      double delta = 0.0;
      double vol = InpUseTickVolume ? (double)tick_volume[i] : (double)volume[i];
      
      if(close[i] > close[i-1])      delta = vol;
      else if(close[i] < close[i-1]) delta = -vol;
      
      // Cumulative sum logic
      ObvRawBuffer[i] = ObvRawBuffer[i-1] + delta;
   }

   // --- STEP 2: Smoothing OBV ---
   if(InpObvSmooth > 1)
      SimpleMAOnBuffer(rates_total, prev_calculated, 0, InpObvSmooth, ObvRawBuffer, ObvSmoothBuffer);
   else
      ArrayCopy(ObvSmoothBuffer, ObvRawBuffer); // Direct copy if no smoothing

   // --- STEP 3: MACD Calculation (Manual EMA for precision) ---
   // We need manual calculation to ensure synchronization with the custom OBV buffer
   double kFast = 2.0 / (InpFastEMA + 1.0);
   double kSlow = 2.0 / (InpSlowEMA + 1.0);
   
   // Handle initialization of EMAs if full recalc
   if(prev_calculated == 0)
   {
      FastObvEmaBuffer[0] = ObvSmoothBuffer[0];
      SlowObvEmaBuffer[0] = ObvSmoothBuffer[0];
      // Fill initial part up to start
      for(int i=1; i<start; i++) {
          FastObvEmaBuffer[i] = FastObvEmaBuffer[i-1] + kFast * (ObvSmoothBuffer[i] - FastObvEmaBuffer[i-1]);
          SlowObvEmaBuffer[i] = SlowObvEmaBuffer[i-1] + kSlow * (ObvSmoothBuffer[i] - SlowObvEmaBuffer[i-1]);
      }
   }

   for(int i = start; i < rates_total; i++)
   {
      if(i == 0) continue; // Skip 0, handled in init
      
      FastObvEmaBuffer[i] = FastObvEmaBuffer[i-1] + kFast * (ObvSmoothBuffer[i] - FastObvEmaBuffer[i-1]);
      SlowObvEmaBuffer[i] = SlowObvEmaBuffer[i-1] + kSlow * (ObvSmoothBuffer[i] - SlowObvEmaBuffer[i-1]);
      
      MacdLineBuffer[i] = FastObvEmaBuffer[i] - SlowObvEmaBuffer[i];
   }

   // --- STEP 4: Signal Line ---
   SimpleMAOnBuffer(rates_total, prev_calculated, 0, InpSignalSMA, MacdLineBuffer, SignalLineBuffer);

   // --- STEP 5: Histogram & Threshold ---
   // Calculate Threshold EMA manually to export to EA
   double kThresh = 2.0 / (InpThreshPeriod + 1.0);
   
   if(prev_calculated == 0) ThresholdBuffer[0] = 0.0;

   for(int i = start; i < rates_total; i++)
   {
      // Histogram
      double hist = MacdLineBuffer[i] - SignalLineBuffer[i];
      HistBuffer[i] = hist;
      double absHist = MathAbs(hist);
      AbsHistCalc[i] = absHist;

      // Threshold Calculation
      if(InpThreshPeriod <= 1) {
         ThresholdBuffer[i] = absHist * InpThreshMult;
      } else {
         if(i > 0) {
             double inputVal = absHist * InpThreshMult;
             // Standard EMA formula
             ThresholdBuffer[i] = ThresholdBuffer[i-1] + kThresh * (inputVal - ThresholdBuffer[i-1]);
         } else {
             ThresholdBuffer[0] = absHist * InpThreshMult;
         }
      }

      // Coloring Logic (No change to logic, just cleaner implementation)
      int color_idx = 0;
      if(i > 0)
      {
         double prev_hist = HistBuffer[i-1];
         if(hist >= 0) color_idx = (hist > prev_hist) ? COLOR_POS_STRONG : COLOR_POS_WEAK;
         else          color_idx = (hist < prev_hist) ? COLOR_NEG_STRONG : COLOR_NEG_WEAK;
      }
      else
      {
         color_idx = (hist >= 0) ? COLOR_POS_STRONG : COLOR_NEG_STRONG;
      }
      HistColorBuffer[i] = (double)color_idx;
   }

   // Return correct rates_total to maintain sync
   return(rates_total);
}
//+------------------------------------------------------------------+