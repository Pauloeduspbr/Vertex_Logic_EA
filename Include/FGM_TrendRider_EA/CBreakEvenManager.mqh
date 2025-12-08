//+------------------------------------------------------------------+
//|                                          CBreakEvenManager.mqh |
//|                      FGM TrendRider EA - Módulo Break Even       |
//|                       Gestão de Break Even Individual BUY/SELL   |
//|              Baseado no modelo BreakEvenManager.mqh (Nexus EA)   |
//+------------------------------------------------------------------+
#property copyright "FGM Trading Systems"
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Helper: Descrição de retcodes do MT5                             |
//+------------------------------------------------------------------+
string GetBERetcodeDescription(uint retcode)
{
    switch(retcode)
    {
        case TRADE_RETCODE_DONE:           return "Requisição completada";
        case TRADE_RETCODE_PLACED:         return "Ordem colocada";
        case TRADE_RETCODE_DONE_PARTIAL:   return "Preenchimento parcial";
        case TRADE_RETCODE_ERROR:          return "Erro na requisição";
        case TRADE_RETCODE_TIMEOUT:        return "Timeout";
        case TRADE_RETCODE_INVALID:        return "Requisição inválida";
        case TRADE_RETCODE_INVALID_VOLUME: return "Volume inválido";
        case TRADE_RETCODE_INVALID_PRICE:  return "Preço inválido";
        case TRADE_RETCODE_INVALID_STOPS:  return "Stop Loss/Take Profit inválido";
        case TRADE_RETCODE_TRADE_DISABLED: return "Trading desabilitado";
        case TRADE_RETCODE_MARKET_CLOSED:  return "Mercado fechado";
        case TRADE_RETCODE_NO_MONEY:       return "Fundos insuficientes";
        case TRADE_RETCODE_PRICE_CHANGED:  return "Preço mudou (requote)";
        case TRADE_RETCODE_PRICE_OFF:      return "Sem preço";
        case TRADE_RETCODE_INVALID_EXPIRATION: return "Expiração inválida";
        case TRADE_RETCODE_ORDER_CHANGED:  return "Ordem foi modificada";
        case TRADE_RETCODE_TOO_MANY_REQUESTS: return "Muitas requisições";
        case TRADE_RETCODE_NO_CHANGES:     return "Sem mudanças na modificação";
        case TRADE_RETCODE_SERVER_DISABLES_AT: return "AutoTrading desabilitado pelo servidor";
        case TRADE_RETCODE_CLIENT_DISABLES_AT: return "AutoTrading desabilitado pelo cliente";
        case TRADE_RETCODE_LOCKED:         return "Requisição bloqueada";
        case TRADE_RETCODE_FROZEN:         return "Ordem/Posição congelada";
        case TRADE_RETCODE_INVALID_FILL:   return "Tipo de preenchimento inválido";
        case TRADE_RETCODE_CONNECTION:     return "Sem conexão";
        case TRADE_RETCODE_ONLY_REAL:      return "Permitido apenas em conta real";
        case TRADE_RETCODE_LIMIT_ORDERS:   return "Limite de ordens pendentes";
        case TRADE_RETCODE_LIMIT_VOLUME:   return "Limite de volume de ordens/posições";
        default:                           return "Retcode desconhecido: " + IntegerToString(retcode);
    }
}

//+------------------------------------------------------------------+
//| Classe de Gerenciamento de Break Even                            |
//+------------------------------------------------------------------+
class CBreakEvenManager
{
private:
    // Configurações (unificadas para BUY e SELL)
    bool     m_enabled;
    int      m_trigger;           // Trigger em STEPS (após conversão)
    int      m_offset;            // Offset em STEPS (após conversão)
    
    // Controle interno
    bool     m_initialized;
    CTrade   m_trade;
    datetime m_last_market_closed_log;
    
    // Log de ativações (evita múltiplas ativações)
    ulong    m_activated_tickets[];
    
    // Estatísticas
    int      m_total_activations_buy;
    int      m_total_activations_sell;
    int      m_total_saves;
    
    // Informações do símbolo (cache)
    double   m_point;
    double   m_tick_size;
    double   m_price_step;
    int      m_digits;
    string   m_symbol;
    
public:
    //--- Construtor/Destrutor
    CBreakEvenManager(void);
    ~CBreakEvenManager(void);
    
