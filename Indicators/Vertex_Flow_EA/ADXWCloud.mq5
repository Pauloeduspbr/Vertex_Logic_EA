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
#property indicator_label1  "+DI/-DI Cloud"
#property indicator_type1   DRAW_FILLING
#property indicator_color1  clrLightGreen, clrHotPink
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

//--- Plot 3: +DI line (green)
#property indicator_label4  "+DI"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrLime
#property indicator_width4  1

//--- Plot 4: -DI line (red)
#property indicator_label5  "-DI"
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
input color    Inp_BullishCloudColor = clrLightGreen; // Bullish cloud color
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

   //--- NÃO usar ArraySetAsSeries nos buffers do indicador
   //--- O MT5 espera indexação normal (0 = mais antigo, rates_total-1 = mais recente)

   //--- aplicar cores configuráveis à nuvem com transparência
   int alpha = MathMax(0, MathMin(255, Inp_FillTransparency));
   
   // Extrair componentes RGB da cor bullish
   uchar rBull = (uchar)((Inp_BullishCloudColor >> 16) & 0xFF);
   uchar gBull = (uchar)((Inp_BullishCloudColor >> 8) & 0xFF);
   uchar bBull = (uchar)(Inp_BullishCloudColor & 0xFF);
   
   // Extrair componentes RGB da cor bearish
   uchar rBear = (uchar)((Inp_BearishCloudColor >> 16) & 0xFF);
   uchar gBear = (uchar)((Inp_BearishCloudColor >> 8) & 0xFF);
   uchar bBear = (uchar)(Inp_BearishCloudColor & 0xFF);
   
   // Montar cores com alpha (ARGB)
   uint bullAlpha = ((uint)alpha << 24) | ((uint)rBull << 16) | ((uint)gBull << 8) | (uint)bBull;
   uint bearAlpha = ((uint)alpha << 24) | ((uint)rBear << 16) | ((uint)gBear << 8) | (uint)bBear;
   
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, (color)bullAlpha);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, (color)bearAlpha);

   IndicatorSetString(INDICATOR_SHORTNAME,
                      StringFormat("ADXWCloud (%d,%.1f)", Inp_ADX_Period, Inp_ADXR_Level));

   //--- nível configurável para ADXR/força de tendência
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

   //--- get built-in ADX buffers (sem ArraySetAsSeries - índice normal)
   double adx_values[];
   double plusdi_values[];
   double minusdi_values[];

   int copied1 = CopyBuffer(adx_handle, 0, 0, rates_total, adx_values);     // ADX
   int copied2 = CopyBuffer(adx_handle, 1, 0, rates_total, plusdi_values);  // +DI
   int copied3 = CopyBuffer(adx_handle, 2, 0, rates_total, minusdi_values); // -DI

   if(copied1 <= 0 || copied2 <= 0 || copied3 <= 0)
      return(0);

   int start = prev_calculated;
   if(start <= 0)
      start = Inp_ADX_Period + 2; // garantir dados suficientes

   //--- fill buffers (índice normal, do mais antigo para o mais recente)
   for(int i = start; i < rates_total; ++i)
   {
      double adx    = adx_values[i];
      double plusDI = plusdi_values[i];
      double minusDI= minusdi_values[i];

      // Cloud buffers (+DI e -DI)
      PlusDICloudBuffer[i]  = plusDI;
      MinusDICloudBuffer[i] = minusDI;

      // ADX
      ADXBuffer[i] = adx;

      // +DI and -DI as separate lines
      PlusDILineBuffer[i]  = plusDI;
      MinusDILineBuffer[i] = minusDI;
   }

   //--- ADXR: média móvel simples do ADX (olhando para trás, não para frente)
   int adxr_period = 14;
   for(int i = start; i < rates_total; ++i)
   {
      if(i < adxr_period)
      {
         ADXRBuffer[i] = ADXBuffer[i];
      }
      else
      {
         double sum = 0.0;
         for(int j = 0; j < adxr_period; ++j)
         {
            sum += ADXBuffer[i - j];
         }
         ADXRBuffer[i] = sum / adxr_period;
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
//  Buffer 4: +DI line
//  Buffer 5: -DI line
//+------------------------------------------------------------------+
