//+------------------------------------------------------------------+
//|                                             SignalVertexFlow.mqh |
//|                                  Copyright 2025, ExpertTrader MQL5 |
//|                                         https://www.experttrader.net |
//+------------------------------------------------------------------+
#include "Inputs.mqh"

class CSignalVertexFlow
{
private:
    int            m_handle_fgm;
    int            m_handle_mfi;
    int            m_handle_rsi;
    int            m_handle_adx;
    
    //--- Buffers for reading - FGM EMAs (5 linhas) + dados
    double         m_buf_fgm_ema1[];   // Buffer 0: EMA mais rápida (14)
    double         m_buf_fgm_ema2[];   // Buffer 1: EMA (26)
    double         m_buf_fgm_ema3[];   // Buffer 2: EMA (50)
    double         m_buf_fgm_ema4[];   // Buffer 3: EMA (100)
    double         m_buf_fgm_ema5[];   // Buffer 4: EMA mais lenta (200)
    double         m_buf_fgm_phase[];  // Buffer 7: Fase do mercado
    
    //--- Buffers MFI, RSI, ADX
    double         m_buf_mfi_color[];
    double         m_buf_mfi_val[];
    double         m_buf_rsi_val[];
    double         m_buf_rsi_ma[];
    double         m_buf_adx[];
    
    //--- Controle de re-entrada
    datetime       m_last_entry_time;
    int            m_last_entry_direction; // 1=buy, -1=sell, 0=none
    datetime       m_last_bar_processed;   // Última barra processada (evita duplicatas)
    
public:
    CSignalVertexFlow();
    ~CSignalVertexFlow();
    
    bool           Init();
    int            GetSignal(); // 1=Buy, -1=Sell, 0=None
    
