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
    // ADX REMOVIDO
    
    //--- Buffers for reading - FGM EMAs (5 lines) + data
    double         m_buf_fgm_ema1[];   // Buffer 0: EMA 14
    double         m_buf_fgm_ema2[];   // Buffer 1: EMA 26
    double         m_buf_fgm_ema3[];   // Buffer 2: EMA 50
    double         m_buf_fgm_ema4[];   // Buffer 3: EMA 100
    double         m_buf_fgm_ema5[];   // Buffer 4: EMA 200
    double         m_buf_fgm_phase[];  // Buffer 7: Phase
    
    //--- Buffers MFI, RSI
    double         m_buf_mfi_color[];
    double         m_buf_mfi_val[];
    double         m_buf_rsi_val[];
    double         m_buf_rsi_ma[];
    // ADX buffers REMOVIDOS
    
    //--- Re-entry control
    datetime       m_last_entry_time;
    int            m_last_entry_direction; // 1=buy, -1=sell, 0=none
    datetime       m_last_bar_processed;   // Last processed bar
    
public:
    CSignalVertexFlow();
    ~CSignalVertexFlow();
    
    bool           Init();
    int            GetSignal(); // 1=Buy, -1=Sell, 0=None
    
    //--- Getters for Chart Attachment
    int            GetHandleFGM() { return m_handle_fgm; }
    int            GetHandleMFI() { return m_handle_mfi; }
    int            GetHandleRSI() { return m_handle_rsi; }
    // GetHandleADX() REMOVIDO
    
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
    // ADX release REMOVIDO
}

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CSignalVertexFlow::Init()
{
    Print("Vertex Flow Signal Init - FGM + RSI + MFI (ADX REMOVIDO)");
    
    //--- Initialize FGM Indicator
    m_handle_fgm = iCustom(_Symbol, _Period, "Vertex_Flow_EA\\FGM_Indicator",
                           Inp_FGM_Period1,
                           Inp_FGM_Period2,
                           Inp_FGM_Period3,
                           Inp_FGM_Period4,
                           Inp_FGM_Period5,
                           Inp_FGM_Price,
                           Inp_FGM_Cross,
                           1,
                           1,
                           2,
                           Inp_FGM_Mode,
                           Inp_FGM_MinStr
                           );
                           
    if(m_handle_fgm == INVALID_HANDLE) { Print("Failed to create FGM handle"); return false; }

    //--- Initialize Enhanced MFI
    m_handle_mfi = iCustom(_Symbol, _Period, "Vertex_Flow_EA\\EnhancedMFI",
                           Inp_MFI_Period,
                           13,
                           5,
                           Inp_MFI_LatStart,
                           Inp_MFI_LatEnd,
                           Inp_MFI_VolType,
                           1.2
                           );
                           
    if(m_handle_mfi == INVALID_HANDLE) { Print("Failed to create MFI handle"); return false; }

    //--- Initialize RSIOMA v2
    m_handle_rsi = iCustom(_Symbol, _Period, "Vertex_Flow_EA\\RSIOMA_v2HHLSX_MT5",
                           Inp_RSI_Period,
                           Inp_RSI_MAPeriod,
                           Inp_RSI_MAMethod,
                           70.0, 30.0, true
                           );
                           
    if(m_handle_rsi == INVALID_HANDLE) { Print("Failed to create RSIOMA handle"); return false; }

    // ADX REMOVIDO - não mais inicializado

    return true;
}

//+------------------------------------------------------------------+
//| Update Buffers                                                   |
//+------------------------------------------------------------------+
bool CSignalVertexFlow::UpdateBuffers()
{
    int count = 3;

    // Set arrays as series
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
    // ADX arrays REMOVIDOS

    // FGM
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

    // ADX CopyBuffer REMOVIDO

    return true;
}

