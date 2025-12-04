//+------------------------------------------------------------------+
//|                                                 TradeManager.mqh |
//|                                  Copyright 2025, ExpertTrader MQL5 |
//|                                         https://www.experttrader.net |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include "Inputs.mqh"

class CTradeManager
{
private:
    CTrade         m_trade;
    string         m_symbol;
    double         m_point;
    double         m_tick_size;
    int            m_digits;
    
    //--- Time Filter Helpers
    int            TimeStringToMinutes(string time_str);
    
public:
    CTradeManager();
    ~CTradeManager();
    
    bool           Init();
    void           OnTick();
    void           ManagePositions();
    
    //--- Trade Execution
    void           OpenBuy(double sl_points, double tp_points, string comment="VertexFlow Buy");
    void           OpenSell(double sl_points, double tp_points, string comment="VertexFlow Sell");
    
    //--- Filters
    bool           IsTimeAllowed();
    bool           IsDayAllowed();
    
    //--- Utilities
    double         NormalizePrice(double price);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTradeManager::CTradeManager()
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTradeManager::~CTradeManager()
{
}

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CTradeManager::Init()
{
    m_symbol = _Symbol;
    m_point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    m_tick_size = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
    m_digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
    
    m_trade.SetExpertMagicNumber(Inp_MagicNum);
    m_trade.SetDeviationInPoints(Inp_Slippage);
    m_trade.SetTypeFillingBySymbol(m_symbol);
    m_trade.SetMarginMode();
    
    return true;
}

//+------------------------------------------------------------------+
//| OnTick Update (Refresh Symbol Info)                              |
//+------------------------------------------------------------------+
void CTradeManager::OnTick()
{
    // Refresh symbol info if needed, though usually static
    ManagePositions();
}

//+------------------------------------------------------------------+
//| Manage Positions (BE & Trailing)                                 |
//+------------------------------------------------------------------+
void CTradeManager::ManagePositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        if(PositionGetString(POSITION_SYMBOL) != m_symbol || PositionGetInteger(POSITION_MAGIC) != Inp_MagicNum)
            continue;
            
        //--- Data
        long type = PositionGetInteger(POSITION_TYPE);
        double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
        double current_sl = PositionGetDouble(POSITION_SL);
        double current_tp = PositionGetDouble(POSITION_TP);
        double current_price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(m_symbol, SYMBOL_BID) : SymbolInfoDouble(m_symbol, SYMBOL_ASK);
        
        //--- Break Even
        if(Inp_UseBreakEven)
        {
            if(type == POSITION_TYPE_BUY)
            {
                // Trigger: Price >= Open + Trigger
                if(current_price - open_price >= Inp_BE_Trigger * m_point)
                {
                    double new_sl = open_price + Inp_BE_Profit * m_point;
                    new_sl = NormalizePrice(new_sl);
                    
                    // Move SL only if it improves the current SL
                    if(current_sl < new_sl - m_point) 
                    {
                        if(!m_trade.PositionModify(ticket, new_sl, current_tp))
                            Print("Failed to move BE for Buy: ", m_trade.ResultRetcodeDescription());
                    }
                }
            }
            else if(type == POSITION_TYPE_SELL)
            {
                // Trigger: Price <= Open - Trigger
                if(open_price - current_price >= Inp_BE_Trigger * m_point)
                {
                    double new_sl = open_price - Inp_BE_Profit * m_point;
                    new_sl = NormalizePrice(new_sl);
                    
                    // Move SL only if it improves the current SL (Lower is better for Sell? No, SL for Sell is above price. We want to move it DOWN)
                    // Current SL (e.g. 1.1000) > New SL (e.g. 1.0900). Yes.
                    // Also handle case where SL is 0.
                    if(current_sl > new_sl + m_point || current_sl == 0.0) 
                    {
                        if(!m_trade.PositionModify(ticket, new_sl, current_tp))
                            Print("Failed to move BE for Sell: ", m_trade.ResultRetcodeDescription());
                    }
                }
            }
        }
        
