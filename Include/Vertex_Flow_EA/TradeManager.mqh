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
    // Limitar frequência de verificação para evitar modificações excessivas
    static datetime last_check = 0;
    datetime now = TimeCurrent();
    
    // Verificar no máximo a cada 5 segundos
    if(now - last_check < 5)
        return;
    last_check = now;

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
        
        double profit_points = 0;
        if(type == POSITION_TYPE_BUY)
            profit_points = (current_price - open_price) / m_point;
        else
            profit_points = (open_price - current_price) / m_point;
        
        //--- Break Even (apenas uma vez)
        if(Inp_UseBreakEven)
        {
            if(type == POSITION_TYPE_BUY)
            {
                double be_level = open_price + Inp_BE_Profit * m_point;
                be_level = NormalizePrice(be_level);
                
                // Ativar BE se: lucro >= trigger E SL ainda não está no BE
                if(profit_points >= Inp_BE_Trigger && current_sl < be_level - m_tick_size)
                {
                    if(m_trade.PositionModify(ticket, be_level, current_tp))
                        PrintFormat("[BE BUY] Ticket %d: SL moved to %.0f (profit: %.0f pts)", ticket, be_level, profit_points);
                }
            }
            else if(type == POSITION_TYPE_SELL)
            {
                double be_level = open_price - Inp_BE_Profit * m_point;
                be_level = NormalizePrice(be_level);
                
                // Ativar BE se: lucro >= trigger E SL ainda não está no BE
                if(profit_points >= Inp_BE_Trigger && (current_sl > be_level + m_tick_size || current_sl == 0.0))
                {
                    if(m_trade.PositionModify(ticket, be_level, current_tp))
                        PrintFormat("[BE SELL] Ticket %d: SL moved to %.0f (profit: %.0f pts)", ticket, be_level, profit_points);
                }
            }
        }
        
        //--- Trailing Stop (só ativa após lucro >= TS_Start)
        if(Inp_UseTrailing)
        {
            if(type == POSITION_TYPE_BUY)
            {
                // Só ativa trailing se lucro >= TS_Start
                if(profit_points >= Inp_TS_Start)
                {
                    double new_sl = current_price - Inp_TS_Start * m_point;
                    new_sl = NormalizePrice(new_sl);
                    
                    // Só move se melhora em pelo menos TS_Step pontos
                    if(new_sl > current_sl + Inp_TS_Step * m_point)
                    {
                        if(m_trade.PositionModify(ticket, new_sl, current_tp))
                            PrintFormat("[TRAIL BUY] Ticket %d: SL moved to %.0f (profit: %.0f pts)", ticket, new_sl, profit_points);
                    }
                }
            }
            else if(type == POSITION_TYPE_SELL)
            {
                // Só ativa trailing se lucro >= TS_Start
                if(profit_points >= Inp_TS_Start)
                {
                    double new_sl = current_price + Inp_TS_Start * m_point;
                    new_sl = NormalizePrice(new_sl);
                    
                    // Só move se melhora em pelo menos TS_Step pontos
                    if(new_sl < current_sl - Inp_TS_Step * m_point)
                    {
                        if(m_trade.PositionModify(ticket, new_sl, current_tp))
                            PrintFormat("[TRAIL SELL] Ticket %d: SL moved to %.0f (profit: %.0f pts)", ticket, new_sl, profit_points);
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