//+------------------------------------------------------------------+
//| Check if price is above all EMAs                                 |
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
//| Check if price is below all EMAs                                 |
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

    datetime closed_bar_time = iTime(_Symbol, _Period, 1);
    
    if(m_last_bar_processed == closed_bar_time)
        return 0;
    
    m_last_bar_processed = closed_bar_time;

    int shift = 1;
    double close_price = iClose(_Symbol, _Period, shift);

    // Read Indicators on closed bar (shift=1)
    int    mfi_color    = (int)m_buf_mfi_color[shift];
    double mfi_val      = m_buf_mfi_val[shift];
    // ADX leitura REMOVIDA

    // FGM Logic (principal gerador de direção)
    bool price_above_all_emas = IsPriceAboveAllEMAs(shift, close_price);
    bool price_below_all_emas = IsPriceBelowAllEMAs(shift, close_price);

    bool emas_fanned_bull = (m_buf_fgm_ema1[shift] > m_buf_fgm_ema2[shift] &&
                             m_buf_fgm_ema2[shift] > m_buf_fgm_ema3[shift] &&
                             m_buf_fgm_ema3[shift] > m_buf_fgm_ema5[shift]);

    bool emas_fanned_bear = (m_buf_fgm_ema1[shift] < m_buf_fgm_ema2[shift] &&
                             m_buf_fgm_ema2[shift] < m_buf_fgm_ema3[shift] &&
                             m_buf_fgm_ema3[shift] < m_buf_fgm_ema5[shift]);

    // ADX Logic REMOVIDA

    // MFI Logic - Baseado na COR do indicador (definida por Bulls/Bears Power)
    // Color 0 = Green = buying pressure (compra)
    // Color 1 = Red = selling pressure (venda)
    // Color 2 = Yellow = lateral (neutro)
    bool mfi_green = (mfi_color == 0); // fluxo de compra
    bool mfi_red   = (mfi_color == 1); // fluxo de venda
    bool mfi_neutral = (mfi_color == 2); // lateral

    // RSI Logic (linha vermelha = valor, linha azul = média)
    double rsi_val = m_buf_rsi_val[shift];
    double rsi_ma  = m_buf_rsi_ma[shift];

    bool rsi_bullish        = (rsi_val > rsi_ma); // vermelha acima da azul
    bool rsi_bearish        = (rsi_val < rsi_ma); // vermelha abaixo da azul
    bool rsi_not_overbought = (rsi_val < 75.0);
    bool rsi_not_oversold   = (rsi_val > 25.0);

    // Debug principal - SEM ADX
    PrintFormat("[DEBUG] %s | Close=%.2f | AboveEMAs=%s BelowEMAs=%s | FanBull=%s FanBear=%s | MFI=%d(%.1f)[G=%s R=%s] RSI=%.1f/%.1f(%s)",
                TimeToString(iTime(_Symbol, _Period, shift), TIME_DATE|TIME_MINUTES),
                close_price,
                price_above_all_emas ? "Y" : "N",
                price_below_all_emas ? "Y" : "N",
                emas_fanned_bull ? "Y" : "N",
                emas_fanned_bear ? "Y" : "N",
                mfi_color, mfi_val,
                mfi_green ? "Y" : "N",
                mfi_red ? "Y" : "N",
                rsi_val, rsi_ma, rsi_bullish ? "BULL" : "BEAR");

    // Controle de reentrada
    datetime current_bar_time = iTime(_Symbol, _Period, 0);
    int bars_since_entry = (m_last_entry_time > 0) ?
                           (int)((current_bar_time - m_last_entry_time) / PeriodSeconds(_Period)) : 999;

    bool can_buy  = (m_last_entry_direction != 1 || bars_since_entry > 10);
    bool can_sell = (m_last_entry_direction != -1 || bars_since_entry > 10);

    //--------------------------------------------------------------
    // 1) FGM gera o sinal bruto (direção principal)
    //    Preço além de todas EMAs + Fan alinhado
    //--------------------------------------------------------------
    int raw_signal = 0; // 1=BUY, -1=SELL, 0=NENHUM

    // Sinal forte: preço além de todas EMAs + fan alinhado
    if(price_above_all_emas && emas_fanned_bull)
        raw_signal = 1;
    else if(price_below_all_emas && emas_fanned_bear)
        raw_signal = -1;

    if(raw_signal == 0)
        return 0; // sem sinal FGM, não há operação

    //--------------------------------------------------------------
    // 2) RSI valida sequencialmente (FLEXIBILIZADO)
    //    BUY: vermelha acima da azul OU RSI em zona bullish (>50) E não sobrecomprado
    //    SELL: vermelha abaixo da azul OU RSI em zona bearish (<50) E não sobrevendido
    //--------------------------------------------------------------
    if(raw_signal == 1)
    {
        // Para BUY: RSI bullish OU RSI acima de 50 (tendência de alta)
        bool rsi_ok_buy = rsi_bullish || (rsi_val > 50.0);
        if(!rsi_ok_buy)
            return 0; // RSI não favorece compra
        if(!rsi_not_overbought)
            return 0; // RSI sobrecomprado, cancela BUY
    }
    else if(raw_signal == -1)
    {
        // Para SELL: RSI bearish OU RSI abaixo de 50 (tendência de baixa)
        bool rsi_ok_sell = rsi_bearish || (rsi_val < 50.0);
        if(!rsi_ok_sell)
            return 0; // RSI não favorece venda
        if(!rsi_not_oversold)
            return 0; // RSI sobrevendido, cancela SELL
    }

    //--------------------------------------------------------------
    // 3) ADX REMOVIDO - Não validar mais ADX
    //    FGM + RSI + MFI são suficientes para gerar sinal
    //--------------------------------------------------------------

    //--------------------------------------------------------------
    // 4) MFI valida fluxo sequencialmente
    //    BUY: verde e não extremamente sobrecomprado
    //    SELL: vermelho e não extremamente sobrevendido
    //--------------------------------------------------------------
    if(raw_signal == 1)
    {
        if(!mfi_green)
            return 0; // MFI não está verde, fluxo não favorece compra

        // Exemplo de checagem de "sobrecomprado" via valor MFI (zona alta)
        if(mfi_val > Inp_MFI_LatEnd)
        {
            // MFI muito alto (acima da zona lateral superior), opcionalmente filtrar
            // Neste exemplo, mantemos apenas como proteção leve, então não cancelamos sempre
            // Poderia ser: if(mfi_val > 80.0) return 0;
        }
    }
    else if(raw_signal == -1)
    {
        if(!mfi_red)
            return 0; // MFI não está vermelho, fluxo não favorece venda

        if(mfi_val < Inp_MFI_LatStart)
        {
            // MFI muito baixo (abaixo da zona lateral inferior), mesma ideia do BUY
            // Poderia ser endurecido se desejar.
        }
    }

    //--------------------------------------------------------------
    // 5) Controle de reentrada / cooldown
    //--------------------------------------------------------------
    if(raw_signal == 1 && !can_buy)
        return 0;
    if(raw_signal == -1 && !can_sell)
        return 0;

    //--------------------------------------------------------------
    // 6) Se chegou aqui, o sinal sequencial (FGM -> RSI -> ADX -> MFI)
    //    foi validado. Dispara BUY ou SELL.
    //--------------------------------------------------------------
    if(raw_signal == 1)
    {
        PrintFormat("[SIGNAL BUY] %s | Close=%.2f | FGM=ABOVE_ALL+FAN RSI=%.1f/%.1f(BULL) | MFI=%d(%.1f, GREEN)",
                    TimeToString(iTime(_Symbol, _Period, shift), TIME_DATE|TIME_MINUTES),
                    close_price,
                    rsi_val, rsi_ma,
                    mfi_color, mfi_val);

        PrintFormat("   EMAs: %.2f / %.2f / %.2f / %.2f / %.2f",
                    m_buf_fgm_ema1[shift], m_buf_fgm_ema2[shift], m_buf_fgm_ema3[shift],
                    m_buf_fgm_ema4[shift], m_buf_fgm_ema5[shift]);

        m_last_entry_time      = current_bar_time;
        m_last_entry_direction = 1;
        return 1;
    }

    if(raw_signal == -1)
    {
        PrintFormat("[SIGNAL SELL] %s | Close=%.2f | FGM=BELOW_ALL+FAN RSI=%.1f/%.1f(BEAR) | MFI=%d(%.1f, RED)",
                    TimeToString(iTime(_Symbol, _Period, shift), TIME_DATE|TIME_MINUTES),
                    close_price,
                    rsi_val, rsi_ma,
                    mfi_color, mfi_val);

        PrintFormat("   EMAs: %.2f / %.2f / %.2f / %.2f / %.2f",
                    m_buf_fgm_ema1[shift], m_buf_fgm_ema2[shift], m_buf_fgm_ema3[shift],
                    m_buf_fgm_ema4[shift], m_buf_fgm_ema5[shift]);

        m_last_entry_time      = current_bar_time;
        m_last_entry_direction = -1;
        return -1;
    }

    return 0;
}
