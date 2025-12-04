//+------------------------------------------------------------------+
//|                                                 ADXWCloud.mq5   |
//|                        ADX + ADXR + DI Cloud (MT5)              |
//|                    Inspired by ADXWCloud 1.0 visual style       |
//+------------------------------------------------------------------+
#property copyright "Vertex Flow"
#property version   "1.00"
#property description "ADX with ADXR and DI+ / DI- cloud"

#property indicator_separate_window
#property indicator_plots   4
#property indicator_buffers 6

//--- Plot 0: DI+ / DI- Cloud (fill between +DI and -DI)
#property indicator_label1  "+DI/-DI Cloud"
#property indicator_type1   DRAW_FILLING
#property indicator_color1  clrLime, clrRed
#property indicator_width1  1

//--- Plot 1: ADX line (blue)
#property indicator_label2  "ADX"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_width2  2

//--- Plot 2: ADXR line (orange dotted)
#property indicator_label3  "ADXR"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrOrange
#property indicator_width3  1
#property indicator_style3  STYLE_DOT

//--- Plot 3: DI+ and DI- lines (for separate reading if needed)
#property indicator_label4  "DI+ / DI-"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrLime, clrRed
#property indicator_width4  2

//--- Levels (classic trend threshold)
#property indicator_level1  20.0
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

//--- Inputs
input int   Inp_ADX_Period = 14;   // ADX period
input int   Inp_ADXR_Period = 20;  // ADXR smoothing period

//--- Buffers
// Plot 0: cloud
double PlusDICloudBuffer[];   // +DI for cloud
double MinusDICloudBuffer[];  // -DI for cloud

// Plot 1: ADX
double ADXBuffer[];

// Plot 2: ADXR
double ADXRBuffer[];

// Plot 3: DI+ / DI- lines (two colors in same buffer)
double DILineBuffer[];

// Internal handle for standard ADX
int adx_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
int OnInit()
{
   //--- basic checks
   if(Inp_ADX_Period <= 1)
   {
      Print("ADXWCloud: invalid ADX period, must be > 1");
      return(INIT_FAILED);
   }
   if(Inp_ADXR_Period < 1)
   {
      Print("ADXWCloud: invalid ADXR period, must be >= 1");
      return(INIT_FAILED);
   }

   //--- create built-in ADX handle
   adx_handle = iADX(_Symbol, PERIOD_CURRENT, Inp_ADX_Period);
   if(adx_handle == INVALID_HANDLE)
   {
      Print("ADXWCloud: failed to create iADX handle");
      return(INIT_FAILED);
   }

   //--- map buffers
   // Plot 0: cloud between +DI and -DI
   SetIndexBuffer(0, PlusDICloudBuffer,  INDICATOR_DATA);
   SetIndexBuffer(1, MinusDICloudBuffer, INDICATOR_DATA);

   // Plot 1: ADX
   SetIndexBuffer(2, ADXBuffer, INDICATOR_DATA);

   // Plot 2: ADXR
   SetIndexBuffer(3, ADXRBuffer, INDICATOR_DATA);

   // Plot 3: DI line (single buffer with two colors)
   SetIndexBuffer(4, DILineBuffer, INDICATOR_DATA);

   // We use DI+ for color index 0 and DI- for color index 1 visually
   // but for EA leitura é mais simples usar os próprios buffers da cloud.

   //--- set series
   ArraySetAsSeries(PlusDICloudBuffer,  true);
   ArraySetAsSeries(MinusDICloudBuffer, true);
   ArraySetAsSeries(ADXBuffer,          true);
   ArraySetAsSeries(ADXRBuffer,         true);
   ArraySetAsSeries(DILineBuffer,       true);

   IndicatorSetString(INDICATOR_SHORTNAME,
                      StringFormat("ADXWCloud (%d,%d)", Inp_ADX_Period, Inp_ADXR_Period));

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(adx_handle != INVALID_HANDLE)
      IndicatorRelease(adx_handle);
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
   if(rates_total <= Inp_ADX_Period + 2)
      return(0);

   //--- get built-in ADX buffers
   static double adx_values[];
   static double plusdi_values[];
   static double minusdi_values[];

   ArraySetAsSeries(adx_values,     true);
   ArraySetAsSeries(plusdi_values,  true);
   ArraySetAsSeries(minusdi_values, true);

   int copied1 = CopyBuffer(adx_handle, 0, 0, rates_total, adx_values);     // ADX
   int copied2 = CopyBuffer(adx_handle, 1, 0, rates_total, plusdi_values);  // +DI
   int copied3 = CopyBuffer(adx_handle, 2, 0, rates_total, minusdi_values); // -DI

   if(copied1 <= 0 || copied2 <= 0 || copied3 <= 0)
      return(0);

   int start = prev_calculated;
   if(start <= 0)
      start = Inp_ADX_Period + 2; // garantir dados suficientes

   //--- fill buffers
   for(int i = start; i < rates_total; ++i)
   {
      double adx    = adx_values[i];
      double plusDI = plusdi_values[i];
      double minusDI= minusdi_values[i];

      // Cloud buffers
      PlusDICloudBuffer[i]  = plusDI;
      MinusDICloudBuffer[i] = minusDI;

      // ADX
      ADXBuffer[i] = adx;

      // DI line buffer: usamos +DI (verde) quando maior que -DI, senão -DI (vermelho)
      DILineBuffer[i] = (plusDI >= minusDI ? plusDI : minusDI);
   }

   //--- ADXR: média móvel simples do ADX
   if(Inp_ADXR_Period <= 1)
   {
      for(int i = start; i < rates_total; ++i)
         ADXRBuffer[i] = ADXBuffer[i];
   }
   else
   {
      for(int i = start; i < rates_total; ++i)
      {
         double sum = 0.0;
         int    cnt = 0;
         for(int j = 0; j < Inp_ADXR_Period && (i + j) < rates_total; ++j)
         {
            sum += ADXBuffer[i + j];
            cnt++;
         }
         ADXRBuffer[i] = (cnt > 0 ? sum / cnt : ADXBuffer[i]);
      }
   }

   return(rates_total);
}

//+------------------------------------------------------------------+
// Conveniência para EA via iCustom:
//  Buffer 0: +DI cloud (PlusDICloudBuffer)
//  Buffer 1: -DI cloud (MinusDICloudBuffer)
//  Buffer 2: ADX
//  Buffer 3: ADXR
//  Buffer 4: DI line (maior entre +DI e -DI, apenas visual)
//+------------------------------------------------------------------+
