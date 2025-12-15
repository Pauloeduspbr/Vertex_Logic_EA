//+------------------------------------------------------------------+
//|                                        CTrailingStopManager.mqh |
//|                     FGM TrendRider EA - Módulo Trailing Stop     |
//|                   Gestão de Trailing Stop Individual BUY/SELL    |
//|            Baseado no modelo TrailingStopManager.mqh (Nexus EA)  |
//+------------------------------------------------------------------+
#property copyright "FGM Trading Systems"
#property version   "2.00"
#property strict

#ifndef CTRAILINGSTOPMANAGER_MQH
#define CTRAILINGSTOPMANAGER_MQH

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Helper: Descrição de retcodes do MT5                             |
//+------------------------------------------------------------------+
string GetTSRetcodeDescription(uint retcode)
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
//| Estrutura para tracking de Trailing Stop por ticket              |
//+------------------------------------------------------------------+
struct TrailingRecord
{
    ulong    ticket;              // Ticket da posição
    double   highest_price;       // Maior preço (BUY) ou menor preço (SELL)
    double   current_sl;          // SL atual do trailing
    double   last_move_price;     // Preço quando fez último movimento
    datetime last_bar_time;       // Última barra que moveu
    bool     trailing_started;    // Se trailing já iniciou
    
    // Campos para deduplicação de erros (como no modelo Nexus)
    uint     last_retcode;        // Último retcode de erro
    int      last_error;          // Último GetLastError
    double   last_attempt_sl;     // Último SL tentado
    datetime last_failure_log_time; // Última vez que logou falha
};

//+------------------------------------------------------------------+
//| Classe de Gerenciamento de Trailing Stop                         |
//+------------------------------------------------------------------+
class CTrailingStopManager
{
private:
    // Configurações
    bool     m_enabled;
    int      m_trigger;           // Trigger em STEPS (após conversão)
    int      m_distance;          // Distância em STEPS (após conversão)
    int      m_step;              // Step mínimo em STEPS (após conversão)
    
    // Controle interno
    bool     m_initialized;
    CTrade   m_trade;
    datetime m_last_market_closed_log;
    datetime m_last_waiting_log_time;  // Throttling de logs de espera
    
    // Registros de trailing por ticket
    TrailingRecord m_trailing_records[];
    
    // Estatísticas
    int      m_total_moves;
    int      m_total_activations_buy;
    int      m_total_activations_sell;
    
    // Informações do símbolo (cache)
    double   m_point;
    double   m_tick_size;
    double   m_price_step;
    int      m_digits;
    string   m_symbol;
    
public:
    //--- Construtor/Destrutor
    CTrailingStopManager(void);
    ~CTrailingStopManager(void);
    
    //--- Inicialização
    bool Init(string symbol, bool enabled, int trigger, int distance, int step);
    
    //--- Métodos principais
    bool Update(ulong ticket);
    bool IsTrailing(ulong ticket);
    void RemoveTicket(ulong ticket);
    void Reset(void);
    
    //--- Estatísticas
    int GetTotalMoves(void) { return m_total_moves; }
    int GetTotalActivationsBuy(void) { return m_total_activations_buy; }
    int GetTotalActivationsSell(void) { return m_total_activations_sell; }
    int GetTotalActivations(void) { return m_total_activations_buy + m_total_activations_sell; }
    
    //--- Utilidades
    void PrintStats(void);
    
private:
    //--- Métodos internos
    int  FindRecord(ulong ticket);
    int  CreateRecord(ulong ticket);
    bool IsMarketOpenNow(string symbol);
    bool ShouldLogFailure(int record_idx, uint retcode, int error, double attempted_sl);
};