    //--- Inicialização
    bool Init(string symbol, bool enabled, int trigger, int offset);
    
    //--- Métodos principais
    bool CheckAndApply(ulong ticket);
    bool IsBEActivated(ulong ticket);
    void RemoveTicket(ulong ticket);
    void Reset(void);
    
    //--- Estatísticas
    int GetTotalActivationsBuy(void) { return m_total_activations_buy; }
    int GetTotalActivationsSell(void) { return m_total_activations_sell; }
    int GetTotalActivations(void) { return m_total_activations_buy + m_total_activations_sell; }
    int GetTotalSaves(void) { return m_total_saves; }
    
    //--- Utilidades
    void PrintStats(void);
    
private:
    //--- Métodos internos
    void AddActivatedTicket(ulong ticket);
    bool IsTicketInList(ulong ticket);
    bool IsMarketOpenNow(string symbol);
};

//+------------------------------------------------------------------+
//| Construtor                                                        |
//+------------------------------------------------------------------+
CBreakEvenManager::CBreakEvenManager(void)
{
    m_initialized = false;
    m_enabled = false;
    m_trigger = 0;
    m_offset = 0;
    
    m_total_activations_buy = 0;
    m_total_activations_sell = 0;
    m_total_saves = 0;
    
    m_point = 0;
    m_tick_size = 0;
    m_price_step = 0;
    m_digits = 0;
    m_symbol = "";
    
    ArrayResize(m_activated_tickets, 0);
    m_last_market_closed_log = 0;
}

//+------------------------------------------------------------------+
//| Destrutor                                                         |
//+------------------------------------------------------------------+
CBreakEvenManager::~CBreakEvenManager(void)
{
    ArrayFree(m_activated_tickets);
}

//+------------------------------------------------------------------+
//| Inicialização do módulo                                          |
//+------------------------------------------------------------------+
bool CBreakEvenManager::Init(string symbol, bool enabled, int trigger, int offset)
{
    m_symbol = symbol;
    m_enabled = enabled;
    
    if(!m_enabled)
    {
        m_initialized = true;
        Print("🔒 [BE] Break Even Manager DESATIVADO");
        return true;
    }
    
    // Obter informações do símbolo
    m_point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    m_tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    m_digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    
    // Usar TICK_SIZE (B3) ou POINT (índices) - o que for maior
    m_price_step = (m_tick_size > m_point) ? m_tick_size : m_point;
    
    // Converter inputs de pontos para steps internos
    int trigger_converted = trigger;
    int offset_converted = offset;
    
    if(m_tick_size > m_point)
    {
        // B3/Special assets: converter para steps
        trigger_converted = (int)MathRound((double)trigger / m_tick_size);
        offset_converted = (int)MathRound((double)offset / m_tick_size);
        
        Print("📊 [BE] Conversão B3 (input → steps):");
        Print(StringFormat("   Trigger: %d pts → %d steps (%.1f distance)", 
              trigger, trigger_converted, trigger_converted * m_tick_size));
        Print(StringFormat("   Offset: %d pts → %d steps (%.1f distance)", 
              offset, offset_converted, offset_converted * m_tick_size));
    }
    
    // Validação
    if(trigger_converted <= 0)
    {
        Print("❌ [BE] Erro: Trigger deve ser > 0. Valor convertido: ", trigger_converted);
        return false;
    }
    
    if(offset_converted < 0)
    {
        Print("❌ [BE] Erro: Offset deve ser >= 0. Valor convertido: ", offset_converted);
        return false;
    }
    
    // Validação: Trigger deve ser maior que Offset para fazer sentido
    if(trigger_converted <= offset_converted)
    {
        Print("❌ [BE] ERRO: Trigger (", trigger_converted, ") deve ser MAIOR que Offset (", offset_converted, ")");
        Print("   O BE só ativa quando lucro >= Trigger, e move SL para Entry + Offset");
        Print("   Se Trigger <= Offset, o SL estaria além do preço atual!");
        return false;
    }
    
    // Armazenar configurações convertidas
    m_trigger = trigger_converted;
    m_offset = offset_converted;
    
    m_initialized = true;
    
    Print("✅ [BE] Break Even Manager inicializado:");
    Print(StringFormat("   Trigger=%d steps | Offset=%d steps | PriceStep=%.5f", 
          m_trigger, m_offset, m_price_step));
    
    return true;
}

