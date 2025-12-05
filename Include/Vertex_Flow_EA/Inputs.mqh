//+------------------------------------------------------------------+
//|                                                       Inputs.mqh |
//|                                  Copyright 2025, ExpertTrader MQL5 |
//|                                         https://www.experttrader.net |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ExpertTrader MQL5"
#property link      "https://www.experttrader.net"

//--- Enums for FGM
enum SIGNAL_MODE {
    MODE_CONSERVATIVE = 0,  // Conservative (4-5 confirmations)
    MODE_MODERATE = 1,      // Moderate (3-4 confirmations)
    MODE_AGGRESSIVE = 2     // Aggressive (2+ confirmations)
};

enum CROSSOVER_TYPE {
    CROSS_EMA1_EMA2 = 0,   // EMA1 x EMA2 (Fastest)
    CROSS_EMA2_EMA3 = 1,   // EMA2 x EMA3 (Medium)
    CROSS_EMA3_EMA4 = 2,   // EMA3 x EMA4 (Slow)
    CROSS_CUSTOM = 3       // Custom Crossover
};

//--- Enums for MFI
// ENUM_APPLIED_VOLUME is built-in

//--- Input Group: Strategy - FGM Indicator
input group "===== FGM Indicator Settings ====="
input int              Inp_FGM_Period1   = 5;      // FGM EMA 1 Period
input int              Inp_FGM_Period2   = 8;      // FGM EMA 2 Period
input int              Inp_FGM_Period3   = 21;     // FGM EMA 3 Period
input int              Inp_FGM_Period4   = 50;     // FGM EMA 4 Period
input int              Inp_FGM_Period5   = 200;    // FGM EMA 5 Period
input ENUM_APPLIED_PRICE Inp_FGM_Price   = PRICE_CLOSE; // FGM Applied Price
input SIGNAL_MODE      Inp_FGM_Mode      = MODE_MODERATE; // FGM Signal Mode
input int              Inp_FGM_MinStr    = 3;      // FGM Min Strength
input CROSSOVER_TYPE   Inp_FGM_Cross     = CROSS_EMA1_EMA2; // FGM Primary Cross

//--- Input Group: Strategy - Enhanced MFI
input group "===== Enhanced MFI Settings ====="
input int              Inp_MFI_Period    = 14;     // MFI Period
input double           Inp_MFI_LatStart  = 40.0;   // MFI Lateral Zone Start
input double           Inp_MFI_LatEnd    = 60.0;   // MFI Lateral Zone End
input ENUM_APPLIED_VOLUME Inp_MFI_VolType = VOLUME_TICK; // MFI Volume Type

//--- Input Group: Strategy - RSIOMA v2
input group "===== RSIOMA v2 Settings ====="
input int              Inp_RSI_Period    = 14;     // RSI Period
input int              Inp_RSI_MAPeriod  = 9;      // RSI MA Period
input ENUM_MA_METHOD   Inp_RSI_MAMethod  = MODE_SMA; // RSI MA Method

//--- Input Group: Strategy - ADXW Cloud
input group "===== ADXW Cloud Settings ====="
input int              Inp_ADX_Period    = 14;     // ADX Period
input double           Inp_ADX_MinTrend  = 20.0;   // ADX Min Trend Strength

//--- Input Group: Trading Settings
input group "===== Trading Settings ====="
input double           Inp_LotSize       = 0.1;    // Fixed Lot Size
input int              Inp_StopLoss      = 200;    // Stop Loss (Points)
input int              Inp_TakeProfit    = 400;    // Take Profit (Points)
input int              Inp_MagicNum      = 123456; // Magic Number
input int              Inp_Slippage      = 3;      // Slippage (Points)

//--- Input Group: Time Filters
input group "===== Time Filter ====="
input bool             Inp_UseTimeFilter = true;   // Use Time Filter
input string           Inp_StartTime     = "09:00"; // Start Time (HH:MM)
input string           Inp_EndTime       = "17:00"; // End Time (HH:MM)

//--- Input Group: Weekly Trading Filter
input group "═══════════════ WEEKLY TRADING FILTER ═══════════════"
input bool TradeSunday = false;                     // Trade on Sunday
input bool TradeMonday = true;                      // Trade on Monday
input bool TradeTuesday = true;                     // Trade on Tuesday
input bool TradeWednesday = true;                   // Trade on Wednesday
input bool TradeThursday = true;                    // Trade on Thursday
input bool TradeFriday = true;                      // Trade on Friday
input bool TradeSaturday = false;                   // Trade on Saturday

//--- Input Group: Management Settings
input group "===== Management Settings ====="
input bool             Inp_UseBreakEven  = true;   // Use Break Even
input int              Inp_BE_Trigger    = 200;    // BE Trigger (Points) - Aumentado de 150 para 200
input int              Inp_BE_Profit     = 50;     // BE Profit Lock (Points) - Aumentado de 10 para 50
input bool             Inp_UseTrailing   = true;   // Use Trailing Stop
input int              Inp_TS_Start      = 300;    // Trailing Distance (Points) - Aumentado de 200 para 300
input int              Inp_TS_Step       = 50;     // Trailing Step (Points)
