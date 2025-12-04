//+------------------------------------------------------------------+
//|                                               Vertex_Flow_EA.mq5 |
//|                                  Copyright 2025, ExpertTrader MQL5 |
//|                                         https://www.experttrader.net |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ExpertTrader MQL5"
#property link      "https://www.experttrader.net"
#property version   "1.01"

#include <Vertex_Flow_EA\Inputs.mqh>
#include <Vertex_Flow_EA\SignalVertexFlow.mqh>
#include <Vertex_Flow_EA\TradeManager.mqh>

//--- Global Objects
CSignalVertexFlow *g_signal;
CTradeManager     *g_trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Create Objects
    g_signal = new CSignalVertexFlow();
    g_trade = new CTradeManager();
    
    //--- Initialize Trade Manager
    if(!g_trade.Init())
    {
        Print("Failed to initialize Trade Manager");
        return(INIT_FAILED);
    }
    
    //--- Initialize Signal (Indicators)
    if(!g_signal.Init())
    {
        Print("Failed to initialize Signal Logic");
        return(INIT_FAILED);
    }
    
    //--- Attach Indicators to Chart
    long chart_id = ChartID();
    
    // FGM (Main Window)
    if(!ChartIndicatorAdd(chart_id, 0, g_signal.GetHandleFGM()))
        Print("Failed to attach FGM to chart");
        
    // RSIOMA (Subwindow 1)
    if(!ChartIndicatorAdd(chart_id, 1, g_signal.GetHandleRSI()))
        Print("Failed to attach RSIOMA to chart");
        
    // OBV MACD (Subwindow 2)
    if(!ChartIndicatorAdd(chart_id, 2, g_signal.GetHandleOBV()))
        Print("Failed to attach OBV MACD to chart");
        
    // Enhanced MFI (Subwindow 3)
    if(!ChartIndicatorAdd(chart_id, 3, g_signal.GetHandleMFI()))
        Print("Failed to attach Enhanced MFI to chart");
        
    Print("Vertex Flow EA Initialized Successfully");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //--- Delete Objects
    if(g_signal != NULL) delete g_signal;
    if(g_trade != NULL) delete g_trade;
    
    Print("Vertex Flow EA Deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    //--- 1. Check Time Filter
    if(!g_trade.IsTimeAllowed())
        return;
        
    //--- 2. Check Weekly Filter
    if(g_trade.IsWeeklyLimitReached())
        return;
        
    //--- 3. Update Trade Manager (Trailing, etc. - if implemented)
    g_trade.OnTick();
    
    //--- 4. Check for Open Positions
    // Simple logic: One trade at a time per symbol
    if(PositionsTotal() > 0)
    {
        // Check if we already have a position for this symbol
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
               PositionGetInteger(POSITION_MAGIC) == Inp_MagicNum)
            {
                return; // Already have a position, wait for exit
            }
        }
    }
    
    //--- 5. Get Signal
    int signal = g_signal.GetSignal();
    
    //--- 6. Execute Trade
    if(signal == 1)
    {
        g_trade.OpenBuy(Inp_StopLoss, Inp_TakeProfit, "VertexFlow Buy");
    }
    else if(signal == -1)
    {
        g_trade.OpenSell(Inp_StopLoss, Inp_TakeProfit, "VertexFlow Sell");
    }
}
