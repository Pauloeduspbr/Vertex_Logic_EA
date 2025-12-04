//+------------------------------------------------------------------+
//|                                                 ADXWCloud.mq5   |
//|                        ADX + ADXR + DI Cloud (MT5)              |
//|                    Manual ADXW Calculation                      |
//+------------------------------------------------------------------+
#property copyright "Vertex Flow"
#property version   "1.00"
#property description "ADXW (Wilder's) with ADXR and DI+ / DI- cloud"

#property indicator_separate_window
#property indicator_plots   5
#property indicator_buffers 10

//--- Plot 0: DI+ / DI- Cloud
#property indicator_label1  ""
#property indicator_type1   DRAW_FILLING
#property indicator_color1  clrLimeGreen, clrHotPink
#property indicator_width1  1

//--- Plot 1: DI+ Line
#property indicator_label2  "DI+"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrLimeGreen
#property indicator_width2  1

//--- Plot 2: DI- Line
#property indicator_label3  "DI-"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrHotPink
#property indicator_width3  1

//--- Plot 3: ADX line
#property indicator_label4  "ADX"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrDodgerBlue
#property indicator_width4  2

//--- Plot 4: ADXR line
#property indicator_label5  "ADXR"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrOrange
#property indicator_width5  1
#property indicator_style5  STYLE_DOT

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
double CloudPlusDIBuffer[];   // 0
double CloudMinusDIBuffer[];  // 1
double LinePlusDIBuffer[];    // 2
double LineMinusDIBuffer[];   // 3
double ADXBuffer[];           // 4
double ADXRBuffer[];          // 5

//--- Calculation Buffers
double TRBuffer[];        // 6 (Smoothed TR)
double PlusDMBuffer[];    // 7 (Smoothed +DM)
double MinusDMBuffer[];   // 8 (Smoothed -DM)
double DXBuffer[];        // 9 (Raw DX)

//+------------------------------------------------------------------+
int OnInit()
{
   if(Inp_ADX_Period <= 1) return(INIT_FAILED);

   // Mapping Buffers
   SetIndexBuffer(0, CloudPlusDIBuffer,   INDICATOR_DATA);
   SetIndexBuffer(1, CloudMinusDIBuffer,  INDICATOR_DATA);
   SetIndexBuffer(2, LinePlusDIBuffer,    INDICATOR_DATA);
   SetIndexBuffer(3, LineMinusDIBuffer,   INDICATOR_DATA);
   SetIndexBuffer(4, ADXBuffer,           INDICATOR_DATA);
   SetIndexBuffer(5, ADXRBuffer,          INDICATOR_DATA);
   
   SetIndexBuffer(6, TRBuffer,      INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, PlusDMBuffer,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(8, MinusDMBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(9, DXBuffer,      INDICATOR_CALCULATIONS);

   //--- aplicar cores configuráveis à nuvem com transparência
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, ColorToARGB(Inp_BullishCloudColor, Inp_FillTransparency));
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, ColorToARGB(Inp_BearishCloudColor, Inp_FillTransparency));
   
   //--- Ocultar valores da nuvem na Janela de Dados e na String do Gráfico
   PlotIndexSetInteger(0, PLOT_SHOW_DATA, false);
   PlotIndexSetString(0, PLOT_LABEL, "");

   //--- aplicar cores às linhas (sem transparência ou opacas)
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, 0, Inp_BullishCloudColor);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, 0, Inp_BearishCloudColor);
   
   //--- Aumentar espessura das linhas DI para melhor visibilidade
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, 2); // DI+
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, 2); // DI-

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("ADXW Cloud (%d,%d)", Inp_ADX_Period, Inp_ADXR_Period));
   
   Print("ADXW Cloud Updated: ", __DATETIME__); // Debug para confirmar atualização
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
      ArrayInitialize(CloudPlusDIBuffer, 0);
      ArrayInitialize(CloudMinusDIBuffer, 0);
      ArrayInitialize(LinePlusDIBuffer, 0);
      ArrayInitialize(LineMinusDIBuffer, 0);
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

      double pdi = 100.0 * PlusDMBuffer[i] / tr_smooth;
      double mdi = 100.0 * MinusDMBuffer[i] / tr_smooth;

      // Fill Cloud Buffers
      CloudPlusDIBuffer[i] = pdi;
      CloudMinusDIBuffer[i] = mdi;
      
      // Fill Line Buffers
      LinePlusDIBuffer[i] = pdi;
      LineMinusDIBuffer[i] = mdi;

      // 4. Calculate DX
      double di_sum = pdi + mdi;
      double di_diff = MathAbs(pdi - mdi);
      
      if(di_sum == 0) DXBuffer[i] = 0;
      else DXBuffer[i] = 100.0 * di_diff / di_sum;

      // 5. Calculate ADX (Smoothed DX)
      if(i < Inp_ADX_Period)
      {
         ADXBuffer[i] = 0; 
      }
      else if(i == Inp_ADX_Period)
      {
         ADXBuffer[i] = DXBuffer[i]; 
      }
      else if(i < 2 * Inp_ADX_Period - 1)
      {
         ADXBuffer[i] = ADXBuffer[i-1] + DXBuffer[i]; 
      }
      else if(i == 2 * Inp_ADX_Period - 1)
      {
         ADXBuffer[i] = (ADXBuffer[i-1] + DXBuffer[i]) / Inp_ADX_Period;
      }
      else
      {
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
