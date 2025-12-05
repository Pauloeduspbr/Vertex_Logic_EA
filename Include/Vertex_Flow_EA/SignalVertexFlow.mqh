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
    
    //--- Buffers for reading
    double         m_buf_fgm_phase[];
    double         m_buf_mfi_color[];
    double         m_buf_mfi_val[];
    double         m_buf_rsi_val[];
    double         m_buf_rsi_ma[];
    double         m_buf_adx[];
    
    //--- Contadores de barras com filtros alinhados (para re-entrada)
    int            m_bars_aligned_buy;
    int            m_bars_aligned_sell;
    datetime       m_last_entry_time;  // Evita múltiplas entradas na mesma tendência
    
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
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSignalVertexFlow::CSignalVertexFlow() : 
    m_handle_fgm(INVALID_HANDLE),
    m_handle_mfi(INVALID_HANDLE),
    m_handle_rsi(INVALID_HANDLE),
    m_handle_adx(INVALID_HANDLE),
    m_bars_aligned_buy(0),
    m_bars_aligned_sell(0),
    m_last_entry_time(0)
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
    // Precisamos de 3 barras COMPLETAS para verificar cruzamento e filtros.
    // Vamos sempre trabalhar com séries (0 = barra atual em formação, 1 = última barra fechada, 2 = barra anterior fechada).
    int count = 3;

    // IMPORTANTE: Definir ArraySetAsSeries ANTES de CopyBuffer é uma boa prática
    // para evitar problemas de indexação em diferentes timeframes
    ArraySetAsSeries(m_buf_fgm_phase, true);
    ArraySetAsSeries(m_buf_mfi_color, true);
    ArraySetAsSeries(m_buf_mfi_val, true);
    ArraySetAsSeries(m_buf_rsi_val, true);
    ArraySetAsSeries(m_buf_rsi_ma, true);
    ArraySetAsSeries(m_buf_adx, true);

    // Copia a partir da barra 0, com arrays já marcados como séries
    // para garantir que todos os indicadores estejam alinhados no mesmo índice.
    if(CopyBuffer(m_handle_fgm, 7, 0, count, m_buf_fgm_phase) < count) return false;
    if(CopyBuffer(m_handle_mfi, 1, 0, count, m_buf_mfi_color) < count) return false;
    if(CopyBuffer(m_handle_mfi, 0, 0, count, m_buf_mfi_val) < count) return false; // Valor para sobrecompra/sobrevenda
    // No indicador RSIOMA_v2HHLSX_MT5:
    //  - Buffer 0 = RSI principal (linha vermelha)
    //  - Buffer 1 = MA do RSI (linha azul)
    // Portanto, aqui mantemos a mesma convenção visual:
    if(CopyBuffer(m_handle_rsi, 0, 0, count, m_buf_rsi_val) < count) return false; // Buffer 0 = RSI (vermelha)
    if(CopyBuffer(m_handle_rsi, 1, 0, count, m_buf_rsi_ma) < count) return false; // Buffer 1 = MA  (azul)

    // ADXW Cloud: Buffer 2 é assumido como o valor principal do ADX
    // NOTA: Se o indicador ADXW_Cloud usar outro buffer, ajustar aqui
    if(CopyBuffer(m_handle_adx, 2, 0, count, m_buf_adx) < count) return false;

    return true;
}

