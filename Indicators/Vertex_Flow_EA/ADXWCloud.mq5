//+------------------------------------------------------------------+
//|                                                 ADXWCloud.mq5   |
//|                        ADX + ADXR + DI Cloud (MT5)              |
//|                    Inspired by ADXWCloud 1.0 visual style       |
//+------------------------------------------------------------------+
#property copyright "Vertex Flow"
#property version   "1.00"
#property description "ADX with ADXR and DI+ / DI- cloud"

#property indicator_separate_window
#property indicator_plots   5
#property indicator_buffers 6

//--- Plot 0: DI+ / DI- Cloud (fill between +DI and -DI)
#property indicator_label1  "DI+;DI-"
#property indicator_type1   DRAW_FILLING
#property indicator_color1  clrLimeGreen, clrHotPink
#property indicator_width1  1

//--- Plot 1: ADX line (blue) - desenhado DEPOIS da cloud para ficar por cima
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

//--- Plot 3: +DI line (green) - desenhada por cima da cloud
#property indicator_label4  "DI+ line"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrLime
#property indicator_width4  1

//--- Plot 4: -DI line (red) - desenhada por cima da cloud
#property indicator_label5  "DI- line"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrRed
#property indicator_width5  1

//--- Levels (classic trend threshold)
#property indicator_level1  20.0
#property indicator_levelcolor clrSilver
#property indicator_levelstyle STYLE_DOT

//--- Inputs (espelhando ADXW Cloud 1.0)
input int      Inp_ADX_Period        = 14;            // ADX period
input double   Inp_ADXR_Level        = 20.0;          // ADXR level line
input color    Inp_BullishCloudColor = clrLimeGreen;  // Bullish cloud color
input color    Inp_BearishCloudColor = clrHotPink;    // Bearish cloud color
input int      Inp_FillTransparency  = 80;            // Filling colors transparency (0..255)

//--- Buffers
// Plot 0: cloud (2 buffers)
double PlusDICloudBuffer[];   // +DI for cloud
double MinusDICloudBuffer[];  // -DI for cloud

// Plot 1: ADX
double ADXBuffer[];

// Plot 2: ADXR
double ADXRBuffer[];

// Plot 3: +DI line
double PlusDILineBuffer[];

// Plot 4: -DI line
double MinusDILineBuffer[];

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
   // Plot 0: cloud between +DI and -DI (2 buffers)
   SetIndexBuffer(0, PlusDICloudBuffer,  INDICATOR_DATA);
   SetIndexBuffer(1, MinusDICloudBuffer, INDICATOR_DATA);

   // Plot 1: ADX
   SetIndexBuffer(2, ADXBuffer, INDICATOR_DATA);

   // Plot 2: ADXR
   SetIndexBuffer(3, ADXRBuffer, INDICATOR_DATA);

   // Plot 3: +DI line (green)
   SetIndexBuffer(4, PlusDILineBuffer, INDICATOR_DATA);

   // Plot 4: -DI line (red)
   SetIndexBuffer(5, MinusDILineBuffer, INDICATOR_DATA);

   //--- aplicar cores configuráveis à nuvem
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, Inp_BullishCloudColor);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, Inp_BearishCloudColor);
   
   // Cores das linhas DI
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, 0, clrLime);
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, 0, clrRed);

   IndicatorSetString(INDICATOR_SHORTNAME,
                      StringFormat("ADXW Cloud (%d,%d)", Inp_ADX_Period, Inp_ADX_Period));

   //--- nível configurável
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, Inp_ADXR_Level);

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
   double adx_main[];
   double plusdi_values[];
   double minusdi_values[];

   // iADX buffers: 0=ADX, 1=+DI, 2=-DI
   int copied1 = CopyBuffer(adx_handle, 0, 0, rates_total, adx_main);       // ADX
   int copied2 = CopyBuffer(adx_handle, 1, 0, rates_total, plusdi_values);  // +DI
   int copied3 = CopyBuffer(adx_handle, 2, 0, rates_total, minusdi_values); // -DI

   if(copied1 <= 0 || copied2 <= 0 || copied3 <= 0)
      return(0);

   int start = prev_calculated;
   if(start <= 0)
      start = 0;
   
   // Garantir que temos dados suficientes
   if(start < Inp_ADX_Period)
      start = Inp_ADX_Period;

   //--- fill all buffers
   for(int i = start; i < rates_total; ++i)
   {
      double adx    = adx_main[i];
      double plusDI = plusdi_values[i];
      double minusDI= minusdi_values[i];

      // Cloud buffers (+DI e -DI)
      PlusDICloudBuffer[i]  = plusDI;
      MinusDICloudBuffer[i] = minusDI;

      // ADX - valor direto do iADX
      ADXBuffer[i] = adx;

      // +DI and -DI as separate lines (para desenhar por cima da cloud)
      PlusDILineBuffer[i]  = plusDI;
      MinusDILineBuffer[i] = minusDI;
      
      // ADXR clássico: (ADX[hoje] + ADX[n barras atrás]) / 2
      if(i >= Inp_ADX_Period)
      {
         ADXRBuffer[i] = (adx_main[i] + adx_main[i - Inp_ADX_Period]) / 2.0;
      }
      else
      {
         ADXRBuffer[i] = adx;
      }
   }

   return(rates_total);
}

//+------------------------------------------------------------------+
// Conveniência para EA via iCustom:
//  Buffer 0: +DI (para cloud)
//  Buffer 1: -DI (para cloud)
//  Buffer 2: ADX
//  Buffer 3: ADXR
//  Buffer 4: +DI line
//  Buffer 5: -DI line
//+------------------------------------------------------------------+
