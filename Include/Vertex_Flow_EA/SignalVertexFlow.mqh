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
    int            m_handle_atr;  // ATR para filtro de volatilidade
    
    //--- Buffers for reading - FGM EMAs (5 lines) + data
    double         m_buf_fgm_ema1[];   // Buffer 0: EMA 14
    double         m_buf_fgm_ema2[];   // Buffer 1: EMA 26
    double         m_buf_fgm_ema3[];   // Buffer 2: EMA 50
    double         m_buf_fgm_ema4[];   // Buffer 3: EMA 100
    double         m_buf_fgm_ema5[];   // Buffer 4: EMA 200
    double         m_buf_fgm_phase[];  // Buffer 7: Phase
    
    //--- Buffers MFI, RSI, ATR
    double         m_buf_mfi_color[];
    double         m_buf_mfi_val[];
    double         m_buf_rsi_val[];
    double         m_buf_rsi_ma[];
    double         m_buf_atr[];        // ATR buffer
    
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
    m_handle_atr(INVALID_HANDLE),
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
    if(m_handle_atr != INVALID_HANDLE) IndicatorRelease(m_handle_atr);
}

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CSignalVertexFlow::Init()
{
    Print("Vertex Flow Signal Init - FGM + RSI + MFI + ATR (Anti-Falso-Sinal v2)");
    
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

    //--- Initialize ATR para filtro de volatilidade
    m_handle_atr = iATR(_Symbol, _Period, 14);
    if(m_handle_atr == INVALID_HANDLE) { Print("Failed to create ATR handle"); return false; }

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
    ArraySetAsSeries(m_buf_atr, true);

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

    // ATR
    if(CopyBuffer(m_handle_atr, 0, 0, count, m_buf_atr) < count) return false;

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
    int    mfi_color = (int)m_buf_mfi_color[shift];
    double mfi_val   = m_buf_mfi_val[shift];
    double atr_val   = m_buf_atr[shift];

    // FGM Logic (principal gerador de direção)
    bool price_above_all_emas = IsPriceAboveAllEMAs(shift, close_price);
    bool price_below_all_emas = IsPriceBelowAllEMAs(shift, close_price);

    bool emas_fanned_bull = (m_buf_fgm_ema1[shift] > m_buf_fgm_ema2[shift] &&
                             m_buf_fgm_ema2[shift] > m_buf_fgm_ema3[shift] &&
                             m_buf_fgm_ema3[shift] > m_buf_fgm_ema5[shift]);

    bool emas_fanned_bear = (m_buf_fgm_ema1[shift] < m_buf_fgm_ema2[shift] &&
                             m_buf_fgm_ema2[shift] < m_buf_fgm_ema3[shift] &&
                             m_buf_fgm_ema3[shift] < m_buf_fgm_ema5[shift]);

    //==========================================================
    // NOVOS FILTROS ANTI-ENTRADA-ATRASADA E ANTI-FALSO-SINAL
    //==========================================================
    
    // 1) SPREAD ENTRE EMAs - Se EMAs muito próximas = mercado lateral
    double ema_spread = MathAbs(m_buf_fgm_ema1[shift] - m_buf_fgm_ema5[shift]);
    double min_ema_spread = atr_val * 1.5;  // Mínimo 1.5x ATR de spread
    bool emas_well_spread = (ema_spread >= min_ema_spread);
    
    // 2) DISTÂNCIA DO PREÇO À EMA RÁPIDA - Se muito longe = entrada atrasada
    double dist_to_ema1 = MathAbs(close_price - m_buf_fgm_ema1[shift]);
    double max_dist_to_ema = atr_val * 2.0;  // Máximo 2x ATR de distância
    bool price_not_too_far = (dist_to_ema1 <= max_dist_to_ema);
    
    // 3) EMA1 deve estar se movendo na direção correta (momentum)
    double ema1_change = m_buf_fgm_ema1[shift] - m_buf_fgm_ema1[shift+1 < 3 ? shift : 0];
    bool ema1_rising  = (ema1_change > 0);
    bool ema1_falling = (ema1_change < 0);

    // MFI Logic - Baseado na COR do indicador
    bool mfi_green   = (mfi_color == 0);
    bool mfi_red     = (mfi_color == 1);
    bool mfi_neutral = (mfi_color == 2);

    // RSI Logic
    double rsi_val = m_buf_rsi_val[shift];
    double rsi_ma  = m_buf_rsi_ma[shift];

    bool rsi_bullish        = (rsi_val > rsi_ma);
    bool rsi_bearish        = (rsi_val < rsi_ma);
    
    // RSI ZONAS EXTREMAS - Não entrar em reversão
    bool rsi_not_overbought = (rsi_val < 70.0);  // Mais rigoroso (era 75)
    bool rsi_not_oversold   = (rsi_val > 30.0);  // Mais rigoroso (era 25)
    
    // RSI zona saudável para entrada
    bool rsi_healthy_buy  = (rsi_val > 45.0 && rsi_val < 70.0);  // Zona saudável para BUY
    bool rsi_healthy_sell = (rsi_val < 55.0 && rsi_val > 30.0);  // Zona saudável para SELL

    // Debug principal
    PrintFormat("[DEBUG] %s | Close=%.0f | AboveEMAs=%s BelowEMAs=%s | FanBull=%s FanBear=%s | EMAspread=%.0f(min%.0f) | DistEMA1=%.0f(max%.0f) | MFI=%d[G=%s R=%s] RSI=%.1f(%s) ATR=%.0f",
                TimeToString(iTime(_Symbol, _Period, shift), TIME_DATE|TIME_MINUTES),
                close_price,
                price_above_all_emas ? "Y" : "N",
                price_below_all_emas ? "Y" : "N",
                emas_fanned_bull ? "Y" : "N",
                emas_fanned_bear ? "Y" : "N",
                ema_spread, min_ema_spread,
                dist_to_ema1, max_dist_to_ema,
                mfi_color,
                mfi_green ? "Y" : "N",
                mfi_red ? "Y" : "N",
                rsi_val, rsi_bullish ? "BULL" : "BEAR",
                atr_val);

    // Controle de reentrada
    datetime current_bar_time = iTime(_Symbol, _Period, 0);
    int bars_since_entry = (m_last_entry_time > 0) ?
                           (int)((current_bar_time - m_last_entry_time) / PeriodSeconds(_Period)) : 999;

    bool can_buy  = (m_last_entry_direction != 1 || bars_since_entry > 10);
    bool can_sell = (m_last_entry_direction != -1 || bars_since_entry > 10);

    //--------------------------------------------------------------
    // 1) FGM gera o sinal bruto (direção principal)
    //--------------------------------------------------------------
    int raw_signal = 0;

    if(price_above_all_emas && emas_fanned_bull)
        raw_signal = 1;
    else if(price_below_all_emas && emas_fanned_bear)
        raw_signal = -1;

    if(raw_signal == 0)
        return 0;

    //--------------------------------------------------------------
    // 2) FILTRO ANTI-LATERALIZAÇÃO - EMAs devem estar bem separadas
    //--------------------------------------------------------------
    if(!emas_well_spread)
    {
        PrintFormat("[BLOCKED] EMAs muito próximas (spread=%.0f < min=%.0f) - Mercado lateral", ema_spread, min_ema_spread);
        return 0;
    }

    //--------------------------------------------------------------
    // 3) FILTRO ANTI-ENTRADA-ATRASADA - Preço não pode estar muito longe da EMA1
    //--------------------------------------------------------------
    if(!price_not_too_far)
    {
        PrintFormat("[BLOCKED] Preço muito longe da EMA1 (dist=%.0f > max=%.0f) - Entrada atrasada", dist_to_ema1, max_dist_to_ema);
        return 0;
    }

    //--------------------------------------------------------------
    // 4) FILTRO DE MOMENTUM - EMA1 deve estar se movendo na direção do trade
    //--------------------------------------------------------------
    if(raw_signal == 1 && !ema1_rising)
    {
        PrintFormat("[BLOCKED] EMA1 não está subindo - Sem momentum de alta");
        return 0;
    }
    if(raw_signal == -1 && !ema1_falling)
    {
        PrintFormat("[BLOCKED] EMA1 não está caindo - Sem momentum de baixa");
        return 0;
    }

    //--------------------------------------------------------------
    // 5) RSI valida - MAIS RIGOROSO
    //--------------------------------------------------------------
    if(raw_signal == 1)
    {
        if(!rsi_healthy_buy)
        {
            PrintFormat("[BLOCKED] RSI=%.1f fora da zona saudável para BUY (45-70)", rsi_val);
            return 0;
        }
    }
    else if(raw_signal == -1)
    {
        if(!rsi_healthy_sell)
        {
            PrintFormat("[BLOCKED] RSI=%.1f fora da zona saudável para SELL (30-55)", rsi_val);
            return 0;
        }
    }

    //--------------------------------------------------------------
    // 6) MFI valida fluxo
    //--------------------------------------------------------------
    if(raw_signal == 1)
    {
        if(!mfi_green)
        {
            PrintFormat("[BLOCKED] MFI não está verde - Sem fluxo comprador");
            return 0;
        }
    }
    else if(raw_signal == -1)
    {
        if(!mfi_red)
        {
            PrintFormat("[BLOCKED] MFI não está vermelho - Sem fluxo vendedor");
            return 0;
        }
    }

    //--------------------------------------------------------------
    // 7) Controle de reentrada / cooldown
    //--------------------------------------------------------------
    if(raw_signal == 1 && !can_buy)
        return 0;
    if(raw_signal == -1 && !can_sell)
        return 0;

    //--------------------------------------------------------------
    // 8) SINAL VALIDADO - Executar trade
    //--------------------------------------------------------------
    if(raw_signal == 1)
    {
        PrintFormat("[SIGNAL BUY] %s | Close=%.0f | EMAspread=%.0f | DistEMA1=%.0f | RSI=%.1f | MFI=%d(GREEN) | ATR=%.0f",
                    TimeToString(iTime(_Symbol, _Period, shift), TIME_DATE|TIME_MINUTES),
                    close_price, ema_spread, dist_to_ema1, rsi_val, mfi_color, atr_val);

        m_last_entry_time      = current_bar_time;
        m_last_entry_direction = 1;
        return 1;
    }

    if(raw_signal == -1)
    {
        PrintFormat("[SIGNAL SELL] %s | Close=%.0f | EMAspread=%.0f | DistEMA1=%.0f | RSI=%.1f | MFI=%d(RED) | ATR=%.0f",
                    TimeToString(iTime(_Symbol, _Period, shift), TIME_DATE|TIME_MINUTES),
                    close_price, ema_spread, dist_to_ema1, rsi_val, mfi_color, atr_val);

        m_last_entry_time      = current_bar_time;
        m_last_entry_direction = -1;
        return -1;
    }

    return 0;
}
