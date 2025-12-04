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
    int            m_handle_obv;
    int            m_handle_rsi;
    
    //--- Buffers for reading
    double         m_buf_fgm_phase[];
    double         m_buf_mfi_color[];
    double         m_buf_mfi_val[];
    double         m_buf_obv_hist[];
    double         m_buf_obv_color[];
    double         m_buf_rsi_val[];
    double         m_buf_rsi_ma[];
    
public:
    CSignalVertexFlow();
    ~CSignalVertexFlow();
    
    bool           Init();
    int            GetSignal(); // 1=Buy, -1=Sell, 0=None
    
    //--- Getters for Chart Attachment
    int            GetHandleFGM() { return m_handle_fgm; }
    int            GetHandleMFI() { return m_handle_mfi; }
    int            GetHandleOBV() { return m_handle_obv; }
    int            GetHandleRSI() { return m_handle_rsi; }
    
private:
    bool           UpdateBuffers();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSignalVertexFlow::CSignalVertexFlow() : 
    m_handle_fgm(INVALID_HANDLE),
    m_handle_mfi(INVALID_HANDLE),
    m_handle_obv(INVALID_HANDLE),
    m_handle_rsi(INVALID_HANDLE)
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CSignalVertexFlow::~CSignalVertexFlow()
{
    if(m_handle_fgm != INVALID_HANDLE) IndicatorRelease(m_handle_fgm);
    if(m_handle_mfi != INVALID_HANDLE) IndicatorRelease(m_handle_mfi);
    if(m_handle_obv != INVALID_HANDLE) IndicatorRelease(m_handle_obv);
    if(m_handle_rsi != INVALID_HANDLE) IndicatorRelease(m_handle_rsi);
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

    //--- Initialize OBV MACD
    m_handle_obv = iCustom(_Symbol, _Period, "Vertex_Flow_EA\\OBV_MACD",
                           Inp_OBV_FastEMA,
                           Inp_OBV_SlowEMA,
                           Inp_OBV_SignalSMA,
                           Inp_OBV_Smooth,
                           Inp_OBV_UseTick,
                           false, false, 34, 0.6 // Visuals & Threshold
                           );
                           
    if(m_handle_obv == INVALID_HANDLE) { Print("Failed to create OBV MACD handle"); return false; }

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

    return true;
}

//+------------------------------------------------------------------+
//| Update Buffers                                                   |
//+------------------------------------------------------------------+
bool CSignalVertexFlow::UpdateBuffers()
{
    // Precisamos de 3 barras COMPLETAS para verificar cruzamento e filtros.
    // Vamos sempre trabalhar com séries (0 = barra atual em formação, 1 = última barra fechada, 2 = barra anterior fechada).
    int count = 3;

    // Copia a partir da barra 0, mas logo abaixo os arrays serão marcados como séries
    // para garantir que todos os indicadores estejam alinhados no mesmo índice.
    if(CopyBuffer(m_handle_fgm, 7, 0, count, m_buf_fgm_phase) < count) return false;
    if(CopyBuffer(m_handle_mfi, 1, 0, count, m_buf_mfi_color) < count) return false;
    if(CopyBuffer(m_handle_mfi, 0, 0, count, m_buf_mfi_val) < count) return false; // Valor para sobrecompra/sobrevenda
    if(CopyBuffer(m_handle_obv, 0, 0, count, m_buf_obv_hist) < count) return false;
    if(CopyBuffer(m_handle_obv, 1, 0, count, m_buf_obv_color) < count) return false;
    // No indicador RSIOMA_v2HHLSX_MT5:
    //  - Buffer 0 = RSI principal (linha vermelha)
    //  - Buffer 1 = MA do RSI (linha azul)
    // Portanto, aqui mantemos a mesma convenção visual:
    if(CopyBuffer(m_handle_rsi, 0, 0, count, m_buf_rsi_val) < count) return false; // Buffer 0 = RSI (vermelha)
    if(CopyBuffer(m_handle_rsi, 1, 0, count, m_buf_rsi_ma) < count) return false; // Buffer 1 = MA  (azul)

    // Garante que todos os buffers usem a mesma convenção de índices (0 = barra atual, 1 = última fechada, 2 = penúltima).
    ArraySetAsSeries(m_buf_fgm_phase, true);
    ArraySetAsSeries(m_buf_mfi_color, true);
    ArraySetAsSeries(m_buf_mfi_val, true);
    ArraySetAsSeries(m_buf_obv_hist, true);
    ArraySetAsSeries(m_buf_obv_color, true);
    ArraySetAsSeries(m_buf_rsi_val, true);
    ArraySetAsSeries(m_buf_rsi_ma, true);

    return true;
}

