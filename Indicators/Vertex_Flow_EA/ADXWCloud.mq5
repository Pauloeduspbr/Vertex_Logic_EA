//+------------------------------------------------------------------+
//|                                                 ADXWCloud.mq5   |
//|                        ADX + ADXR + DI Cloud (MT5)              |
//|                    Manual ADXW Calculation                      |
//+------------------------------------------------------------------+
#property copyright "Vertex Flow"
#property version   "1.00"
#property description "ADXW (Wilder's) with ADXR and DI+ / DI- cloud"

#property indicator_separate_window
#property indicator_plots   3
#property indicator_buffers 8

//--- Plot 0: DI+ / DI- Cloud
#property indicator_label1  "DI+;DI-"
#property indicator_type1   DRAW_FILLING
#property indicator_color1  clrLimeGreen, clrHotPink
#property indicator_width1  1

//--- Plot 1: ADX line
#property indicator_label2  "ADX"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_width2  2

//--- Plot 2: ADXR line
#property indicator_label3  "ADXR"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrOrange
#property indicator_width3  1
#property indicator_style3  STYLE_DOT

//--- Levels
#property indicator_level1  20.0
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT
#property indicator_minimum 0
#property indicator_maximum 100

input int      Inp_ADX_Period        = 14;            // ADX period
input int      Inp_ADXR_Period       = 20;            // ADXR period
input color    Inp_BullishCloudColor = clrLimeGreen;  // Bullish cloud color
input color    Inp_BearishCloudColor = clrHotPink;    // Bearish cloud color
input int      Inp_FillTransparency  = 80;            // Filling colors transparency (0..255)

//--- Buffers
double PlusDIBuffer[];    // 0
double MinusDIBuffer[];   // 1
double ADXBuffer[];       // 2
double ADXRBuffer[];      // 3

//--- Calculation Buffers
double TRBuffer[];        // 4 (Smoothed TR)
double PlusDMBuffer[];    // 5 (Smoothed +DM)
double MinusDMBuffer[];   // 6 (Smoothed -DM)
double DXBuffer[];        // 7 (Raw DX)

