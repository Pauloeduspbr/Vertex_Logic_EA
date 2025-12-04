//+------------------------------------------------------------------+
//|                                                 ADXWCloud.mq5   |
//|                        ADX + ADXR + DI Cloud (MT5)              |
//|                    Inspired by ADXWCloud 1.0 visual style       |
//+------------------------------------------------------------------+
#property copyright "Vertex Flow"
#property version   "1.00"
#property description "ADX with ADXR and DI+ / DI- cloud"

#property indicator_separate_window
#property indicator_plots   3
#property indicator_buffers 4

//--- Plot 0: DI+ / DI- Cloud (fill between +DI and -DI)
#property indicator_label1  "DI+;DI-"
#property indicator_type1   DRAW_FILLING
#property indicator_color1  clrLimeGreen, clrHotPink
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

//--- Levels (classic trend threshold)
#property indicator_level1  20.0
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

//--- Inputs (espelhando ADXW Cloud 1.0)
input int      Inp_ADX_Period        = 14;            // ADX period
input int      Inp_ADXR_Period       = 20;            // ADXR period
input color    Inp_BullishCloudColor = clrLimeGreen;  // Bullish cloud color
input color    Inp_BearishCloudColor = clrHotPink;    // Bearish cloud color
input int      Inp_FillTransparency  = 80;            // Filling colors transparency (0..255)

//--- Buffers
double PlusDIBuffer[];    // Buffer 0: +DI (para cloud)
double MinusDIBuffer[];   // Buffer 1: -DI (para cloud)
double ADXBuffer[];       // Buffer 2: ADX
double ADXRBuffer[];      // Buffer 3: ADXR

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

   //--- create built-in ADX handle
   adx_handle = iADX(_Symbol, PERIOD_CURRENT, Inp_ADX_Period);
   if(adx_handle == INVALID_HANDLE)
   {
      Print("ADXWCloud: failed to create iADX handle");
      return(INIT_FAILED);
   }

   //--- map buffers
   SetIndexBuffer(0, PlusDIBuffer,  INDICATOR_DATA);
   SetIndexBuffer(1, MinusDIBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, ADXBuffer,     INDICATOR_DATA);
   SetIndexBuffer(3, ADXRBuffer,    INDICATOR_DATA);

   //--- aplicar cores configuráveis à nuvem
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, Inp_BullishCloudColor);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, Inp_BearishCloudColor);

   IndicatorSetString(INDICATOR_SHORTNAME,
                      StringFormat("ADXW Cloud (%d,%d)", Inp_ADX_Period, Inp_ADXR_Period));

   //--- nível configurável
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 20.0);

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
   if(rates_total <= Inp_ADX_Period + Inp_ADXR_Period)
      return(0);

   //--- get built-in ADX buffers
   double adx_main[];
   double plusdi_values[];
   double minusdi_values[];

   int copied1 = CopyBuffer(adx_handle, MAIN_LINE,    0, rates_total, adx_main);
   int copied2 = CopyBuffer(adx_handle, PLUSDI_LINE,  0, rates_total, plusdi_values);
   int copied3 = CopyBuffer(adx_handle, MINUSDI_LINE, 0, rates_total, minusdi_values);

   if(copied1 <= 0 || copied2 <= 0 || copied3 <= 0)
      return(0);

   int start = prev_calculated;
   if(start <= 0)
      start = Inp_ADX_Period;

   //--- fill all buffers
   for(int i = start; i < rates_total; ++i)
   {
      double plusDI  = plusdi_values[i];
      double minusDI = minusdi_values[i];
      double adx     = adx_main[i];

      // Cloud: +DI e -DI
      PlusDIBuffer[i]  = plusDI;
      MinusDIBuffer[i] = minusDI;
      
      // ADX
      ADXBuffer[i] = adx;
      
      // ADXR: (ADX[hoje] + ADX[n barras atrás]) / 2
      if(i >= Inp_ADXR_Period)
      {
         ADXRBuffer[i] = (adx_main[i] + adx_main[i - Inp_ADXR_Period]) / 2.0;
      }
      else
      {
         ADXRBuffer[i] = adx;
      }
   }

   return(rates_total);
}

//+------------------------------------------------------------------+
// Buffers para EA via iCustom:
//  Buffer 0: +DI
//  Buffer 1: -DI
//  Buffer 2: ADX
//  Buffer 3: ADXR
//+------------------------------------------------------------------+