//+------------------------------------------------------------------+
//| Construtor                                                        |
//+------------------------------------------------------------------+
CTrailingStopManager::CTrailingStopManager(void)
{
    m_initialized = false;
    m_enabled = false;
    m_trigger = 0;
    m_distance = 0;
    m_step = 1;
    m_total_moves = 0;
    m_total_activations_buy = 0;
    m_total_activations_sell = 0;
    m_point = 0;
    m_tick_size = 0;
    m_price_step = 0;
    m_digits = 0;
    m_symbol = "";
    
    ArrayResize(m_trailing_records, 0);
    m_last_market_closed_log = 0;
    m_last_waiting_log_time = 0;
}

//+------------------------------------------------------------------+
//| Destrutor                                                         |
//+------------------------------------------------------------------+
CTrailingStopManager::~CTrailingStopManager(void)
{
    ArrayFree(m_trailing_records);
}

//+------------------------------------------------------------------+
//| Inicialização do módulo                                          |
//+------------------------------------------------------------------+
bool CTrailingStopManager::Init(string symbol, bool enabled, int trigger, int distance, int step)
{
    m_symbol = symbol;
    m_enabled = enabled;
    
    if(!m_enabled)
    {
        m_initialized = true;
        Print("🔒 [TS] Trailing Stop Manager DESATIVADO");
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
    int distance_converted = distance;
    int step_converted = step;
    
    if(m_tick_size > m_point)
    {
        // B3/Special assets: converter para steps
        trigger_converted = (int)MathRound((double)trigger / m_tick_size);
        distance_converted = (int)MathRound((double)distance / m_tick_size);
        step_converted = (int)MathRound((double)step / m_tick_size);
        
        Print("📊 [TS] Conversão B3 (input → steps):");
        Print(StringFormat("   Trigger: %d pts → %d steps (%.1f distance)", 
              trigger, trigger_converted, trigger_converted * m_tick_size));
        Print(StringFormat("   Distance: %d pts → %d steps (%.1f distance)", 
              distance, distance_converted, distance_converted * m_tick_size));
        Print(StringFormat("   Step: %d pts → %d steps (%.1f movement)", 
              step, step_converted, step_converted * m_tick_size));
    }
    
    // Validação
    if(trigger_converted <= 0)
    {
        Print("❌ [TS] Erro: Trigger deve ser > 0. Valor convertido: ", trigger_converted);
        return false;
    }
    
    if(distance_converted <= 0)
    {
        Print("❌ [TS] Erro: Distance deve ser > 0. Valor convertido: ", distance_converted);
        return false;
    }
    
    if(step_converted < 1)
    {
        Print("⚠️ [TS] Aviso: Step < 1, usando 1 como mínimo");
        step_converted = 1;
    }
    
    // Validação: Trigger deve ser maior ou igual a Distance
    // NOTA: Se Trigger == Distance, o SL começa exatamente no entry
    //       Se Trigger > Distance, o SL já começa no lucro
    if(trigger_converted < distance_converted)
    {
        Print("❌ [TS] ERRO: Trigger (", trigger_converted, ") deve ser MAIOR ou IGUAL a Distance (", distance_converted, ")");
        Print("   O TS só ativa quando lucro >= Trigger, então se Trigger < Distance,");
        Print("   o SL estaria ANTES do preço de entrada!");
        return false;
    }
    
    // Aviso se Trigger == Distance (SL começa no entry, sem lucro protegido inicialmente)
    if(trigger_converted == distance_converted)
    {
        Print("⚠️ [TS] AVISO: Trigger == Distance (ambos ", trigger_converted, " steps)");
        Print("   O SL começará no preço de entrada. Recomendado: Trigger > Distance para iniciar com lucro protegido.");
    }
    
    // Validação: Ratio Trigger:Step deve ser >= 2:1
    double ratio = (double)trigger_converted / (double)step_converted;
    if(ratio < 2.0)
    {
        Print("⚠️ [TS] AVISO: Ratio Trigger:Step = ", DoubleToString(ratio, 1), 
              " (recomendado >= 2.0)");
        Print("   Trigger baixo demais em relação ao Step pode causar movimentos prematuros");
    }

    
    // Armazenar configurações convertidas
    m_trigger = trigger_converted;
    m_distance = distance_converted;
    m_step = step_converted;
    
    m_initialized = true;
    
    Print("✅ [TS] Trailing Stop Manager inicializado:");
    Print(StringFormat("   Trigger=%d steps | Distance=%d steps | Step=%d steps | PriceStep=%.5f", 
          m_trigger, m_distance, m_step, m_price_step));
    
    return true;
}

//+------------------------------------------------------------------+
//| Atualiza Trailing Stop para uma posição                          |
//+------------------------------------------------------------------+
bool CTrailingStopManager::Update(ulong ticket)
{
    if(!m_initialized || !m_enabled)
        return false;
    
    // Verificar se posição existe
    if(!PositionSelectByTicket(ticket))
        return false;
    
    // Obter informações da posição
    ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
    double current_sl = PositionGetDouble(POSITION_SL);
    double current_tp = PositionGetDouble(POSITION_TP);
    string symbol = PositionGetString(POSITION_SYMBOL);
    
    // Verificar se mercado está aberto
    if(!IsMarketOpenNow(symbol))
    {
        datetime now = TimeCurrent();
        if(m_last_market_closed_log == 0 || (now - m_last_market_closed_log) >= 300)
        {
            Print("🔒 [TS] Mercado FECHADO para ", symbol, " - aguardando reabertura");
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
    
    // Verificar se atingiu o trigger para ativar trailing
    if(profit_steps < m_trigger)
        return false;
    
    // Buscar ou criar registro para este ticket
    int record_idx = FindRecord(ticket);
    if(record_idx < 0)
    {
        record_idx = CreateRecord(ticket);
        if(record_idx < 0)
            return false;
        
        if(pos_type == POSITION_TYPE_BUY)
            m_total_activations_buy++;
        else
            m_total_activations_sell++;
        
        Print("🚀 [TS] Trailing INICIADO para ", 
              (pos_type == POSITION_TYPE_BUY ? "BUY" : "SELL"), " #", ticket,
              " | Lucro: +", (int)profit_steps, " steps");
    }
    
    // Atualizar highest/lowest price
    if(pos_type == POSITION_TYPE_BUY)
    {
        if(current_price > m_trailing_records[record_idx].highest_price || 
           m_trailing_records[record_idx].highest_price == 0)
            m_trailing_records[record_idx].highest_price = current_price;
    }
    else
    {
        if(current_price < m_trailing_records[record_idx].highest_price || 
           m_trailing_records[record_idx].highest_price == 0 || 
           m_trailing_records[record_idx].highest_price > 1000000)
            m_trailing_records[record_idx].highest_price = current_price;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // CÁLCULO GRADUAL DO SL (como no modelo Nexus)
    // candidate_sl = current_sl ± step
    // target_sl = price ∓ distance
    // new_sl = melhor dos dois
    // ═══════════════════════════════════════════════════════════════
    double step_distance = m_step * m_price_step;
    double trail_distance = m_distance * m_price_step;
    
    double candidate_sl = 0;
    double target_sl = 0;
    double new_sl = 0;
    
    if(pos_type == POSITION_TYPE_BUY)
    {
        // BUY: SL sobe
        if(current_sl > 0)
            candidate_sl = NormalizeDouble(current_sl + step_distance, m_digits);
        else
            candidate_sl = NormalizeDouble(entry_price, m_digits);  // Começar do entry
        
        target_sl = NormalizeDouble(m_trailing_records[record_idx].highest_price - trail_distance, m_digits);
        
        // Escolher o MENOR dos dois (mais conservador)
        // Mas deve ser MAIOR que o SL atual
        if(candidate_sl < target_sl)
            new_sl = candidate_sl;  // Movimento gradual
        else
            new_sl = target_sl;     // Já atingiu o target
        
        // Validação: novo SL deve ser MAIOR que o atual
        if(current_sl > 0 && new_sl <= current_sl)
            return false;
        
        // SL deve estar abaixo do preço atual
        if(new_sl >= current_price)
            return false;
    }
    else
    {
        // SELL: SL desce
        if(current_sl > 0 && current_sl < 1000000)
            candidate_sl = NormalizeDouble(current_sl - step_distance, m_digits);
        else
            candidate_sl = NormalizeDouble(entry_price, m_digits);  // Começar do entry
        
        target_sl = NormalizeDouble(m_trailing_records[record_idx].highest_price + trail_distance, m_digits);
        
        // Escolher o MAIOR dos dois (mais conservador para SELL)
        // Mas deve ser MENOR que o SL atual
        if(candidate_sl > target_sl)
            new_sl = candidate_sl;  // Movimento gradual
        else
            new_sl = target_sl;     // Já atingiu o target
        
        // Validação: novo SL deve ser MENOR que o atual
        if(current_sl > 0 && current_sl < 1000000 && new_sl >= current_sl)
            return false;
        
        // SL deve estar acima do preço atual
        if(new_sl <= current_price)
            return false;
    }
    
    // Validar contra TP
    if(current_tp > 0)
    {
        if(pos_type == POSITION_TYPE_BUY && new_sl >= current_tp)
            return false;
        if(pos_type == POSITION_TYPE_SELL && new_sl <= current_tp)
            return false;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // THROTTLING: Regra dos 75% - só move se preço avançou 75% do step
    // COM VERIFICAÇÃO DIRECIONAL
    // ═══════════════════════════════════════════════════════════════
    double min_movement = step_distance * 0.75;
    
    if(m_trailing_records[record_idx].last_move_price > 0)
    {
        double price_moved;
        if(pos_type == POSITION_TYPE_BUY)
        {
            price_moved = current_price - m_trailing_records[record_idx].last_move_price;
            // BUY: só move se preço SUBIU
            if(price_moved < min_movement)
            {
                // Log de throttling (uma vez a cada 60s)
                datetime now = TimeCurrent();
                if(m_last_waiting_log_time == 0 || (now - m_last_waiting_log_time) >= 60)
                {
                    // Silencioso - não logar waiting a cada tick
                    m_last_waiting_log_time = now;
                }
                return false;
            }
        }
        else
        {
            price_moved = m_trailing_records[record_idx].last_move_price - current_price;
            // SELL: só move se preço DESCEU
            if(price_moved < min_movement)
            {
                datetime now = TimeCurrent();
                if(m_last_waiting_log_time == 0 || (now - m_last_waiting_log_time) >= 60)
                {
                    m_last_waiting_log_time = now;
                }
                return false;
            }
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // THROTTLING: Limite de um movimento por barra
    // ═══════════════════════════════════════════════════════════════
    datetime current_bar = iTime(symbol, PERIOD_CURRENT, 0);
    if(m_trailing_records[record_idx].last_bar_time == current_bar)
        return false;
    
    // ═══════════════════════════════════════════════════════════════
    // VALIDAÇÃO: STOPS_LEVEL e FREEZE_LEVEL
    // ═══════════════════════════════════════════════════════════════
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
            Print("⚠️ [TS] #", ticket, ": SL muito próximo (dist=", (int)distance_to_price, 
                  " < min_level=", min_level, ")");
            return false;
        }
    }
    
    // Evitar modificação se SL é idêntico
    if(current_sl > 0 && MathAbs(new_sl - current_sl) < m_price_step)
        return false;
    
    // ═══════════════════════════════════════════════════════════════
    // EXECUTAR MODIFICAÇÃO via CTrade
    // ═══════════════════════════════════════════════════════════════
    m_trade.SetExpertMagicNumber((ulong)PositionGetInteger(POSITION_MAGIC));
    
    if(m_trade.PositionModify(ticket, new_sl, current_tp))
    {
        uint retcode = m_trade.ResultRetcode();
        
        if(retcode == TRADE_RETCODE_DONE)
        {
            // Atualizar registro
            m_trailing_records[record_idx].current_sl = new_sl;
            m_trailing_records[record_idx].last_move_price = current_price;
            m_trailing_records[record_idx].last_bar_time = current_bar;
            m_trailing_records[record_idx].trailing_started = true;
            
            // Limpar info de erros anteriores
            m_trailing_records[record_idx].last_retcode = 0;
            m_trailing_records[record_idx].last_error = 0;
            
            m_total_moves++;
            
            double sl_distance_steps;
            if(pos_type == POSITION_TYPE_BUY)
                sl_distance_steps = (new_sl - entry_price) / m_price_step;
            else
                sl_distance_steps = (entry_price - new_sl) / m_price_step;
            
            Print("📈 [TS] Trailing MOVEU ", 
                  (pos_type == POSITION_TYPE_BUY ? "BUY" : "SELL"), " #", ticket,
                  " | Novo SL: ", new_sl, " (+", (int)sl_distance_steps, " steps protegidos)");
            
            return true;
        }
        else if(retcode == TRADE_RETCODE_MARKET_CLOSED)
        {
            datetime now = TimeCurrent();
            if(m_last_market_closed_log == 0 || (now - m_last_market_closed_log) >= 300)
            {
                Print("🔒 [TS] #", ticket, ": Mercado fechado");
                m_last_market_closed_log = now;
            }
        }
        else
        {
            // Deduplicação de logs de erro
            int current_error = (int)GetLastError();
            if(ShouldLogFailure(record_idx, retcode, current_error, new_sl))
            {
                Print("❌ [TS] Falha ao modificar #", ticket, 
                      " - Retcode: ", retcode, 
                      " (", GetTSRetcodeDescription(retcode), ")");
                
                // Atualizar info de erro para deduplicação
                m_trailing_records[record_idx].last_retcode = retcode;
                m_trailing_records[record_idx].last_error = current_error;
                m_trailing_records[record_idx].last_attempt_sl = new_sl;
                m_trailing_records[record_idx].last_failure_log_time = TimeCurrent();
            }
        }
    }
    else
    {
        int current_error = (int)GetLastError();
        if(ShouldLogFailure(record_idx, 0, current_error, new_sl))
        {
            Print("❌ [TS] Erro ao enviar ordem #", ticket, " - Error: ", current_error);
            
            m_trailing_records[record_idx].last_retcode = 0;
            m_trailing_records[record_idx].last_error = current_error;
            m_trailing_records[record_idx].last_attempt_sl = new_sl;
            m_trailing_records[record_idx].last_failure_log_time = TimeCurrent();
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Verifica se trailing está ativo para um ticket                   |
//+------------------------------------------------------------------+
bool CTrailingStopManager::IsTrailing(ulong ticket)
{
    int idx = FindRecord(ticket);
    return (idx >= 0 && m_trailing_records[idx].trailing_started);
}

//+------------------------------------------------------------------+
//| Busca registro pelo ticket                                       |
//+------------------------------------------------------------------+
int CTrailingStopManager::FindRecord(ulong ticket)
{
    int size = ArraySize(m_trailing_records);
    for(int i = 0; i < size; i++)
    {
        if(m_trailing_records[i].ticket == ticket)
            return i;
    }
    return -1;
}

//+------------------------------------------------------------------+
//| Cria novo registro para um ticket                                |
//+------------------------------------------------------------------+
int CTrailingStopManager::CreateRecord(ulong ticket)
{
    int size = ArraySize(m_trailing_records);
    ArrayResize(m_trailing_records, size + 1);
    
    // Inicializar novo registro
    m_trailing_records[size].ticket = ticket;
    m_trailing_records[size].highest_price = 0;
    m_trailing_records[size].current_sl = 0;
    m_trailing_records[size].last_move_price = 0;
    m_trailing_records[size].last_bar_time = 0;
    m_trailing_records[size].trailing_started = false;
    
    // Campos de deduplicação
    m_trailing_records[size].last_retcode = 0;
    m_trailing_records[size].last_error = 0;
    m_trailing_records[size].last_attempt_sl = 0;
    m_trailing_records[size].last_failure_log_time = 0;
    
    return size;
}

//+------------------------------------------------------------------+
//| Remove registro de um ticket (quando posição fecha)              |
//+------------------------------------------------------------------+
void CTrailingStopManager::RemoveTicket(ulong ticket)
{
    int size = ArraySize(m_trailing_records);
    for(int i = 0; i < size; i++)
    {
        if(m_trailing_records[i].ticket == ticket)
        {
            // Mover últimos elementos para preencher o gap
            for(int j = i; j < size - 1; j++)
                m_trailing_records[j] = m_trailing_records[j + 1];
            
            ArrayResize(m_trailing_records, size - 1);
            break;
        }
    }
}

//+------------------------------------------------------------------+
//| Reset das estatísticas e registros                               |
//+------------------------------------------------------------------+
void CTrailingStopManager::Reset(void)
{
    ArrayResize(m_trailing_records, 0);
    m_total_moves = 0;
    m_total_activations_buy = 0;
    m_total_activations_sell = 0;
    Print("🔄 [TS] Estatísticas resetadas.");
}

//+------------------------------------------------------------------+
//| Imprime estatísticas do Trailing Stop                            |
//+------------------------------------------------------------------+
void CTrailingStopManager::PrintStats(void)
{
    Print("═══════════════════════════════════════");
    Print("📈 [TS] ESTATÍSTICAS TRAILING STOP");
    Print("═══════════════════════════════════════");
    Print("   📈 Ativações BUY: ", m_total_activations_buy);
    Print("   📉 Ativações SELL: ", m_total_activations_sell);
    Print("   🔄 Total de Movimentos: ", m_total_moves);
    Print("   📊 Registros Ativos: ", ArraySize(m_trailing_records));
    Print("═══════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Verifica se mercado está aberto para trading                     |
//+------------------------------------------------------------------+
bool CTrailingStopManager::IsMarketOpenNow(string symbol)
{
    //--- Em modo de backtest, sempre permitir operações (tester simula mercado aberto)
    if(MQLInfoInteger(MQL_TESTER))
        return true;
    
    //--- Verificar se o símbolo está disponível para trade
    int trade_mode = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
    if(trade_mode == SYMBOL_TRADE_MODE_DISABLED || trade_mode == SYMBOL_TRADE_MODE_CLOSEONLY)
        return false;
    
    //--- Verificar se há cotações válidas (spread > 0 indica mercado ativo)
    double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    
    if(bid <= 0 || ask <= 0 || bid >= ask * 10) // Verificação básica de cotação válida
        return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Verifica se deve logar falha (deduplicação)                      |
//+------------------------------------------------------------------+
bool CTrailingStopManager::ShouldLogFailure(int record_idx, uint retcode, int error, double attempted_sl)
{
    if(record_idx < 0 || record_idx >= ArraySize(m_trailing_records))
        return true;
    
    // Acessar diretamente sem referência (MQL5 não suporta ref a struct)
    
    // Se é um erro diferente, logar
    if(m_trailing_records[record_idx].last_retcode != retcode || 
       m_trailing_records[record_idx].last_error != error)
        return true;
    
    // Se é o mesmo SL tentado, só logar a cada 60 segundos
    if(MathAbs(m_trailing_records[record_idx].last_attempt_sl - attempted_sl) < m_price_step)
    {
        datetime now = TimeCurrent();
        if(m_trailing_records[record_idx].last_failure_log_time > 0 && 
           (now - m_trailing_records[record_idx].last_failure_log_time) < 60)
            return false;  // Suprimir log duplicado
    }
    
    return true;
}

#endif // CTRAILINGSTOPMANAGER_MQH

//+------------------------------------------------------------------+