//+------------------------------------------------------------------+
int OnInit()
{
   if(Inp_ADX_Period <= 1) return(INIT_FAILED);

   SetIndexBuffer(0, PlusDIBuffer,  INDICATOR_DATA);
   SetIndexBuffer(1, MinusDIBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, ADXBuffer,     INDICATOR_DATA);
   SetIndexBuffer(3, ADXRBuffer,    INDICATOR_DATA);
   
   SetIndexBuffer(4, TRBuffer,      INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, PlusDMBuffer,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, MinusDMBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, DXBuffer,      INDICATOR_CALCULATIONS);

   //--- aplicar cores configuráveis à nuvem com transparência
   // Nota: ColorToARGB espera alpha entre 0 (transparente) e 255 (opaco).
   // Se Inp_FillTransparency for 0-255, usamos direto.
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, ColorToARGB(Inp_BullishCloudColor, Inp_FillTransparency));
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, ColorToARGB(Inp_BearishCloudColor, Inp_FillTransparency));

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("ADXW Cloud (%d,%d)", Inp_ADX_Period, Inp_ADXR_Period));
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 20.0);

   return(INIT_SUCCEEDED);
}

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
   if(rates_total < Inp_ADX_Period + Inp_ADXR_Period) return(0);

   int start;
   if(prev_calculated < 2)
   {
      start = 1;
      ArrayInitialize(TRBuffer, 0);
      ArrayInitialize(PlusDMBuffer, 0);
      ArrayInitialize(MinusDMBuffer, 0);
      ArrayInitialize(DXBuffer, 0);
      ArrayInitialize(ADXBuffer, 0);
      ArrayInitialize(ADXRBuffer, 0);
      ArrayInitialize(PlusDIBuffer, 0);
      ArrayInitialize(MinusDIBuffer, 0);
   }
   else start = prev_calculated - 1;

   for(int i = start; i < rates_total; i++)
   {
      // 1. Calculate Raw TR, +DM, -DM
      double tr = MathMax(high[i] - low[i], MathMax(MathAbs(high[i] - close[i-1]), MathAbs(low[i] - close[i-1])));
      double dm_plus = (high[i] - high[i-1]);
      double dm_minus = (low[i-1] - low[i]);

      if(dm_plus < 0) dm_plus = 0;
      if(dm_minus < 0) dm_minus = 0;
      
      if(dm_plus == dm_minus) { dm_plus = 0; dm_minus = 0; }
      else if(dm_plus < dm_minus) dm_plus = 0;
      else if(dm_minus < dm_plus) dm_minus = 0;

      // 2. Smooth TR, +DM, -DM (Wilder's Smoothing)
      if(i < Inp_ADX_Period)
      {
         // Accumulate for initial SMA
         TRBuffer[i] = TRBuffer[i-1] + tr;
         PlusDMBuffer[i] = PlusDMBuffer[i-1] + dm_plus;
         MinusDMBuffer[i] = MinusDMBuffer[i-1] + dm_minus;
      }
      else if(i == Inp_ADX_Period)
      {
         // First smoothed value is the Sum (Wilder's convention)
         TRBuffer[i] = TRBuffer[i-1] + tr;
         PlusDMBuffer[i] = PlusDMBuffer[i-1] + dm_plus;
         MinusDMBuffer[i] = MinusDMBuffer[i-1] + dm_minus;
      }
      else
      {
         // Wilder's Smoothing: Previous - (Previous / N) + Current
         TRBuffer[i] = TRBuffer[i-1] - (TRBuffer[i-1] / Inp_ADX_Period) + tr;
         PlusDMBuffer[i] = PlusDMBuffer[i-1] - (PlusDMBuffer[i-1] / Inp_ADX_Period) + dm_plus;
         MinusDMBuffer[i] = MinusDMBuffer[i-1] - (MinusDMBuffer[i-1] / Inp_ADX_Period) + dm_minus;
      }

      // 3. Calculate DI+ and DI-
      double tr_smooth = TRBuffer[i];
      if(tr_smooth == 0) tr_smooth = 1.0;

      PlusDIBuffer[i] = 100.0 * PlusDMBuffer[i] / tr_smooth;
      MinusDIBuffer[i] = 100.0 * MinusDMBuffer[i] / tr_smooth;

      // 4. Calculate DX
      double di_sum = PlusDIBuffer[i] + MinusDIBuffer[i];
      double di_diff = MathAbs(PlusDIBuffer[i] - MinusDIBuffer[i]);
      
      if(di_sum == 0) DXBuffer[i] = 0;
      else DXBuffer[i] = 100.0 * di_diff / di_sum;

      // 5. Calculate ADX (Smoothed DX)
      // We start accumulating DX only after the first valid DI/DX (at i = Inp_ADX_Period)
      
      if(i < Inp_ADX_Period)
      {
         ADXBuffer[i] = 0; // Not valid yet
      }
      else if(i == Inp_ADX_Period)
      {
         ADXBuffer[i] = DXBuffer[i]; // Start accumulation
      }
      else if(i < 2 * Inp_ADX_Period - 1)
      {
         ADXBuffer[i] = ADXBuffer[i-1] + DXBuffer[i]; // Accumulate
      }
      else if(i == 2 * Inp_ADX_Period - 1)
      {
         // First ADX value is Average of DX over period
         ADXBuffer[i] = (ADXBuffer[i-1] + DXBuffer[i]) / Inp_ADX_Period;
      }
      else
      {
         // Wilder's Smoothing for ADX
         ADXBuffer[i] = (ADXBuffer[i-1] * (Inp_ADX_Period - 1) + DXBuffer[i]) / Inp_ADX_Period;
      }

      // 6. Calculate ADXR
      if(i >= Inp_ADXR_Period)
      {
         ADXRBuffer[i] = (ADXBuffer[i] + ADXBuffer[i - Inp_ADXR_Period]) / 2.0;
      }
      else
      {
         ADXRBuffer[i] = ADXBuffer[i];
      }
   }

   return(rates_total);
}
