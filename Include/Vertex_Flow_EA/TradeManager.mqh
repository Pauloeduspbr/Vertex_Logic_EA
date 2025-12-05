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
    
    //--- Tracking de posições para BE e Trailing
    ulong          m_tracked_tickets[100];
    double         m_best_prices[100];      // Melhor preço atingido (para trailing)
    bool           m_be_executed[100];      // Flag: BE já foi executado para esta posição
    double         m_last_trail_sl[100];    // Último SL do trailing (evita movimentos desnecessários)
    int            m_tracked_count;
    
    //--- Time Filter Helpers
    int            TimeStringToMinutes(string time_str);
    
    //--- Tracking Helpers
    int            GetTicketIndex(ulong ticket);
    void           InitTicket(ulong ticket, double open_price);
    void           RemoveTicket(ulong ticket);
    double         GetBestPrice(ulong ticket);
    void           SetBestPrice(ulong ticket, double price);
    bool           IsBEExecuted(ulong ticket);
    void           SetBEExecuted(ulong ticket);
    double         GetLastTrailSL(ulong ticket);
    void           SetLastTrailSL(ulong ticket, double sl);
    
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
    ArrayInitialize(m_be_executed, false);
    ArrayInitialize(m_last_trail_sl, 0);
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
    //==========================================================================
    // REGRAS DE BE E TRAILING STOP:
    //
    // BREAK EVEN:
    // - Ativa quando lucro >= BE_Trigger (200 pts)
    // - Move SL para preço de entrada + BE_Profit (100 pts)
    // - Executa APENAS UMA VEZ por posição
    // - Após executar, NÃO modifica mais o SL (deixa para o Trailing)
    //
    // TRAILING STOP:
    // - SÓ ativa se BE já foi executado (ou se BE está desativado)
    // - SÓ ativa quando lucro >= TS_Start (300 pts)
    // - Move SL apenas quando preço FAZ NOVO MÁXIMO/MÍNIMO
    // - Recuos (pullbacks) NÃO movem o SL
    // - Move em incrementos de TS_Step (50 pts)
    //==========================================================================

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        if(PositionGetString(POSITION_SYMBOL) != m_symbol || PositionGetInteger(POSITION_MAGIC) != Inp_MagicNum)
            continue;
            
        //--- Dados da posição
        long type = PositionGetInteger(POSITION_TYPE);
        double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
        double current_sl = PositionGetDouble(POSITION_SL);
        double current_tp = PositionGetDouble(POSITION_TP);
        double current_price = (type == POSITION_TYPE_BUY) ? 
                               SymbolInfoDouble(m_symbol, SYMBOL_BID) : 
                               SymbolInfoDouble(m_symbol, SYMBOL_ASK);
        
        //--- Inicializar tracking se necessário
        if(GetTicketIndex(ticket) < 0)
            InitTicket(ticket, open_price);
        
        //--- Calcular lucro atual em pontos
        double profit_points = 0;
        if(type == POSITION_TYPE_BUY)
            profit_points = (current_price - open_price) / m_point;
        else
            profit_points = (open_price - current_price) / m_point;
        
        //--- Atualizar melhor preço APENAS se movimento a favor (nunca em pullback)
        double best_price = GetBestPrice(ticket);
        bool new_best = false;
        
        if(type == POSITION_TYPE_BUY && current_price > best_price)
        {
            best_price = current_price;
            SetBestPrice(ticket, best_price);
            new_best = true;
        }
        else if(type == POSITION_TYPE_SELL && current_price < best_price)
        {
            best_price = current_price;
            SetBestPrice(ticket, best_price);
            new_best = true;
        }
        
        //--- Calcular lucro baseado no MELHOR preço atingido
        double best_profit_points = 0;
        if(type == POSITION_TYPE_BUY)
            best_profit_points = (best_price - open_price) / m_point;
        else
            best_profit_points = (open_price - best_price) / m_point;
        
        //--- Flag: BE já foi executado para esta posição?
        bool be_done = IsBEExecuted(ticket);
        
        //======================================================================
        // BREAK EVEN (executa apenas UMA VEZ)
        //======================================================================
        if(Inp_UseBreakEven && !be_done)
        {
            if(type == POSITION_TYPE_BUY)
            {
                // Verificar se lucro atingiu o trigger
                if(profit_points >= Inp_BE_Trigger)
                {
                    double be_level = open_price + Inp_BE_Profit * m_point;
                    be_level = NormalizePrice(be_level);
                    
                    // Só mover se SL atual está abaixo do nível BE
                    if(current_sl < be_level - m_tick_size)
                    {
                        if(m_trade.PositionModify(ticket, be_level, current_tp))
                        {
                            PrintFormat("[BE BUY] Ticket %d: SL moved to %.0f (profit: %.0f pts)", 
                                        ticket, be_level, profit_points);
                            SetBEExecuted(ticket);
                            SetLastTrailSL(ticket, be_level);
                        }
                    }
                    else
                    {
                        // SL já está no nível ou acima, marcar BE como executado
                        SetBEExecuted(ticket);
                        SetLastTrailSL(ticket, current_sl);
                    }
                }
            }
            else if(type == POSITION_TYPE_SELL)
            {
                if(profit_points >= Inp_BE_Trigger)
                {
                    double be_level = open_price - Inp_BE_Profit * m_point;
                    be_level = NormalizePrice(be_level);
                    
                    // Só mover se SL atual está acima do nível BE (ou não definido)
                    if(current_sl > be_level + m_tick_size || current_sl == 0.0)
                    {
                        if(m_trade.PositionModify(ticket, be_level, current_tp))
                        {
                            PrintFormat("[BE SELL] Ticket %d: SL moved to %.0f (profit: %.0f pts)", 
                                        ticket, be_level, profit_points);
                            SetBEExecuted(ticket);
                            SetLastTrailSL(ticket, be_level);
                        }
                    }
                    else
                    {
                        SetBEExecuted(ticket);
                        SetLastTrailSL(ticket, current_sl);
                    }
                }
            }
        }
        
        //======================================================================
        // TRAILING STOP (só após BE, e só quando preço faz novo máximo/mínimo)
        //======================================================================
        // Condição: BE desativado OU BE já executado
        bool can_trail = (!Inp_UseBreakEven || IsBEExecuted(ticket));
        
        if(Inp_UseTrailing && can_trail)
        {
            // Só ativar trailing se lucro baseado no MELHOR preço >= TS_Start
            if(best_profit_points >= Inp_TS_Start)
            {
                // IMPORTANTE: Só mover SL se preço ACABOU DE FAZER novo máximo/mínimo
                // Isso evita movimentos durante pullbacks
                if(new_best)
                {
                    double last_sl = GetLastTrailSL(ticket);
                    
                    if(type == POSITION_TYPE_BUY)
                    {
                        // Novo SL = melhor preço - TS_Start pontos
                        double new_sl = best_price - Inp_TS_Start * m_point;
                        new_sl = NormalizePrice(new_sl);
                        
                        // Só mover se novo SL é MELHOR que o atual em pelo menos TS_Step
                        if(new_sl > last_sl + Inp_TS_Step * m_point)
                        {
                            if(m_trade.PositionModify(ticket, new_sl, current_tp))
                            {
                                PrintFormat("[TRAIL BUY] Ticket %d: SL %.0f -> %.0f (best: %.0f, profit: %.0f pts)", 
                                            ticket, last_sl, new_sl, best_price, profit_points);
                                SetLastTrailSL(ticket, new_sl);
                            }
                        }
                    }
                    else if(type == POSITION_TYPE_SELL)
                    {
                        // Novo SL = melhor preço + TS_Start pontos
                        double new_sl = best_price + Inp_TS_Start * m_point;
                        new_sl = NormalizePrice(new_sl);
                        
                        // Só mover se novo SL é MELHOR que o atual em pelo menos TS_Step
                        if(new_sl < last_sl - Inp_TS_Step * m_point || last_sl == 0.0)
                        {
                            if(m_trade.PositionModify(ticket, new_sl, current_tp))
                            {
                                PrintFormat("[TRAIL SELL] Ticket %d: SL %.0f -> %.0f (best: %.0f, profit: %.0f pts)", 
                                            ticket, last_sl, new_sl, best_price, profit_points);
                                SetLastTrailSL(ticket, new_sl);
                            }
                        }
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
//| Get Ticket Index in tracking arrays                              |
//+------------------------------------------------------------------+
int CTradeManager::GetTicketIndex(ulong ticket)
{
    for(int i = 0; i < m_tracked_count; i++)
    {
        if(m_tracked_tickets[i] == ticket)
            return i;
    }
    return -1; // Não encontrado
}

//+------------------------------------------------------------------+
//| Initialize tracking for a new ticket                             |
//+------------------------------------------------------------------+
void CTradeManager::InitTicket(ulong ticket, double open_price)
{
    if(m_tracked_count < 100)
    {
        m_tracked_tickets[m_tracked_count] = ticket;
        m_best_prices[m_tracked_count] = open_price;
        m_be_executed[m_tracked_count] = false;
        m_last_trail_sl[m_tracked_count] = 0;
        m_tracked_count++;
    }
}

//+------------------------------------------------------------------+
//| Get Best Price for a Ticket                                      |
//+------------------------------------------------------------------+
double CTradeManager::GetBestPrice(ulong ticket)
{
    int idx = GetTicketIndex(ticket);
    if(idx >= 0)
        return m_best_prices[idx];
    return 0.0;
}

//+------------------------------------------------------------------+
//| Set Best Price for a Ticket                                      |
//+------------------------------------------------------------------+
void CTradeManager::SetBestPrice(ulong ticket, double price)
{
    int idx = GetTicketIndex(ticket);
    if(idx >= 0)
        m_best_prices[idx] = price;
}

//+------------------------------------------------------------------+
//| Check if BE was executed for a Ticket                            |
//+------------------------------------------------------------------+
bool CTradeManager::IsBEExecuted(ulong ticket)
{
    int idx = GetTicketIndex(ticket);
    if(idx >= 0)
        return m_be_executed[idx];
    return false;
}

//+------------------------------------------------------------------+
//| Mark BE as executed for a Ticket                                 |
//+------------------------------------------------------------------+
void CTradeManager::SetBEExecuted(ulong ticket)
{
    int idx = GetTicketIndex(ticket);
    if(idx >= 0)
        m_be_executed[idx] = true;
}

//+------------------------------------------------------------------+
//| Get last trailing SL for a Ticket                                |
//+------------------------------------------------------------------+
double CTradeManager::GetLastTrailSL(ulong ticket)
{
    int idx = GetTicketIndex(ticket);
    if(idx >= 0)
        return m_last_trail_sl[idx];
    return 0.0;
}

//+------------------------------------------------------------------+
//| Set last trailing SL for a Ticket                                |
//+------------------------------------------------------------------+
void CTradeManager::SetLastTrailSL(ulong ticket, double sl)
{
    int idx = GetTicketIndex(ticket);
    if(idx >= 0)
        m_last_trail_sl[idx] = sl;
}

//+------------------------------------------------------------------+
//| Remove Ticket from Tracking                                      |
//+------------------------------------------------------------------+
void CTradeManager::RemoveTicket(ulong ticket)
{
    int idx = GetTicketIndex(ticket);
    if(idx >= 0)
    {
        // Mover último para esta posição
        m_tracked_tickets[idx] = m_tracked_tickets[m_tracked_count - 1];
        m_best_prices[idx] = m_best_prices[m_tracked_count - 1];
        m_be_executed[idx] = m_be_executed[m_tracked_count - 1];
        m_last_trail_sl[idx] = m_last_trail_sl[m_tracked_count - 1];
        m_tracked_count--;
    }
}