//+------------------------------------------------------------------+
//| Verifica e aplica Break Even em uma posição                      |
//+------------------------------------------------------------------+
bool CBreakEvenManager::CheckAndApply(ulong ticket)
{
    if(!m_initialized || !m_enabled)
        return false;
    
    // Verificar se posição existe
    if(!PositionSelectByTicket(ticket))
        return false;
    
    // Verificar se BE já foi ativado para este ticket
    if(IsTicketInList(ticket))
        return true;  // Já está em BE
    
    // Obter informações da posição
    ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
    double current_sl = PositionGetDouble(POSITION_SL);
    double current_tp = PositionGetDouble(POSITION_TP);
    string symbol = PositionGetString(POSITION_SYMBOL);
    
    // Verificar se mercado está aberto para modificações
    if(!IsMarketOpenNow(symbol))
    {
        datetime now = TimeCurrent();
        if(m_last_market_closed_log == 0 || (now - m_last_market_closed_log) >= 300)
        {
            Print("🔒 [BE] Mercado FECHADO para ", symbol, " - aguardando reabertura");
            m_last_market_closed_log = now;
        }
        return false;
    }
    
    // Obter preço atual
    double current_price;
    if(pos_type == POSITION_TYPE_BUY)
        current_price = SymbolInfoDouble(symbol, SYMBOL_BID);
    else
        current_price = SymbolInfoDouble(symbol, SYMBOL_ASK);
    
    // Calcular lucro em steps
    double profit_steps;
    if(pos_type == POSITION_TYPE_BUY)
        profit_steps = (current_price - entry_price) / m_price_step;
    else
        profit_steps = (entry_price - current_price) / m_price_step;
    
    // Verificar se atingiu o trigger
    if(profit_steps < m_trigger)
        return false;
    
    // Calcular novo SL
    double new_sl = 0;
    double offset_distance = m_offset * m_price_step;
    
    if(pos_type == POSITION_TYPE_BUY)
    {
        // BUY: SL = Entry + Offset
        new_sl = NormalizeDouble(entry_price + offset_distance, m_digits);
        
        // Se o SL atual já atingiu ou superou o alvo de BE, marcar e sair
        double target_be = new_sl;
        double tol = 2 * m_price_step;
        if(m_offset >= 0 && current_sl > 0 && current_sl >= (target_be - tol))
        {
            AddActivatedTicket(ticket);
            Print("✅ [BE] BUY #", ticket, ": BE já aplicado anteriormente (SL=", current_sl, ")");
            return true;
        }
        
        // VALIDAÇÃO 1: SL não pode ultrapassar TP em BUY
        if(current_tp > 0 && new_sl >= current_tp)
        {
            Print("⚠️ [BE] BUY #", ticket, ": SL alvo (", new_sl, ") ultrapassaria TP (", current_tp, ")");
            return false;
        }
        
        // VALIDAÇÃO 2: SL deve estar ABAIXO do preço atual
        double min_distance_for_be = (m_trigger - m_offset) * m_price_step;
        double current_distance = current_price - new_sl;
        
        if(current_distance <= 0)
        {
            Print("⚠️ [BE] BUY #", ticket, ": SL alvo (", new_sl, ") >= preço atual (", current_price, ") - impossível");
            return false;
        }
        
        if(current_distance < min_distance_for_be)
        {
            Print("⚠️ [BE] BUY #", ticket, ": Distância insuficiente entre SL e preço");
            return false;
        }
        
        // Validação: novo SL deve ser melhor (maior) que o atual
        if(current_sl > 0 && new_sl <= current_sl)
            return false;
        
        // Evitar modificação se SL é idêntico
        if(current_sl > 0 && MathAbs(new_sl - current_sl) < m_price_step)
            return false;
    }
    else // POSITION_TYPE_SELL
    {
        // SELL: SL = Entry - Offset
        new_sl = NormalizeDouble(entry_price - offset_distance, m_digits);
        
        // Se o SL atual já atingiu ou superou o alvo de BE, marcar e sair
        double target_be = new_sl;
        double tol = 2 * m_price_step;
        if(m_offset >= 0 && current_sl > 0 && current_sl <= (target_be + tol))
        {
            AddActivatedTicket(ticket);
            Print("✅ [BE] SELL #", ticket, ": BE já aplicado anteriormente (SL=", current_sl, ")");
            return true;
        }
        
        // VALIDAÇÃO 1: SL não pode ultrapassar TP em SELL
        if(current_tp > 0 && new_sl <= current_tp)
        {
            Print("⚠️ [BE] SELL #", ticket, ": SL alvo (", new_sl, ") ultrapassaria TP (", current_tp, ")");
            return false;
        }
        
        // VALIDAÇÃO 2: SL deve estar ACIMA do preço atual
        double min_distance_for_be = (m_trigger - m_offset) * m_price_step;
        double current_distance = new_sl - current_price;
        
        if(current_distance <= 0)
        {
            Print("⚠️ [BE] SELL #", ticket, ": SL alvo (", new_sl, ") <= preço atual (", current_price, ") - impossível");
            return false;
        }
        
        if(current_distance < min_distance_for_be)
        {
            Print("⚠️ [BE] SELL #", ticket, ": Distância insuficiente entre SL e preço");
            return false;
        }
        
        // Validação: novo SL deve ser melhor (menor) que o atual
        if(current_sl > 0 && new_sl >= current_sl)
            return false;
        
        // Evitar modificação se SL é idêntico
        if(current_sl > 0 && MathAbs(new_sl - current_sl) < m_price_step)
            return false;
    }
    
    // Validar STOPS_LEVEL e FREEZE_LEVEL do broker
    long stop_level = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
    long freeze_level = SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
    int min_level = (int)MathMax((double)stop_level, (double)freeze_level);
    
    if(min_level > 0)
    {
        double distance_to_price;
        if(pos_type == POSITION_TYPE_BUY)
            distance_to_price = (current_price - new_sl) / m_price_step;
        else
            distance_to_price = (new_sl - current_price) / m_price_step;
        
        if(distance_to_price < min_level)
        {
            Print("⚠️ [BE] #", ticket, ": SL muito próximo do preço (min_level=", min_level, ")");
            return false;
        }
    }
    
    // Reselecionar posição antes de modificar
    if(!PositionSelectByTicket(ticket))
    {
        Print("⚠️ [BE] Posição #", ticket, " perdida durante processamento");
        return false;
    }
    
    // Executar modificação via CTrade
    m_trade.SetExpertMagicNumber((ulong)PositionGetInteger(POSITION_MAGIC));
    
    if(m_trade.PositionModify(ticket, new_sl, current_tp))
    {
        uint retcode = m_trade.ResultRetcode();
        
        if(retcode == TRADE_RETCODE_DONE)
        {
            // Registrar ativação
            AddActivatedTicket(ticket);
            
            if(pos_type == POSITION_TYPE_BUY)
                m_total_activations_buy++;
            else
                m_total_activations_sell++;
            
            double protected_steps;
            if(pos_type == POSITION_TYPE_BUY)
                protected_steps = (new_sl - entry_price) / m_price_step;
            else
                protected_steps = (entry_price - new_sl) / m_price_step;
            
            Print("🎯 [BE] Break Even ATIVADO para ", 
                  (pos_type == POSITION_TYPE_BUY ? "BUY" : "SELL"), " #", ticket);
            Print("   📈 Lucro atual: +", (int)profit_steps, " steps");
            Print("   🛡️ Novo SL: ", new_sl, " (+", (int)protected_steps, " steps protegidos)");
            Print("   📊 Entry: ", entry_price, " | TP: ", current_tp);
            
            return true;
        }
        else if(retcode == TRADE_RETCODE_MARKET_CLOSED)
        {
            datetime now = TimeCurrent();
            if(m_last_market_closed_log == 0 || (now - m_last_market_closed_log) >= 300)
            {
                Print("🔒 [BE] #", ticket, ": Mercado fechado");
                m_last_market_closed_log = now;
            }
        }
        else
        {
            Print("❌ [BE] Falha ao modificar #", ticket, 
                  " - Retcode: ", retcode, 
                  " (", GetBERetcodeDescription(retcode), ")");
        }
    }
    else
    {
        Print("❌ [BE] Erro ao enviar ordem #", ticket, " - Error: ", GetLastError());
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Verifica se BE já foi ativado para um ticket                     |
//+------------------------------------------------------------------+
bool CBreakEvenManager::IsBEActivated(ulong ticket)
{
    // Verificar se está na lista de ativados
    if(IsTicketInList(ticket))
        return true;
    
    // Verificação adicional: analisar distância do SL atual vs Entry ± Offset
    if(!PositionSelectByTicket(ticket))
        return false;
    
    double entry = PositionGetDouble(POSITION_PRICE_OPEN);
    double sl = PositionGetDouble(POSITION_SL);
    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    
    if(sl == 0)
        return false;
    
    double tol = 2 * m_price_step;
    
    if(type == POSITION_TYPE_BUY)
    {
        double target = entry + (m_offset * m_price_step);
        if(sl >= (target - tol))
        {
            // SL já está no nível de BE, adicionar à lista
            AddActivatedTicket(ticket);
            return true;
        }
    }
    else // SELL
    {
        double target = entry - (m_offset * m_price_step);
        if(sl <= (target + tol))
        {
            // SL já está no nível de BE, adicionar à lista
            AddActivatedTicket(ticket);
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Adiciona ticket à lista de ativados                              |
//+------------------------------------------------------------------+
void CBreakEvenManager::AddActivatedTicket(ulong ticket)
{
    if(IsTicketInList(ticket))
        return;
    
    int size = ArraySize(m_activated_tickets);
    ArrayResize(m_activated_tickets, size + 1);
    m_activated_tickets[size] = ticket;
}

//+------------------------------------------------------------------+
//| Verifica se ticket está na lista                                 |
//+------------------------------------------------------------------+
bool CBreakEvenManager::IsTicketInList(ulong ticket)
{
    int size = ArraySize(m_activated_tickets);
    for(int i = 0; i < size; i++)
    {
        if(m_activated_tickets[i] == ticket)
            return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Remove ticket da lista (quando posição fecha)                    |
//+------------------------------------------------------------------+
void CBreakEvenManager::RemoveTicket(ulong ticket)
{
    int size = ArraySize(m_activated_tickets);
    for(int i = 0; i < size; i++)
    {
        if(m_activated_tickets[i] == ticket)
        {
            // Mover últimos elementos para preencher o gap
            for(int j = i; j < size - 1; j++)
                m_activated_tickets[j] = m_activated_tickets[j + 1];
            
            ArrayResize(m_activated_tickets, size - 1);
            break;
        }
    }
}

//+------------------------------------------------------------------+
//| Reset das estatísticas e lista de tickets                        |
//+------------------------------------------------------------------+
void CBreakEvenManager::Reset(void)
{
    ArrayResize(m_activated_tickets, 0);
    m_total_activations_buy = 0;
    m_total_activations_sell = 0;
    m_total_saves = 0;
    
    Print("🔄 [BE] Estatísticas resetadas.");
}

//+------------------------------------------------------------------+
//| Imprime estatísticas do Break Even                               |
//+------------------------------------------------------------------+
void CBreakEvenManager::PrintStats(void)
{
    Print("═══════════════════════════════════════");
    Print("🎯 [BE] ESTATÍSTICAS BREAK EVEN");
    Print("═══════════════════════════════════════");
    Print("   📈 Ativações BUY: ", m_total_activations_buy);
    Print("   📉 Ativações SELL: ", m_total_activations_sell);
    Print("   🛡️ Total de Saves: ", m_total_saves);
    Print("   📊 Tickets Ativos: ", ArraySize(m_activated_tickets));
    Print("═══════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Verifica se mercado está aberto para trading                     |
//+------------------------------------------------------------------+
bool CBreakEvenManager::IsMarketOpenNow(string symbol)
{
    int trade_mode = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
    if(trade_mode == SYMBOL_TRADE_MODE_DISABLED || trade_mode == SYMBOL_TRADE_MODE_CLOSEONLY)
        return false;
    
    // Verificar sessão de trading
    datetime current_time = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(current_time, dt);
    
    datetime from_time, to_time;
    if(!SymbolInfoSessionTrade(symbol, (ENUM_DAY_OF_WEEK)dt.day_of_week, 0, from_time, to_time))
        return true;  // Se não conseguir obter sessão, assumir aberto
    
    // Construir horários de hoje
    datetime today_start = current_time - (dt.hour * 3600 + dt.min * 60 + dt.sec);
    datetime session_from = today_start + (int)(from_time % 86400);
    datetime session_to = today_start + (int)(to_time % 86400);
    
    return (current_time >= session_from && current_time <= session_to);
}

//+------------------------------------------------------------------+