//+------------------------------------------------------------------+
//| Get Signal                                                       |
//+------------------------------------------------------------------+
int CSignalVertexFlow::GetSignal()
{
    if(!UpdateBuffers())
        return 0;

    // Vamos sempre analisar a ÚLTIMA BARRA FECHADA (candle de sinal) usando índice da série de preços.
    // Em CopyBuffer usamos start_pos=0 e ArraySetAsSeries(true), então:
    //  - índice 0 => barra atual em formação
    //  - índice 1 => última barra fechada (candle de sinal)
    //  - índice 2 => barra fechada anterior
    int shift = 1;              // barra fechada mais recente (candle de sinal)
    int prev_shift = shift + 1; // barra anterior à de sinal (para detectar cruzamento)
    
    //--- 1. RSIOMA Trigger (Crossover)
    // IMPORTANTE: no indicador RSIOMA_v2HHLSX_MT5 a convenção é:
    //  - Buffer 0 (m_buf_rsi_val) : linha vermelha (RSI/RSIOMA principal)
    //  - Buffer 1 (m_buf_rsi_ma)  : linha azul  (média / Sinal)
    // Para BUY queremos que a linha vermelha esteja ACIMA da azul (tendência de alta).
    // Para SELL queremos que a linha vermelha esteja ABAIXO da azul (tendência de baixa).
    // Além disso, exigimos um cruzamento verdadeiro entre a barra anterior e a barra de sinal.

    bool rsi_bull_now  = (m_buf_rsi_val[shift]  > m_buf_rsi_ma[shift]);      // vermelho acima da azul
    bool rsi_bull_prev = (m_buf_rsi_val[prev_shift] > m_buf_rsi_ma[prev_shift]);
    bool rsi_bear_now  = (m_buf_rsi_val[shift]  < m_buf_rsi_ma[shift]);      // vermelho abaixo da azul
    bool rsi_bear_prev = (m_buf_rsi_val[prev_shift] < m_buf_rsi_ma[prev_shift]);

    bool rsi_cross_up   = (!rsi_bull_prev && rsi_bull_now);  // cruzou para cima (buy)
    bool rsi_cross_down = (!rsi_bear_prev && rsi_bear_now);  // cruzou para baixo (sell)

    // LOG DE DEPURAÇÃO (opcional)
    // Atenção: este log pode ser muito verboso em backtests "Every tick".
    // Para evitar spam no log, só ativar manualmente quando estiver depurando um caso específico.
    /*
    if(rsi_cross_up || rsi_cross_down)
    {
        PrintFormat("VertexFlow RSIOMA signal: time=%s dir=%s rsi_red=%.2f rsi_blue=%.2f | prev_red=%.2f prev_blue=%.2f",
                    TimeToString(iTime(_Symbol, _Period, shift), TIME_DATE|TIME_MINUTES),
                    (rsi_cross_up?"BUY":"SELL"),
                    m_buf_rsi_ma[shift], m_buf_rsi_val[shift],
                    m_buf_rsi_ma[prev_shift], m_buf_rsi_val[prev_shift]);
    }
    */

    if(!rsi_cross_up && !rsi_cross_down)
        return 0; // Sem gatilho de RSIOMA, nenhuma operação

    // Nível extra de filtro: exigimos que o RSIOMA esteja coerente com a direção
    // Compra apenas se a linha vermelha (RSIOMA) estiver acima de 50
    // Venda apenas se a linha vermelha estiver abaixo de 50
    // rsi_red representa SEMPRE a linha vermelha (RSI principal)
    double rsi_red = m_buf_rsi_val[shift];
    
    //--- 2. FGM Filter
    // Phase: 2=StrongBull, 1=WeakBull, 0=Neutral, -1=WeakBear, -2=StrongBear
    int fgm_phase = (int)m_buf_fgm_phase[shift];
    
    //--- 3. MFI Filter
    // Color: 0=Green, 1=Red, 2=Yellow
    int mfi_color = (int)m_buf_mfi_color[shift];
    double mfi_val = m_buf_mfi_val[shift];
    
    if(mfi_color == 2) return 0; // Lateral - VETO
    
    //--- 4. OBV MACD Filter
    // Color: 0=GreenStrong, 1=RedStrong, 2=GreenWeak, 3=RedWeak
    double obv_hist = m_buf_obv_hist[shift];
    int obv_color = (int)m_buf_obv_color[shift];
    
    //--- BUY LOGIC
    if(rsi_cross_up)
    {
        // RSIOMA deve estar acima de 50 para compras
        if(rsi_red < 50.0) return 0;

        // FGM: Must be Bullish (1 or 2)
        if(fgm_phase < 1) return 0;
        
        // MFI: Must be Green (0) OR Oversold (<20)
        // Note: mfi_color != 2 is already checked.
        // If it's Red (1) but < 20, is it allowed? User said: "Verde OR saindo da zona de sobrevenda"
        // If it's Red, it's selling pressure. But if it's < 20, it might be a reversal.
        // Let's stick to strict: If Color is Red, check if < 20. If > 20 and Red, then Veto.
        if(mfi_color == 1 && mfi_val > 20.0) return 0; 
        
        // OBV: histograma deve estar POSITIVO para comprar
        if(obv_hist <= 0.0) return 0;
        // Cor: SOMENTE GreenStrong (0) é aceita para compra.
        // Qualquer outro valor (GreenWeak=2 ou vermelho forte/fraco) bloqueia a entrada.
        if(obv_color != 0) return 0;
        
        return 1; // Valid Buy
    }
    
    //--- SELL LOGIC
    if(rsi_cross_down)
    {
        // RSIOMA deve estar abaixo de 50 para vendas
        if(rsi_red > 50.0) return 0;

        // FGM: Must be Bearish (-1 or -2)
        if(fgm_phase > -1) return 0;
        
        // MFI: Must be Red (1) OR Overbought (>80)
        // If it's Green (0) but > 80, is it allowed?
        if(mfi_color == 0 && mfi_val < 80.0) return 0;
        
        // OBV: histograma deve estar NEGATIVO para vender
        if(obv_hist >= 0.0) return 0;
        // Cor: SOMENTE RedStrong (1) é aceita para venda.
        // Qualquer outro valor (RedWeak=3 ou verde forte/fraco) bloqueia a entrada.
        if(obv_color != 1) return 0;
        
        return -1; // Valid Sell
    }
    
    return 0;
}
