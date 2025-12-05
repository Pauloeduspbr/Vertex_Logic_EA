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
    
    //--- Tracking de melhor preço para Trailing Stop correto
    //--- Chave: ticket da posição, Valor: melhor preço atingido
    ulong          m_tracked_tickets[100];
    double         m_best_prices[100];
    int            m_tracked_count;
    
    //--- Time Filter Helpers
    int            TimeStringToMinutes(string time_str);
    
    //--- Trailing Helpers
    double         GetBestPrice(ulong ticket);
    void           SetBestPrice(ulong ticket, double price);
    void           RemoveTicket(ulong ticket);
    
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
CTradeManager::CTradeManager() : m_tracked_count(0)
{
    ArrayInitialize(m_tracked_tickets, 0);
    ArrayInitialize(m_best_prices, 0);
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
        
        //--- Atualizar melhor preço atingido (para trailing)
        double best_price = GetBestPrice(ticket);
        if(best_price == 0.0)
        {
            // Primeiro tick desta posição - inicializar com preço de abertura
            best_price = open_price;
            SetBestPrice(ticket, best_price);
        }
        
        // Atualizar melhor preço APENAS se movimento a favor
        if(type == POSITION_TYPE_BUY && current_price > best_price)
        {
            best_price = current_price;
            SetBestPrice(ticket, best_price);
        }
        else if(type == POSITION_TYPE_SELL && current_price < best_price)
        {
            best_price = current_price;
            SetBestPrice(ticket, best_price);
        }
        
        // Calcular lucro baseado no MELHOR preço atingido
        double best_profit_points = 0;
        if(type == POSITION_TYPE_BUY)
            best_profit_points = (best_price - open_price) / m_point;
        else
            best_profit_points = (open_price - best_price) / m_point;
        
        //--- Flag para saber se BE já foi ativado
        bool be_activated = false;
        if(type == POSITION_TYPE_BUY)
            be_activated = (current_sl >= open_price + Inp_BE_Profit * m_point - m_tick_size);
        else
            be_activated = (current_sl <= open_price - Inp_BE_Profit * m_point + m_tick_size && current_sl > 0);
        
        //--- Break Even (apenas uma vez)
        if(Inp_UseBreakEven && !be_activated)
        {
            if(type == POSITION_TYPE_BUY)
            {
                double be_level = open_price + Inp_BE_Profit * m_point;
                be_level = NormalizePrice(be_level);
                
                // Ativar BE se: lucro >= trigger E SL ainda não está no BE
                if(profit_points >= Inp_BE_Trigger && current_sl < be_level - m_tick_size)
                {
                    if(m_trade.PositionModify(ticket, be_level, current_tp))
                        PrintFormat("[BE BUY] Ticket %d: SL moved to %.0f (profit: %.0f pts, best: %.0f pts)", 
                                    ticket, be_level, profit_points, best_profit_points);
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
                        PrintFormat("[BE SELL] Ticket %d: SL moved to %.0f (profit: %.0f pts, best: %.0f pts)", 
                                    ticket, be_level, profit_points, best_profit_points);
                }
            }
        }
        
        //--- Trailing Stop (só após BE e baseado no MELHOR preço)
        // REGRA IMPORTANTE: O trailing SÓ move o SL quando o preço FAZ NOVO MÁXIMO (buy) ou MÍNIMO (sell)
        // Se o preço está retornando (pullback), o SL NÃO move!
        if(Inp_UseTrailing && be_activated)
        {
            if(type == POSITION_TYPE_BUY)
            {
                // Só ativa trailing se MELHOR PREÇO atingiu TS_Start de lucro
                if(best_profit_points >= Inp_TS_Start)
                {
                    // Calcular novo SL baseado no MELHOR preço, não no preço atual
                    double new_sl = best_price - Inp_TS_Start * m_point;
                    new_sl = NormalizePrice(new_sl);
                    
                    // VERIFICAÇÃO CRÍTICA: 
                    // 1. Preço atual DEVE ser igual ou próximo ao melhor preço (não está em pullback)
                    // 2. Novo SL deve ser melhor que o atual em pelo menos TS_Step pontos
                    bool price_at_best = (current_price >= best_price - Inp_TS_Step * m_point);
                    
                    if(price_at_best && new_sl > current_sl + Inp_TS_Step * m_point)
                    {
                        if(m_trade.PositionModify(ticket, new_sl, current_tp))
                            PrintFormat("[TRAIL BUY] Ticket %d: SL moved to %.0f (current: %.0f, best: %.0f, profit: %.0f pts)", 
                                        ticket, new_sl, current_price, best_price, profit_points);
                    }
                }
            }
            else if(type == POSITION_TYPE_SELL)
            {
                // Só ativa trailing se MELHOR PREÇO atingiu TS_Start de lucro
                if(best_profit_points >= Inp_TS_Start)
                {
                    // Calcular novo SL baseado no MELHOR preço, não no preço atual
                    double new_sl = best_price + Inp_TS_Start * m_point;
                    new_sl = NormalizePrice(new_sl);
                    
                    // VERIFICAÇÃO CRÍTICA:
                    // 1. Preço atual DEVE ser igual ou próximo ao melhor preço (não está em pullback)
                    // 2. Novo SL deve ser melhor que o atual em pelo menos TS_Step pontos
                    bool price_at_best = (current_price <= best_price + Inp_TS_Step * m_point);
                    
                    if(price_at_best && new_sl < current_sl - Inp_TS_Step * m_point)
                    {
                        if(m_trade.PositionModify(ticket, new_sl, current_tp))
                            PrintFormat("[TRAIL SELL] Ticket %d: SL moved to %.0f (current: %.0f, best: %.0f, profit: %.0f pts)", 
                                        ticket, new_sl, current_price, best_price, profit_points);
                    }
                }
            }
        }
    }
    
    // Limpar tickets de posições fechadas
    for(int i = m_tracked_count - 1; i >= 0; i--)
    {
        bool found = false;
        for(int j = PositionsTotal() - 1; j >= 0; j--)
        {
            if(PositionGetTicket(j) == m_tracked_tickets[i])
            {
                found = true;
                break;
            }
        }
        if(!found)
            RemoveTicket(m_tracked_tickets[i]);
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

//+------------------------------------------------------------------+
//| Get Best Price for a Ticket                                      |
//+------------------------------------------------------------------+
double CTradeManager::GetBestPrice(ulong ticket)
{
    for(int i = 0; i < m_tracked_count; i++)
    {
        if(m_tracked_tickets[i] == ticket)
            return m_best_prices[i];
    }
    return 0.0; // Não encontrado
}

//+------------------------------------------------------------------+
//| Set Best Price for a Ticket                                      |
//+------------------------------------------------------------------+
void CTradeManager::SetBestPrice(ulong ticket, double price)
{
    // Verificar se já existe
    for(int i = 0; i < m_tracked_count; i++)
    {
        if(m_tracked_tickets[i] == ticket)
        {
            m_best_prices[i] = price;
            return;
        }
    }
    // Adicionar novo
    if(m_tracked_count < 100)
    {
        m_tracked_tickets[m_tracked_count] = ticket;
        m_best_prices[m_tracked_count] = price;
        m_tracked_count++;
    }
}

//+------------------------------------------------------------------+
//| Remove Ticket from Tracking                                      |
//+------------------------------------------------------------------+
void CTradeManager::RemoveTicket(ulong ticket)
{
    for(int i = 0; i < m_tracked_count; i++)
    {
        if(m_tracked_tickets[i] == ticket)
        {
            // Mover último para esta posição
            m_tracked_tickets[i] = m_tracked_tickets[m_tracked_count - 1];
            m_best_prices[i] = m_best_prices[m_tracked_count - 1];
            m_tracked_count--;
            return;
        }
    }
}