//+------------------------------------------------------------------+
//| Get Signal                                                       |
//+------------------------------------------------------------------+
int CSignalVertexFlow::GetSignal()
{
    if(!UpdateBuffers())
        return 0;

    // IMPORTANTE: Verificar se estamos no início de uma nova barra para evitar sinais duplicados
    static datetime last_bar_time = 0;
    datetime current_bar_time = iTime(_Symbol, _Period, 0);
    
    // Só processar sinal UMA VEZ por barra (quando a barra fecha)
    if(last_bar_time == current_bar_time)
        return 0; // Já processamos esta barra
    
    last_bar_time = current_bar_time;

    // Analisamos a ÚLTIMA BARRA FECHADA (índice 1 após ArraySetAsSeries)
    int shift = 1;              // barra fechada mais recente (candle de sinal)
    int prev_shift = shift + 1; // barra anterior à de sinal (para detectar cruzamento)
    
    //==========================================================================
    // ESTRATÉGIA COM 3 TIPOS DE TRIGGERS:
    //
    // 1. TRIGGER PRIMÁRIO: MFI muda de cor OU FGM muda de fase
    // 2. TRIGGER SECUNDÁRIO: RSI cruza sua MA
    // 3. TRIGGER DE CONTINUAÇÃO: Filtros alinhados por N barras sem entrada
    //
    // FILTROS (todos devem estar alinhados):
    // 1. FGM: >0 para compra, <0 para venda
    // 2. MFI: Verde(0) para compra, Vermelho(1) para venda
    // 3. RSIOMA: Acima da MA = compra, Abaixo da MA = venda
    // 4. ADX: Acima de 20 (tendência com força)
    //==========================================================================
    
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
    
    //--- Condições de FILTRO
    bool rsi_bullish = (rsi_val > rsi_ma);
    bool rsi_bearish = (rsi_val < rsi_ma);
    
    bool fgm_bullish = (fgm_phase > 0);
    bool fgm_bearish = (fgm_phase < 0);
    
    bool mfi_green = (mfi_color == 0);
    bool mfi_red = (mfi_color == 1);
    bool mfi_yellow = (mfi_color == 2);
    
    bool adx_strong = (adx_curr >= Inp_ADX_MinTrend);
    
    //--- Verificar ALINHAMENTO COMPLETO
    bool all_buy_filters = (fgm_bullish && mfi_green && rsi_bullish && adx_strong);
    bool all_sell_filters = (fgm_bearish && mfi_red && rsi_bearish && adx_strong);
    
    //--- Atualizar contadores de barras alinhadas
    if(all_buy_filters)
    {
        m_bars_aligned_buy++;
        m_bars_aligned_sell = 0; // Reset contador oposto
    }
    else
    {
        m_bars_aligned_buy = 0;
    }
    
    if(all_sell_filters)
    {
        m_bars_aligned_sell++;
        m_bars_aligned_buy = 0; // Reset contador oposto
    }
    else
    {
        m_bars_aligned_sell = 0;
    }
    
    //--- TRIGGERS de mudança de estado
    bool mfi_turned_green = (mfi_color == 0 && mfi_color_prev != 0);
    bool mfi_turned_red = (mfi_color == 1 && mfi_color_prev != 1);
    bool fgm_turned_bullish = (fgm_phase > 0 && fgm_phase_prev <= 0);
    bool fgm_turned_bearish = (fgm_phase < 0 && fgm_phase_prev >= 0);
    bool rsi_crossed_up = (rsi_prev <= rsi_ma_prev && rsi_val > rsi_ma);
    bool rsi_crossed_down = (rsi_prev >= rsi_ma_prev && rsi_val < rsi_ma);
    
    //--- TRIGGER DE CONTINUAÇÃO: Entrar após 3 barras alinhadas se ainda não entramos
    // Isso captura tendências estabelecidas que não tiveram trigger inicial
    bool continuation_buy = (m_bars_aligned_buy >= 3);
    bool continuation_sell = (m_bars_aligned_sell >= 3);
    
    // Verificar se já entramos nesta tendência recentemente
    // Se a última entrada foi há menos de 10 barras, não re-entrar por continuação
    int bars_since_last_entry = (int)((current_bar_time - m_last_entry_time) / PeriodSeconds(_Period));
    bool can_continue = (bars_since_last_entry > 10 || m_last_entry_time == 0);
    
    // DEBUG: Log do estado atual
    PrintFormat("[DEBUG] %s | FGM=%d (prev=%d) | MFI_Color=%d (prev=%d) | RSI=%.2f MA=%.2f (%s) | ADX=%.2f | BuyAligned=%d SellAligned=%d",
                TimeToString(iTime(_Symbol, _Period, shift), TIME_DATE|TIME_MINUTES),
                fgm_phase, fgm_phase_prev,
                mfi_color, mfi_color_prev,
                rsi_val, rsi_ma, rsi_bullish ? "BULL" : (rsi_bearish ? "BEAR" : "NEUTRAL"),
                adx_curr,
                m_bars_aligned_buy, m_bars_aligned_sell);
    
    //==========================================================================
    // LÓGICA DE COMPRA
    //==========================================================================
    bool buy_trigger_primary = (mfi_turned_green || fgm_turned_bullish);
    bool buy_trigger_secondary = (rsi_crossed_up && fgm_bullish && mfi_green);
    bool buy_trigger_continuation = (continuation_buy && can_continue);
    bool buy_trigger = (buy_trigger_primary || buy_trigger_secondary || buy_trigger_continuation);
    
    if(buy_trigger && all_buy_filters)
    {
        Print("[TRIGGER BUY] Primary=", buy_trigger_primary, 
              " Secondary(RSI)=", buy_trigger_secondary,
              " Continuation=", buy_trigger_continuation);
        
        Print("[SIGNAL BUY] All filters aligned! FGM=", fgm_phase, " MFI=Green RSI>MA ADX=", adx_curr);
        
        // Registrar entrada
        m_last_entry_time = current_bar_time;
        m_bars_aligned_buy = 0; // Reset para evitar re-entradas imediatas
        
        return 1;
    }
    
    //==========================================================================
    // LÓGICA DE VENDA
    //==========================================================================
    bool sell_trigger_primary = (mfi_turned_red || fgm_turned_bearish);
    bool sell_trigger_secondary = (rsi_crossed_down && fgm_bearish && mfi_red);
    bool sell_trigger_continuation = (continuation_sell && can_continue);
    bool sell_trigger = (sell_trigger_primary || sell_trigger_secondary || sell_trigger_continuation);
    
    if(sell_trigger && all_sell_filters)
    {
        Print("[TRIGGER SELL] Primary=", sell_trigger_primary, 
              " Secondary(RSI)=", sell_trigger_secondary,
              " Continuation=", sell_trigger_continuation);
        
        Print("[SIGNAL SELL] All filters aligned! FGM=", fgm_phase, " MFI=Red RSI<MA ADX=", adx_curr);
        
        // Registrar entrada
        m_last_entry_time = current_bar_time;
        m_bars_aligned_sell = 0; // Reset para evitar re-entradas imediatas
        
        return -1;
    }
    
    return 0;
}