    //--- Getters for Chart Attachment
    int            GetHandleFGM() { return m_handle_fgm; }
    int            GetHandleMFI() { return m_handle_mfi; }
    int            GetHandleRSI() { return m_handle_rsi; }
    int            GetHandleADX() { return m_handle_adx; }
    
private:
    bool           UpdateBuffers();
    bool           IsPriceAboveAllEMAs(int shift, double price);
    bool           IsPriceBelowAllEMAs(int shift, double price);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSignalVertexFlow::CSignalVertexFlow() : 
    m_handle_fgm(INVALID_HANDLE),
    m_handle_mfi(INVALID_HANDLE),
    m_handle_rsi(INVALID_HANDLE),
    m_handle_adx(INVALID_HANDLE),
    m_last_entry_time(0),
    m_last_entry_direction(0),
    m_last_bar_processed(0)
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CSignalVertexFlow::~CSignalVertexFlow()
{
    if(m_handle_fgm != INVALID_HANDLE) IndicatorRelease(m_handle_fgm);
    if(m_handle_mfi != INVALID_HANDLE) IndicatorRelease(m_handle_mfi);
    if(m_handle_rsi != INVALID_HANDLE) IndicatorRelease(m_handle_rsi);
    if(m_handle_adx != INVALID_HANDLE) IndicatorRelease(m_handle_adx);
}

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CSignalVertexFlow::Init()
{
    //--- Initialize FGM Indicator (simplified - passing Period1 twice to account for hidden input shift)
    m_handle_fgm = iCustom(_Symbol, _Period, "Vertex_Flow_EA\\FGM_Indicator",
                           Inp_FGM_Period1, Inp_FGM_Period1, Inp_FGM_Period2, Inp_FGM_Period3, Inp_FGM_Period4, Inp_FGM_Period5
                           );
                           
    if(m_handle_fgm == INVALID_HANDLE) { Print("Failed to create FGM handle"); return false; }

    //--- Initialize Enhanced MFI
    m_handle_mfi = iCustom(_Symbol, _Period, "Vertex_Flow_EA\\EnhancedMFI",
                           Inp_MFI_Period,
                           13, // BullsBearsPeriod
                           5, // VolumePeriod
                           Inp_MFI_LatStart,
                           Inp_MFI_LatEnd,
                           Inp_MFI_VolType,
                           1.2 // VolumeFactor
                           );
                           
    if(m_handle_mfi == INVALID_HANDLE) { Print("Failed to create MFI handle"); return false; }

    //--- Initialize RSIOMA v2
    // Último parâmetro (ShowLevels) EM TRUE para exibir os níveis 70/30 no gráfico
    // Isso permite visualizar claramente o filtro de nível (acima/abaixo de 50) usado pelo EA.
    m_handle_rsi = iCustom(_Symbol, _Period, "Vertex_Flow_EA\\RSIOMA_v2HHLSX_MT5",
                           Inp_RSI_Period,
                           Inp_RSI_MAPeriod,
                           Inp_RSI_MAMethod,
                           70.0, 30.0, true // Levels
                           );
                           
    if(m_handle_rsi == INVALID_HANDLE) { Print("Failed to create RSIOMA handle"); return false; }

    //--- Initialize ADXW Cloud
    // Assuming filename is ADXW_Cloud.mq5 based on "ADXW Cloud 1.0" title
    // Parameters from image: Period, ADXR Level, BullColor, BearColor, Transparency
    m_handle_adx = iCustom(_Symbol, _Period, "Vertex_Flow_EA\\ADXW_Cloud",
                           Inp_ADX_Period,
                           Inp_ADX_MinTrend, // Using MinTrend as the ADXR Level input for the indicator
                           clrLightGreen,
                           clrHotPink,
                           80
                           );
                           
    if(m_handle_adx == INVALID_HANDLE) { Print("Failed to create ADX handle"); return false; }

    return true;
}

//+------------------------------------------------------------------+
//| Update Buffers                                                   |
//+------------------------------------------------------------------+
bool CSignalVertexFlow::UpdateBuffers()
{
    int count = 3;

    // Configurar arrays como séries
    ArraySetAsSeries(m_buf_fgm_ema1, true);
    ArraySetAsSeries(m_buf_fgm_ema2, true);
    ArraySetAsSeries(m_buf_fgm_ema3, true);
    ArraySetAsSeries(m_buf_fgm_ema4, true);
    ArraySetAsSeries(m_buf_fgm_ema5, true);
    ArraySetAsSeries(m_buf_fgm_phase, true);
    ArraySetAsSeries(m_buf_mfi_color, true);
    ArraySetAsSeries(m_buf_mfi_val, true);
    ArraySetAsSeries(m_buf_rsi_val, true);
    ArraySetAsSeries(m_buf_rsi_ma, true);
    ArraySetAsSeries(m_buf_adx, true);

    // FGM: Buffers 0-4 = EMAs, Buffer 7 = Phase
    if(CopyBuffer(m_handle_fgm, 0, 0, count, m_buf_fgm_ema1) < count) return false;
    if(CopyBuffer(m_handle_fgm, 1, 0, count, m_buf_fgm_ema2) < count) return false;
    if(CopyBuffer(m_handle_fgm, 2, 0, count, m_buf_fgm_ema3) < count) return false;
    if(CopyBuffer(m_handle_fgm, 3, 0, count, m_buf_fgm_ema4) < count) return false;
    if(CopyBuffer(m_handle_fgm, 4, 0, count, m_buf_fgm_ema5) < count) return false;
    if(CopyBuffer(m_handle_fgm, 7, 0, count, m_buf_fgm_phase) < count) return false;
    
    // MFI
    if(CopyBuffer(m_handle_mfi, 1, 0, count, m_buf_mfi_color) < count) return false;
    if(CopyBuffer(m_handle_mfi, 0, 0, count, m_buf_mfi_val) < count) return false;
    
    // RSI
    if(CopyBuffer(m_handle_rsi, 0, 0, count, m_buf_rsi_val) < count) return false;
    if(CopyBuffer(m_handle_rsi, 1, 0, count, m_buf_rsi_ma) < count) return false;

    // ADX
    if(CopyBuffer(m_handle_adx, 2, 0, count, m_buf_adx) < count) return false;

    return true;
}

//+------------------------------------------------------------------+
//| Verifica se o preço está ACIMA de todas as 5 EMAs do FGM        |
//+------------------------------------------------------------------+
bool CSignalVertexFlow::IsPriceAboveAllEMAs(int shift, double price)
{
    return (price > m_buf_fgm_ema1[shift] &&
            price > m_buf_fgm_ema2[shift] &&
            price > m_buf_fgm_ema3[shift] &&
            price > m_buf_fgm_ema4[shift] &&
            price > m_buf_fgm_ema5[shift]);
}

//+------------------------------------------------------------------+
//| Verifica se o preço está ABAIXO de todas as 5 EMAs do FGM       |
//+------------------------------------------------------------------+
bool CSignalVertexFlow::IsPriceBelowAllEMAs(int shift, double price)
{
    return (price < m_buf_fgm_ema1[shift] &&
            price < m_buf_fgm_ema2[shift] &&
            price < m_buf_fgm_ema3[shift] &&
            price < m_buf_fgm_ema4[shift] &&
            price < m_buf_fgm_ema5[shift]);
}

//+------------------------------------------------------------------+
//| Get Signal                                                       |
//+------------------------------------------------------------------+
int CSignalVertexFlow::GetSignal()
{
    if(!UpdateBuffers())
        return 0;

    //==========================================================================
    // CONTROLE CRÍTICO: Só processar UMA VEZ por barra FECHADA
    // Usamos a barra shift=1 (última fechada), então verificamos se já processamos
    // a barra que AGORA está em shift=1
    //==========================================================================
    datetime closed_bar_time = iTime(_Symbol, _Period, 1);  // Tempo da barra FECHADA
    
    if(m_last_bar_processed == closed_bar_time)
        return 0;  // Já processamos esta barra
    
    m_last_bar_processed = closed_bar_time;

    // Analisamos a última barra FECHADA (shift=1)
    int shift = 1;
    int prev_shift = 2;
    
    //==========================================================================
    // NOVA ESTRATÉGIA SIMPLIFICADA E CORRETA:
    //
    // INDICADOR PRINCIPAL: FGM (5 EMAs)
    // - BUY:  Candle FECHA ACIMA de TODAS as 5 EMAs
    // - SELL: Candle FECHA ABAIXO de TODAS as 5 EMAs
    //
    // FILTROS DE CONFIRMAÇÃO (todos devem concordar):
    // 1. ADX > 20 (existe tendência, não está lateralizado)
    // 2. MFI: Verde(0) para BUY, Vermelho(1) para SELL
    // 3. RSI > MA para BUY, RSI < MA para SELL
    //
    // TRIGGER: Mudança de estado em qualquer filtro
    //==========================================================================
    
    //--- Obter preço de fechamento da barra
    double close_price = iClose(_Symbol, _Period, shift);
    double close_prev  = iClose(_Symbol, _Period, prev_shift);
    
    //--- Leitura dos indicadores
    int fgm_phase = (int)m_buf_fgm_phase[shift];
    int fgm_phase_prev = (int)m_buf_fgm_phase[prev_shift];
    
    int mfi_color = (int)m_buf_mfi_color[shift];
    int mfi_color_prev = (int)m_buf_mfi_color[prev_shift];
    double mfi_val = m_buf_mfi_val[shift];
    
    double rsi_val = m_buf_rsi_val[shift];
    double rsi_ma = m_buf_rsi_ma[shift];
    double rsi_prev = m_buf_rsi_val[prev_shift];
    double rsi_ma_prev = m_buf_rsi_ma[prev_shift];
    
    double adx_curr = m_buf_adx[shift];
    
    //==========================================================================
    // CONDIÇÃO PRINCIPAL DO FGM: Preço vs EMAs
    //==========================================================================
    bool price_above_all_emas = IsPriceAboveAllEMAs(shift, close_price);
    bool price_below_all_emas = IsPriceBelowAllEMAs(shift, close_price);
    bool was_above_all_emas   = IsPriceAboveAllEMAs(prev_shift, close_prev);
    bool was_below_all_emas   = IsPriceBelowAllEMAs(prev_shift, close_prev);
    
    //--- DETECÇÃO DE BREAKOUT: Preço cruzou todas as EMAs nesta barra
    bool breakout_up   = (price_above_all_emas && !was_above_all_emas);
    bool breakout_down = (price_below_all_emas && !was_below_all_emas);
    
    //==========================================================================
    // FILTROS DE CONFIRMAÇÃO
    //==========================================================================
    
    //--- ADX: Deve indicar tendência (não lateralizado)
    bool adx_trending = (adx_curr >= Inp_ADX_MinTrend);
    
    //--- MFI: Verde=compra, Vermelho=venda, Amarelo=neutro
    bool mfi_green = (mfi_color == 0);
    bool mfi_red   = (mfi_color == 1);
    bool mfi_neutral = (mfi_color == 2);
    
    //--- RSI: Acima da MA = alta, Abaixo da MA = baixa
    bool rsi_bullish = (rsi_val > rsi_ma);
    bool rsi_bearish = (rsi_val < rsi_ma);
    
    //--- TRIGGERS: Mudanças de estado
    bool mfi_turned_green = (mfi_color == 0 && mfi_color_prev != 0);
    bool mfi_turned_red   = (mfi_color == 1 && mfi_color_prev != 1);
    
    //--- FGM Phase mudou para bullish/bearish (NOVO TRIGGER CRÍTICO)
    bool phase_turned_bull = (fgm_phase >= 1 && fgm_phase_prev < 1);  // Entrou em +1 ou +2
    bool phase_turned_bear = (fgm_phase <= -1 && fgm_phase_prev > -1); // Entrou em -1 ou -2
    
    // RSI: Não exige cruzamento, apenas posição relativa (menos restritivo)
    // Linha vermelha (RSI) acima da azul (MA) = compra, abaixo = venda
    
    //--- Evitar sobrecompra/sobrevenda extrema
    bool mfi_extreme_high = (mfi_val > 80.0);
    bool mfi_extreme_low  = (mfi_val < 20.0);
    bool rsi_extreme_high = (rsi_val > 70.0);
    bool rsi_extreme_low  = (rsi_val < 30.0);
    
    //==========================================================================
    // DEBUG LOG
    //==========================================================================
    PrintFormat("[DEBUG] %s | Close=%.2f | PriceAboveEMAs=%s PriceBelowEMAs=%s | FGM_Phase=%d | MFI=%d(%.1f) RSI=%.1f/%.1f(%s) | ADX=%.1f(%s)",
                TimeToString(iTime(_Symbol, _Period, shift), TIME_DATE|TIME_MINUTES),
                close_price,
                price_above_all_emas ? "YES" : "NO",
                price_below_all_emas ? "YES" : "NO",
                fgm_phase,
                mfi_color, mfi_val,
                rsi_val, rsi_ma, rsi_bullish ? "BULL" : "BEAR",
                adx_curr, adx_trending ? "TREND" : "LATERAL");
    
    //==========================================================================
    // LÓGICA DE BUY
    //==========================================================================
    // Condições obrigatórias:
    // 1. Preço fechou ACIMA de TODAS as 5 EMAs do FGM
    // 2. FGM Phase deve ser POSITIVA (+1 Weak Bull ou +2 Strong Bull)
    // 3. ADX indica tendência (não lateralizado)
    // 4. MFI verde (volume comprando)
    // 5. RSI acima da sua MA (momento altista)
    // 6. Não está em sobrecompra extrema
    // 7. Houve um trigger recente (breakout ou MFI virou verde)
    
    bool buy_price_ok   = price_above_all_emas;
    bool buy_phase_ok   = (fgm_phase >= 1);  // Phase +1 (Weak Bull) ou +2 (Strong Bull)
    bool buy_fgm_ok     = buy_price_ok && buy_phase_ok;
    bool buy_adx_ok     = adx_trending;
    bool buy_mfi_ok     = mfi_green;
    bool buy_rsi_ok     = rsi_bullish;  // Linha vermelha ACIMA da azul
    bool buy_not_extreme = (!mfi_extreme_high && !rsi_extreme_high);
    bool buy_trigger    = (breakout_up || mfi_turned_green || phase_turned_bull);  // Breakout, MFI ou Phase mudou
    
    // Evitar re-entrada na mesma direção muito rápido
    datetime current_bar_time = iTime(_Symbol, _Period, 0);
    int bars_since_entry = (m_last_entry_time > 0) ? 
                           (int)((current_bar_time - m_last_entry_time) / PeriodSeconds(_Period)) : 999;
    bool can_buy = (m_last_entry_direction != 1 || bars_since_entry > 5);
    
    if(buy_fgm_ok && buy_adx_ok && buy_mfi_ok && buy_rsi_ok && buy_not_extreme && buy_trigger && can_buy)
    {
        PrintFormat("[SIGNAL BUY] %s | Close=%.2f | Price=%s Phase=%d(%s) ADX=%s MFI=%s RSI=%s Trigger=%s",
                    TimeToString(iTime(_Symbol, _Period, shift), TIME_DATE|TIME_MINUTES),
                    close_price,
                    buy_price_ok ? "OK" : "NO",
                    fgm_phase, buy_phase_ok ? "BULL" : "NEUTRAL/BEAR",
                    buy_adx_ok ? "OK" : "NO",
                    buy_mfi_ok ? "OK" : "NO",
                    buy_rsi_ok ? "OK" : "NO",
                    breakout_up ? "BREAKOUT" : (mfi_turned_green ? "MFI" : (phase_turned_bull ? "PHASE" : "UNKNOWN")));
        
        PrintFormat("   EMAs: %.2f / %.2f / %.2f / %.2f / %.2f",
                    m_buf_fgm_ema1[shift], m_buf_fgm_ema2[shift], m_buf_fgm_ema3[shift],
                    m_buf_fgm_ema4[shift], m_buf_fgm_ema5[shift]);
        
        m_last_entry_time = current_bar_time;
        m_last_entry_direction = 1;
        return 1;
    }
    
    //==========================================================================
    // LÓGICA DE SELL
    //==========================================================================
    // Condições obrigatórias:
    // 1. Preço fechou ABAIXO de TODAS as 5 EMAs do FGM
    // 2. FGM Phase deve ser NEGATIVA (-1 Weak Bear ou -2 Strong Bear)
    // 3. ADX indica tendência (não lateralizado)
    // 4. MFI vermelho (volume vendendo)
    // 5. RSI abaixo da sua MA (momento baixista)
    // 6. Não está em sobrevenda extrema
    // 7. Houve um trigger recente (breakdown ou MFI virou vermelho)
    
    bool sell_price_ok   = price_below_all_emas;
    bool sell_phase_ok   = (fgm_phase <= -1);  // Phase -1 (Weak Bear) ou -2 (Strong Bear)
    bool sell_fgm_ok     = sell_price_ok && sell_phase_ok;
    bool sell_adx_ok     = adx_trending;
    bool sell_mfi_ok     = mfi_red;
    bool sell_rsi_ok     = rsi_bearish;  // Linha vermelha ABAIXO da azul
    bool sell_not_extreme = (!mfi_extreme_low && !rsi_extreme_low);
    bool sell_trigger    = (breakout_down || mfi_turned_red || phase_turned_bear);  // Breakdown, MFI ou Phase mudou
    
    bool can_sell = (m_last_entry_direction != -1 || bars_since_entry > 5);
    
    if(sell_fgm_ok && sell_adx_ok && sell_mfi_ok && sell_rsi_ok && sell_not_extreme && sell_trigger && can_sell)
    {
        PrintFormat("[SIGNAL SELL] %s | Close=%.2f | Price=%s Phase=%d(%s) ADX=%s MFI=%s RSI=%s Trigger=%s",
                    TimeToString(iTime(_Symbol, _Period, shift), TIME_DATE|TIME_MINUTES),
                    close_price,
                    sell_price_ok ? "OK" : "NO",
                    fgm_phase, sell_phase_ok ? "BEAR" : "NEUTRAL/BULL",
                    sell_adx_ok ? "OK" : "NO",
                    sell_mfi_ok ? "OK" : "NO",
                    sell_rsi_ok ? "OK" : "NO",
                    breakout_down ? "BREAKOUT" : (mfi_turned_red ? "MFI" : (phase_turned_bear ? "PHASE" : "UNKNOWN")));
        
        PrintFormat("   EMAs: %.2f / %.2f / %.2f / %.2f / %.2f",
                    m_buf_fgm_ema1[shift], m_buf_fgm_ema2[shift], m_buf_fgm_ema3[shift],
                    m_buf_fgm_ema4[shift], m_buf_fgm_ema5[shift]);
        
        m_last_entry_time = current_bar_time;
        m_last_entry_direction = -1;
        return -1;
    }
    
    return 0;
}
