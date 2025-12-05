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
datetime           g_last_bar_time = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Create Objects
    g_signal = new CSignalVertexFlow();
    g_trade = new CTradeManager();
    
    //--- Initialize New Bar Check
    g_last_bar_time = iTime(_Symbol, _Period, 0);
    
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
        
    // ADX (Subwindow 2)
    if(!ChartIndicatorAdd(chart_id, 2, g_signal.GetHandleADX()))
        Print("Failed to attach ADX to chart");
        
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
    //--- 0. Fechar posições antes do fim do pregão (16:30 para evitar gaps)
    ClosePositionsBeforeClose();
    
    //--- 1. Update Trade Manager (Trailing, BE) - ALWAYS RUN EVERY TICK
    g_trade.OnTick();

    //--- 2. New Bar Check (Entry Logic only on New Bar)
    datetime current_time = iTime(_Symbol, _Period, 0);
    if(g_last_bar_time == current_time)
        return; // Not a new bar, exit
        
    g_last_bar_time = current_time;

    //--- 3. Check Time Filter
    if(!g_trade.IsTimeAllowed())
        return;
        
    //--- 4. Check Weekly Filter
    if(!g_trade.IsDayAllowed())
        return;
    
    //--- 5. Check for Open Positions
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
    
    //--- 6. Get Signal
    int signal = g_signal.GetSignal();
    
    //--- 7. Execute Trade
    if(signal == 1)
    {
        g_trade.OpenBuy(Inp_StopLoss, Inp_TakeProfit, "VertexFlow Buy");
    }
    else if(signal == -1)
    {
        g_trade.OpenSell(Inp_StopLoss, Inp_TakeProfit, "VertexFlow Sell");
    }
}

//+------------------------------------------------------------------+
//| Fechar posições antes do fechamento do mercado                   |
//+------------------------------------------------------------------+
void ClosePositionsBeforeClose()
{
    // Horário limite: 16:30 (30 min antes do fim às 17:00)
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    int current_minutes = dt.hour * 60 + dt.min;
    int close_time = 16 * 60 + 30; // 16:30
    
    if(current_minutes < close_time)
        return; // Ainda não é hora de fechar
    
    // Fechar todas as posições do EA
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
           PositionGetInteger(POSITION_MAGIC) == Inp_MagicNum)
        {
            CTrade trade;
            trade.SetExpertMagicNumber(Inp_MagicNum);
            
            if(trade.PositionClose(ticket))
                Print("[END OF DAY] Position closed to avoid overnight risk. Ticket: ", ticket);
            else
                Print("[END OF DAY] Failed to close position. Ticket: ", ticket);
        }
    }
}