        //--- Trailing Stop
        if(Inp_UseTrailing)
        {
            // Check if Trailing is allowed (Only if BE is disabled OR if BE has already secured profit)
            bool can_trail = false;
            if(!Inp_UseBreakEven)
            {
                can_trail = true;
            }
            else
            {
                // If BE is enabled, only trail if SL is already in profit zone (at or better than Entry Price)
                if(type == POSITION_TYPE_BUY)
                {
                    if(current_sl >= open_price) can_trail = true;
                }
                else if(type == POSITION_TYPE_SELL)
                {
                    // For Sell, SL is above price. Profit zone is when SL <= Open Price.
                    // Also check if SL is not 0 (no SL).
                    if(current_sl <= open_price && current_sl > 0.0) can_trail = true;
                }
            }

            if(can_trail)
            {
                if(type == POSITION_TYPE_BUY)
                {
                    // Trailing Logic: SL = Price - Distance
                    double new_sl = current_price - Inp_TS_Start * m_point;
                    new_sl = NormalizePrice(new_sl);
                    
                    // Only move if New SL > Current SL + Step
                    if(new_sl > current_sl + Inp_TS_Step * m_point)
                    {
                         if(!m_trade.PositionModify(ticket, new_sl, current_tp))
                            Print("Failed to Trailing Stop for Buy: ", m_trade.ResultRetcodeDescription());
                    }
                }
                else if(type == POSITION_TYPE_SELL)
                {
                    // Trailing Logic: SL = Price + Distance
                    double new_sl = current_price + Inp_TS_Start * m_point;
                    new_sl = NormalizePrice(new_sl);
                    
                    // Only move if New SL < Current SL - Step
                    // Or if Current SL is 0 (no SL set yet)
                    if(new_sl < current_sl - Inp_TS_Step * m_point || current_sl == 0.0)
                    {
                         if(!m_trade.PositionModify(ticket, new_sl, current_tp))
                            Print("Failed to Trailing Stop for Sell: ", m_trade.ResultRetcodeDescription());
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Open Buy Position                                                |
//+------------------------------------------------------------------+
void CTradeManager::OpenBuy(double sl_points, double tp_points, string comment)
{
    double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
    double sl = (sl_points > 0) ? ask - sl_points * m_point : 0;
    double tp = (tp_points > 0) ? ask + tp_points * m_point : 0;
    
    sl = NormalizePrice(sl);
    tp = NormalizePrice(tp);
    
    if(!m_trade.Buy(Inp_LotSize, m_symbol, ask, sl, tp, comment))
    {
        Print("TradeManager: Buy failed. Error: ", m_trade.ResultRetcode(), " - ", m_trade.ResultRetcodeDescription());
    }
}

//+------------------------------------------------------------------+
//| Open Sell Position                                               |
//+------------------------------------------------------------------+
void CTradeManager::OpenSell(double sl_points, double tp_points, string comment)
{
    double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    double sl = (sl_points > 0) ? bid + sl_points * m_point : 0;
    double tp = (tp_points > 0) ? bid - tp_points * m_point : 0;
    
    sl = NormalizePrice(sl);
    tp = NormalizePrice(tp);
    
    if(!m_trade.Sell(Inp_LotSize, m_symbol, bid, sl, tp, comment))
    {
        Print("TradeManager: Sell failed. Error: ", m_trade.ResultRetcode(), " - ", m_trade.ResultRetcodeDescription());
    }
}

//+------------------------------------------------------------------+
//| Check Time Filter                                                |
//+------------------------------------------------------------------+
bool CTradeManager::IsTimeAllowed()
{
    if(!Inp_UseTimeFilter) return true;
    
    datetime current_time = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(current_time, dt);
    
    int current_minutes = dt.hour * 60 + dt.min;
    int start_minutes = TimeStringToMinutes(Inp_StartTime);
    int end_minutes = TimeStringToMinutes(Inp_EndTime);
    
    // Simple range check (Start < End)
    if(start_minutes < end_minutes)
    {
        return (current_minutes >= start_minutes && current_minutes < end_minutes);
    }
    else // Cross-midnight (Start > End, e.g. 22:00 to 02:00)
    {
        return (current_minutes >= start_minutes || current_minutes < end_minutes);
    }
}

//+------------------------------------------------------------------+
//| Convert HH:MM string to minutes                                  |
//+------------------------------------------------------------------+
int CTradeManager::TimeStringToMinutes(string time_str)
{
    string sep = ":";
    ushort u_sep = StringGetCharacter(sep, 0);
    string result[];
    int k = StringSplit(time_str, u_sep, result);
    
    if(k >= 2)
    {
        return (int)StringToInteger(result[0]) * 60 + (int)StringToInteger(result[1]);
    }
    return 0;
}

//+------------------------------------------------------------------+
//| Check Day of Week Filter                                         |
//+------------------------------------------------------------------+
bool CTradeManager::IsDayAllowed()
{
    datetime current_time = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(current_time, dt);
    
    switch(dt.day_of_week)
    {
        case 0: return TradeSunday;
        case 1: return TradeMonday;
        case 2: return TradeTuesday;
        case 3: return TradeWednesday;
        case 4: return TradeThursday;
        case 5: return TradeFriday;
        case 6: return TradeSaturday;
        default: return false;
    }
}

//+------------------------------------------------------------------+
//| Normalize Price                                                  |
//+------------------------------------------------------------------+
double CTradeManager::NormalizePrice(double price)
{
    return NormalizeDouble(price, m_digits);
}
