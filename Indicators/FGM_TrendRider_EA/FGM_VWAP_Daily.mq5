//+------------------------------------------------------------------+
//|                                               FGM_VWAP_Daily.mq5 |
//|                                     Copyright 2025, Pauloeduspbr |
//|                                  FGM Trend Rider - Visual Module |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Pauloeduspbr"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot VWAP
#property indicator_label1  "Daily VWAP"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMagenta
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Buffers
double BufferVWAP[];

//--- Global calc vars
double g_sumPV = 0.0;
double g_sumVol = 0.0;
int    g_lastDay = -1;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, BufferVWAP, INDICATOR_DATA);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetString(0, PLOT_LABEL, "Daily VWAP");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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
   if(rates_total < 2) return 0;
   
   int start = prev_calculated - 1;
   if(start < 0) 
   {
      start = 0;
      g_sumPV = 0.0;
      g_sumVol = 0.0;
      g_lastDay = -1;
   }
   
   for(int i = start; i < rates_total; i++)
   {
      // Detectar mudança de dia
      MqlDateTime dt;
      TimeToStruct(time[i], dt);
      
      if(dt.day_of_year != g_lastDay)
      {
         // Reset Diário
         g_sumPV = 0.0;
         g_sumVol = 0.0;
         g_lastDay = dt.day_of_year;
      }
      
      double typical = (high[i] + low[i] + close[i]) / 3.0;
      double vol = (double)tick_volume[i]; // Usar Tick Volume (Forex/B3 comum)
      
      g_sumPV += (typical * vol);
      g_sumVol += vol;
      
      double vwap = 0.0;
      if(g_sumVol > 0) vwap = g_sumPV / g_sumVol;
      else vwap = typical; // Fallback
      
      BufferVWAP[i] = vwap;
   }
   
   return(rates_total);
}
//+------------------------------------------------------------------+
