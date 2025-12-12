//+------------------------------------------------------------------+
//|                                                       CStats.mqh |
//|                         FGM Trend Rider - Versão Platina         |
//|                           Estatísticas e Logging                 |
//+------------------------------------------------------------------+
#property copyright "FGM Trading Systems"
#property version   "1.00"

#ifndef CSTATS_MQH
#define CSTATS_MQH

//+------------------------------------------------------------------+
//| Enumeração: Nível de Log                                         |
//+------------------------------------------------------------------+
enum ENUM_LOG_LEVEL
{
   LOG_MINIMAL = 0,    // Minimal - Apenas erros críticos
   LOG_NORMAL  = 1,    // Normal - Operações principais
   LOG_DEBUG   = 2     // Debug - Detalhamento completo
};

//+------------------------------------------------------------------+
//| Estrutura: Estatísticas de Trade Individual                      |
//+------------------------------------------------------------------+
struct TRADE_STATS
{
   datetime          OpenTime;           // Hora de abertura
   datetime          CloseTime;          // Hora de fechamento
   string            Symbol;             // Símbolo
   ENUM_ORDER_TYPE   OrderType;          // Tipo (BUY/SELL)
   double            EntryPrice;         // Preço de entrada
   double            ExitPrice;          // Preço de saída
   double            Volume;             // Volume
   double            Profit;             // Lucro/Prejuízo
   double            ProfitPips;         // Lucro em pips
   int               Duration;           // Duração em segundos
   int               SignalStrength;     // Força do sinal (F3/F4/F5)
   int               DayOfWeek;          // Dia da semana
   int               EntryHour;          // Hora de entrada
   string            Session;            // Sessão (Asia/London/NY)
   string            CloseReason;        // Razão do fechamento
   bool              IsWin;              // Resultado positivo
};

//+------------------------------------------------------------------+
//| Estrutura: Estatísticas Agregadas                                |
//+------------------------------------------------------------------+
struct AGGREGATED_STATS
{
   int               TotalTrades;        // Total de trades
   int               Wins;               // Vitórias
   int               Losses;             // Derrotas
   double            WinRate;            // Taxa de acerto
   double            TotalProfit;        // Lucro total
   double            GrossProfit;        // Lucro bruto
   double            GrossLoss;          // Perda bruta
   double            ProfitFactor;       // Fator de lucro
   double            AverageWin;         // Média das vitórias
   double            AverageLoss;        // Média das derrotas
   double            ExpectedPayoff;     // Payoff esperado
   double            MaxProfit;          // Maior lucro
   double            MaxLoss;            // Maior perda
   int               MaxConsecWins;      // Máx consecutivas vitórias
   int               MaxConsecLosses;    // Máx consecutivas derrotas
   double            AvgDuration;        // Duração média
   
   void Reset()
   {
      TotalTrades = 0;
      Wins = 0;
      Losses = 0;
      WinRate = 0;
      TotalProfit = 0;
      GrossProfit = 0;
      GrossLoss = 0;
      ProfitFactor = 0;
      AverageWin = 0;
      AverageLoss = 0;
      ExpectedPayoff = 0;
      MaxProfit = 0;
      MaxLoss = 0;
      MaxConsecWins = 0;
      MaxConsecLosses = 0;
      AvgDuration = 0;
   }
};

//+------------------------------------------------------------------+
//| Classe: CStats - Estatísticas e Logging                          |
//+------------------------------------------------------------------+
class CStats
{
private:
   //--- Configurações
   ENUM_LOG_LEVEL    m_logLevel;
   bool              m_trackByDay;
   bool              m_trackByHour;
   bool              m_trackByStrength;
   bool              m_trackBySession;
   bool              m_exportToFile;
   string            m_exportPath;
   ulong             m_magicNumber;
   
   //--- Armazenamento de trades
   TRADE_STATS       m_trades[];
   int               m_tradesCount;
   
   //--- Estatísticas por categoria
   AGGREGATED_STATS  m_statsByDay[7];       // Dom=0 até Sáb=6
   AGGREGATED_STATS  m_statsByHour[24];     // 0-23
   AGGREGATED_STATS  m_statsByStrength[3];  // F3=0, F4=1, F5=2
   AGGREGATED_STATS  m_statsBySession[3];   // Asia=0, London=1, NY=2
   AGGREGATED_STATS  m_statsOverall;        // Geral
   
   //--- Contadores de sequência
   int               m_currentConsecWins;
   int               m_currentConsecLosses;
   
   //--- Arquivo de log
   int               m_logHandle;
   string            m_logFileName;
   
   //--- Métodos privados
   void              UpdateAggregatedStats(AGGREGATED_STATS& stats, const TRADE_STATS& trade);
   void              CalculateDerivedMetrics(AGGREGATED_STATS& stats);
   int               GetSessionIndex(const string session);
   int               GetStrengthIndex(int strength);
   string            FormatLogMessage(const string prefix, const string message);
   void              WriteToFile(const string message);
   
public:
   //--- Construtor e destrutor
                     CStats();
                    ~CStats();
   
   //--- Inicialização
   bool              Init(ulong magicNumber,
                         ENUM_LOG_LEVEL logLevel = LOG_NORMAL,
                         bool trackByDay = true,
                         bool trackByHour = true,
                         bool trackByStrength = true,
                         bool trackBySession = true,
                         bool exportToFile = false,
                         string exportPath = "FGM_Stats");
   
   //--- Logging
   void              LogMinimal(const string message);
   void              LogNormal(const string message);
   void              LogDebug(const string message);
   void              LogError(const string message);
   void              LogTrade(const string action, double price, double volume, double sl = 0, double tp = 0);
   void              LogSignal(int strength, double confluence, string direction);
   void              LogFilter(const string filterName, bool passed, const string reason = "");
   
   //--- Registro de trades
   void              RecordTrade(datetime openTime, datetime closeTime,
                                ENUM_ORDER_TYPE orderType,
                                double entryPrice, double exitPrice,
                                double volume, double profit,
                                int signalStrength, const string session,
                                const string closeReason);
   
   void              RecordTradeFromHistory(ulong ticket);
   
   //--- Obtenção de estatísticas
   AGGREGATED_STATS  GetOverallStats()                    { return m_statsOverall; }
   AGGREGATED_STATS  GetStatsByDay(int dayOfWeek)         { return m_statsByDay[dayOfWeek % 7]; }
   AGGREGATED_STATS  GetStatsByHour(int hour)             { return m_statsByHour[hour % 24]; }
   AGGREGATED_STATS  GetStatsByStrength(int strength)     { return m_statsByStrength[GetStrengthIndex(strength)]; }
   AGGREGATED_STATS  GetStatsBySession(const string session) { return m_statsBySession[GetSessionIndex(session)]; }
   
   //--- Análise de desempenho
   double            GetWinRateForDay(int dayOfWeek);
   double            GetWinRateForHour(int hour);
   double            GetWinRateForStrength(int strength);
   double            GetBestTradingHour();
   int               GetBestTradingDay();
   int               GetBestStrength();
   string            GetBestSession();
   
   //--- Relatórios
   string            GenerateReport();
   string            GenerateDailyReport(datetime date);
   string            GenerateWeeklyReport();
   void              PrintReport();
   void              ExportStats();
   
   //--- Reset
   void              ResetStats();
   void              ResetDailyStats();
};

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
CStats::CStats()
{
   m_logLevel = LOG_NORMAL;
   m_trackByDay = true;
   m_trackByHour = true;
   m_trackByStrength = true;
   m_trackBySession = true;
   m_exportToFile = false;
   m_exportPath = "";
   m_magicNumber = 0;
   m_tradesCount = 0;
   m_currentConsecWins = 0;
   m_currentConsecLosses = 0;
   m_logHandle = INVALID_HANDLE;
   m_logFileName = "";
   
   ArrayResize(m_trades, 0);
   
   //--- Inicializar estatísticas
   m_statsOverall.Reset();
   for(int i = 0; i < 7; i++)  m_statsByDay[i].Reset();
   for(int i = 0; i < 24; i++) m_statsByHour[i].Reset();
   for(int i = 0; i < 3; i++)  m_statsByStrength[i].Reset();
   for(int i = 0; i < 3; i++)  m_statsBySession[i].Reset();
}

//+------------------------------------------------------------------+
//| Destrutor                                                        |
//+------------------------------------------------------------------+
CStats::~CStats()
{
   if(m_logHandle != INVALID_HANDLE)
   {
      FileClose(m_logHandle);
      m_logHandle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Inicialização                                                    |
//+------------------------------------------------------------------+
bool CStats::Init(ulong magicNumber,
                  ENUM_LOG_LEVEL logLevel,
                  bool trackByDay,
                  bool trackByHour,
                  bool trackByStrength,
                  bool trackBySession,
                  bool exportToFile,
                  string exportPath)
{
   m_magicNumber = magicNumber;
   m_logLevel = logLevel;
   m_trackByDay = trackByDay;
   m_trackByHour = trackByHour;
   m_trackByStrength = trackByStrength;
   m_trackBySession = trackBySession;
   m_exportToFile = exportToFile;
   m_exportPath = exportPath;
   
   //--- Criar arquivo de log se necessário
   if(m_exportToFile)
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      
      m_logFileName = StringFormat("%s_%04d%02d%02d_%s.log",
                                   exportPath,
                                   dt.year, dt.mon, dt.day,
                                   Symbol());
      
      m_logHandle = FileOpen(m_logFileName, FILE_WRITE|FILE_TXT|FILE_SHARE_READ, '\t');
      
      if(m_logHandle == INVALID_HANDLE)
      {
         Print("[CStats] Erro ao criar arquivo de log: ", GetLastError());
         return false;
      }
      
      //--- Escrever cabeçalho
      FileWriteString(m_logHandle, "=================================================\n");
      FileWriteString(m_logHandle, "FGM Trend Rider - Log de Operações\n");
      FileWriteString(m_logHandle, StringFormat("Símbolo: %s | Magic: %d\n", Symbol(), m_magicNumber));
      FileWriteString(m_logHandle, StringFormat("Início: %s\n", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS)));
      FileWriteString(m_logHandle, "=================================================\n\n");
   }
   
   LogNormal("CStats inicializado com sucesso");
   return true;
}

//+------------------------------------------------------------------+
//| Formatar mensagem de log                                         |
//+------------------------------------------------------------------+
string CStats::FormatLogMessage(const string prefix, const string message)
{
   return StringFormat("[%s] [%s] %s",
                       TimeToString(TimeCurrent(), TIME_SECONDS),
                       prefix,
                       message);
}

//+------------------------------------------------------------------+
//| Escrever no arquivo                                              |
//+------------------------------------------------------------------+
void CStats::WriteToFile(const string message)
{
   if(m_logHandle != INVALID_HANDLE)
   {
      FileWriteString(m_logHandle, message + "\n");
      FileFlush(m_logHandle);
   }
}

//+------------------------------------------------------------------+
//| Log Minimal - Apenas erros críticos                              |
//+------------------------------------------------------------------+
void CStats::LogMinimal(const string message)
{
   if(m_logLevel >= LOG_MINIMAL)
   {
      string formatted = FormatLogMessage("INFO", message);
      Print(formatted);
      
      if(m_exportToFile)
         WriteToFile(formatted);
   }
}

//+------------------------------------------------------------------+
//| Log Normal - Operações principais                                |
//+------------------------------------------------------------------+
void CStats::LogNormal(const string message)
{
   if(m_logLevel >= LOG_NORMAL)
   {
      string formatted = FormatLogMessage("INFO", message);
      Print(formatted);
      
      if(m_exportToFile)
         WriteToFile(formatted);
   }
}

//+------------------------------------------------------------------+
//| Log Debug - Detalhamento completo                                |
//+------------------------------------------------------------------+
void CStats::LogDebug(const string message)
{
   if(m_logLevel >= LOG_DEBUG)
   {
      string formatted = FormatLogMessage("DEBUG", message);
      Print(formatted);
      
      if(m_exportToFile)
         WriteToFile(formatted);
   }
}

//+------------------------------------------------------------------+
//| Log Error - Sempre registrado                                    |
//+------------------------------------------------------------------+
void CStats::LogError(const string message)
{
   string formatted = FormatLogMessage("ERROR", message);
   Print(formatted);
   
   if(m_exportToFile)
      WriteToFile(formatted);
}

//+------------------------------------------------------------------+
//| Log de Trade                                                     |
//+------------------------------------------------------------------+
void CStats::LogTrade(const string action, double price, double volume, double sl, double tp)
{
   if(m_logLevel >= LOG_NORMAL)
   {
      string slStr = (sl > 0) ? StringFormat(" | SL: %.5f", sl) : "";
      string tpStr = (tp > 0) ? StringFormat(" | TP: %.5f", tp) : "";
      
      string msg = StringFormat("TRADE: %s @ %.5f | Vol: %.2f%s%s",
                               action, price, volume, slStr, tpStr);
      
      LogNormal(msg);
   }
}

//+------------------------------------------------------------------+
//| Log de Sinal                                                     |
//+------------------------------------------------------------------+
void CStats::LogSignal(int strength, double confluence, string direction)
{
   if(m_logLevel >= LOG_NORMAL)
   {
      string msg = StringFormat("SIGNAL: F%d %s | Confluência: %.1f%%",
                               strength, direction, confluence * 100);
      LogNormal(msg);
   }
}

//+------------------------------------------------------------------+
//| Log de Filtro                                                    |
//+------------------------------------------------------------------+
void CStats::LogFilter(const string filterName, bool passed, const string reason)
{
   if(m_logLevel >= LOG_DEBUG)
   {
      string status = passed ? "PASSED" : "BLOCKED";
      string reasonStr = (reason != "") ? StringFormat(" (%s)", reason) : "";
      
      string msg = StringFormat("FILTER [%s]: %s%s", filterName, status, reasonStr);
      LogDebug(msg);
   }
}

//+------------------------------------------------------------------+
//| Registrar trade                                                  |
//+------------------------------------------------------------------+
void CStats::RecordTrade(datetime openTime, datetime closeTime,
                        ENUM_ORDER_TYPE orderType,
                        double entryPrice, double exitPrice,
                        double volume, double profit,
                        int signalStrength, const string session,
                        const string closeReason)
{
   //--- Criar registro
   TRADE_STATS trade;
   trade.OpenTime = openTime;
   trade.CloseTime = closeTime;
   trade.Symbol = Symbol();
   trade.OrderType = orderType;
   trade.EntryPrice = entryPrice;
   trade.ExitPrice = exitPrice;
   trade.Volume = volume;
   trade.Profit = profit;
   trade.Duration = (int)(closeTime - openTime);
   trade.SignalStrength = signalStrength;
   trade.Session = session;
   trade.CloseReason = closeReason;
   trade.IsWin = (profit > 0);
   
   //--- Calcular profit em pips
   double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   if(point > 0)
   {
      if(orderType == ORDER_TYPE_BUY)
         trade.ProfitPips = (exitPrice - entryPrice) / point;
      else
         trade.ProfitPips = (entryPrice - exitPrice) / point;
   }
   else
      trade.ProfitPips = 0;
   
   //--- Data/hora
   MqlDateTime dt;
   TimeToStruct(openTime, dt);
   trade.DayOfWeek = dt.day_of_week;
   trade.EntryHour = dt.hour;
   
   //--- Adicionar ao array
   int newSize = ArraySize(m_trades) + 1;
   ArrayResize(m_trades, newSize);
   m_trades[newSize - 1] = trade;
   m_tradesCount = newSize;
   
   //--- Atualizar sequências
   if(trade.IsWin)
   {
      m_currentConsecWins++;
      m_currentConsecLosses = 0;
   }
   else
   {
      m_currentConsecLosses++;
      m_currentConsecWins = 0;
   }
   
   //--- Atualizar estatísticas agregadas
   UpdateAggregatedStats(m_statsOverall, trade);
   
   if(m_trackByDay)
      UpdateAggregatedStats(m_statsByDay[trade.DayOfWeek], trade);
   
   if(m_trackByHour)
      UpdateAggregatedStats(m_statsByHour[trade.EntryHour], trade);
   
   if(m_trackByStrength)
      UpdateAggregatedStats(m_statsByStrength[GetStrengthIndex(signalStrength)], trade);
   
   if(m_trackBySession)
      UpdateAggregatedStats(m_statsBySession[GetSessionIndex(session)], trade);
   
   //--- Log
   LogNormal(StringFormat("TRADE CLOSED: %s | Profit: %.2f | Razão: %s",
                         trade.IsWin ? "WIN" : "LOSS",
                         profit,
                         closeReason));
}

//+------------------------------------------------------------------+
//| Registrar trade do histórico                                     |
//+------------------------------------------------------------------+
void CStats::RecordTradeFromHistory(ulong ticket)
{
   if(!HistoryDealSelect(ticket))
   {
      LogError(StringFormat("Não foi possível selecionar deal %d", ticket));
      return;
   }
   
   //--- Obter informações do deal
   datetime dealTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
   ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
   double price = HistoryDealGetDouble(ticket, DEAL_PRICE);
   double volume = HistoryDealGetDouble(ticket, DEAL_VOLUME);
   double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
   
   //--- Determinar tipo de ordem
   ENUM_ORDER_TYPE orderType;
   if(dealType == DEAL_TYPE_BUY)
      orderType = ORDER_TYPE_BUY;
   else if(dealType == DEAL_TYPE_SELL)
      orderType = ORDER_TYPE_SELL;
   else
      return; // Ignorar outros tipos
   
   //--- Detectar sessão baseado na hora
   MqlDateTime dt;
   TimeToStruct(dealTime, dt);
   string session;
   
   if(dt.hour >= 0 && dt.hour < 8)
      session = "Asia";
   else if(dt.hour >= 8 && dt.hour < 14)
      session = "London";
   else
      session = "NewYork";
   
   //--- Registrar (simplificado - sem dados completos de abertura)
   RecordTrade(dealTime, dealTime, orderType, price, price, volume, profit, 4, session, "History");
}

//+------------------------------------------------------------------+
//| Atualizar estatísticas agregadas                                 |
//+------------------------------------------------------------------+
void CStats::UpdateAggregatedStats(AGGREGATED_STATS& stats, const TRADE_STATS& trade)
{
   stats.TotalTrades++;
   stats.TotalProfit += trade.Profit;
   
   if(trade.IsWin)
   {
      stats.Wins++;
      stats.GrossProfit += trade.Profit;
      
      if(trade.Profit > stats.MaxProfit)
         stats.MaxProfit = trade.Profit;
      
      if(m_currentConsecWins > stats.MaxConsecWins)
         stats.MaxConsecWins = m_currentConsecWins;
   }
   else
   {
      stats.Losses++;
      stats.GrossLoss += MathAbs(trade.Profit);
      
      if(trade.Profit < stats.MaxLoss)
         stats.MaxLoss = trade.Profit;
      
      if(m_currentConsecLosses > stats.MaxConsecLosses)
         stats.MaxConsecLosses = m_currentConsecLosses;
   }
   
   //--- Atualizar duração média
   stats.AvgDuration = ((stats.AvgDuration * (stats.TotalTrades - 1)) + trade.Duration) / stats.TotalTrades;
   
   //--- Calcular métricas derivadas
   CalculateDerivedMetrics(stats);
}

//+------------------------------------------------------------------+
//| Calcular métricas derivadas                                      |
//+------------------------------------------------------------------+
void CStats::CalculateDerivedMetrics(AGGREGATED_STATS& stats)
{
   //--- Win Rate
   if(stats.TotalTrades > 0)
      stats.WinRate = (double)stats.Wins / stats.TotalTrades * 100;
   
   //--- Profit Factor
   if(stats.GrossLoss > 0)
      stats.ProfitFactor = stats.GrossProfit / stats.GrossLoss;
   else if(stats.GrossProfit > 0)
      stats.ProfitFactor = 999.99; // Infinito prático
   
   //--- Média de vitórias
   if(stats.Wins > 0)
      stats.AverageWin = stats.GrossProfit / stats.Wins;
   
   //--- Média de derrotas
   if(stats.Losses > 0)
      stats.AverageLoss = stats.GrossLoss / stats.Losses;
   
   //--- Expected Payoff
   if(stats.TotalTrades > 0)
      stats.ExpectedPayoff = stats.TotalProfit / stats.TotalTrades;
}

//+------------------------------------------------------------------+
//| Obter índice da sessão                                           |
//+------------------------------------------------------------------+
int CStats::GetSessionIndex(const string session)
{
   if(session == "Asia")
      return 0;
   else if(session == "London")
      return 1;
   else
      return 2; // NewYork
}

//+------------------------------------------------------------------+
//| Obter índice da força                                            |
//+------------------------------------------------------------------+
int CStats::GetStrengthIndex(int strength)
{
   if(strength <= 3)
      return 0; // F3
   else if(strength == 4)
      return 1; // F4
   else
      return 2; // F5
}

//+------------------------------------------------------------------+
//| Win Rate por dia                                                 |
//+------------------------------------------------------------------+
double CStats::GetWinRateForDay(int dayOfWeek)
{
   return m_statsByDay[dayOfWeek % 7].WinRate;
}

//+------------------------------------------------------------------+
//| Win Rate por hora                                                |
//+------------------------------------------------------------------+
double CStats::GetWinRateForHour(int hour)
{
   return m_statsByHour[hour % 24].WinRate;
}

//+------------------------------------------------------------------+
//| Win Rate por força                                               |
//+------------------------------------------------------------------+
double CStats::GetWinRateForStrength(int strength)
{
   return m_statsByStrength[GetStrengthIndex(strength)].WinRate;
}

//+------------------------------------------------------------------+
//| Melhor hora de trading                                           |
//+------------------------------------------------------------------+
double CStats::GetBestTradingHour()
{
   double bestWinRate = 0;
   int bestHour = -1;
   int minTrades = 5; // Mínimo de trades para considerar
   
   for(int i = 0; i < 24; i++)
   {
      if(m_statsByHour[i].TotalTrades >= minTrades && m_statsByHour[i].WinRate > bestWinRate)
      {
         bestWinRate = m_statsByHour[i].WinRate;
         bestHour = i;
      }
   }
   
   return bestHour;
}

//+------------------------------------------------------------------+
//| Melhor dia de trading                                            |
//+------------------------------------------------------------------+
int CStats::GetBestTradingDay()
{
   double bestWinRate = 0;
   int bestDay = -1;
   int minTrades = 3;
   
   for(int i = 0; i < 7; i++)
   {
      if(m_statsByDay[i].TotalTrades >= minTrades && m_statsByDay[i].WinRate > bestWinRate)
      {
         bestWinRate = m_statsByDay[i].WinRate;
         bestDay = i;
      }
   }
   
   return bestDay;
}

//+------------------------------------------------------------------+
//| Melhor força de sinal                                            |
//+------------------------------------------------------------------+
int CStats::GetBestStrength()
{
   double bestPF = 0;
   int bestStrength = 4; // Default F4
   
   for(int i = 0; i < 3; i++)
   {
      if(m_statsByStrength[i].TotalTrades >= 3 && m_statsByStrength[i].ProfitFactor > bestPF)
      {
         bestPF = m_statsByStrength[i].ProfitFactor;
         bestStrength = i + 3; // F3, F4, F5
      }
   }
   
   return bestStrength;
}

//+------------------------------------------------------------------+
//| Melhor sessão                                                    |
//+------------------------------------------------------------------+
string CStats::GetBestSession()
{
   double bestPF = 0;
   int bestIdx = 2; // Default NY
   
   for(int i = 0; i < 3; i++)
   {
      if(m_statsBySession[i].TotalTrades >= 3 && m_statsBySession[i].ProfitFactor > bestPF)
      {
         bestPF = m_statsBySession[i].ProfitFactor;
         bestIdx = i;
      }
   }
   
   string sessions[3] = {"Asia", "London", "NewYork"};
   return sessions[bestIdx];
}

//+------------------------------------------------------------------+
//| Gerar relatório                                                  |
//+------------------------------------------------------------------+
string CStats::GenerateReport()
{
   string report = "";
   string separator = "================================================\n";
   
   report += separator;
   report += "       FGM TREND RIDER - RELATÓRIO GERAL\n";
   report += separator;
   report += StringFormat("Símbolo: %s | Magic: %d\n", Symbol(), m_magicNumber);
   report += StringFormat("Data: %s\n", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));
   report += separator;
   
   //--- Estatísticas gerais
   report += "\n[PERFORMANCE GERAL]\n";
   report += StringFormat("Total Trades: %d\n", m_statsOverall.TotalTrades);
   report += StringFormat("Vitórias: %d (%.1f%%)\n", m_statsOverall.Wins, m_statsOverall.WinRate);
   report += StringFormat("Derrotas: %d\n", m_statsOverall.Losses);
   report += StringFormat("Lucro Total: %.2f\n", m_statsOverall.TotalProfit);
   report += StringFormat("Profit Factor: %.2f\n", m_statsOverall.ProfitFactor);
   report += StringFormat("Expected Payoff: %.2f\n", m_statsOverall.ExpectedPayoff);
   report += StringFormat("Média Vitória: %.2f\n", m_statsOverall.AverageWin);
   report += StringFormat("Média Derrota: %.2f\n", m_statsOverall.AverageLoss);
   report += StringFormat("Máx Consec Wins: %d\n", m_statsOverall.MaxConsecWins);
   report += StringFormat("Máx Consec Losses: %d\n", m_statsOverall.MaxConsecLosses);
   
   //--- Por força de sinal
   if(m_trackByStrength)
   {
      report += "\n[POR FORÇA DE SINAL]\n";
      string strengths[3] = {"F3", "F4", "F5"};
      for(int i = 0; i < 3; i++)
      {
         if(m_statsByStrength[i].TotalTrades > 0)
         {
            report += StringFormat("%s: %d trades | WR: %.1f%% | PF: %.2f | Lucro: %.2f\n",
                                  strengths[i],
                                  m_statsByStrength[i].TotalTrades,
                                  m_statsByStrength[i].WinRate,
                                  m_statsByStrength[i].ProfitFactor,
                                  m_statsByStrength[i].TotalProfit);
         }
      }
   }
   
   //--- Por sessão
   if(m_trackBySession)
   {
      report += "\n[POR SESSÃO]\n";
      string sessions[3] = {"Asia", "London", "NewYork"};
      for(int i = 0; i < 3; i++)
      {
         if(m_statsBySession[i].TotalTrades > 0)
         {
            report += StringFormat("%s: %d trades | WR: %.1f%% | PF: %.2f | Lucro: %.2f\n",
                                  sessions[i],
                                  m_statsBySession[i].TotalTrades,
                                  m_statsBySession[i].WinRate,
                                  m_statsBySession[i].ProfitFactor,
                                  m_statsBySession[i].TotalProfit);
         }
      }
   }
   
   //--- Por dia da semana
   if(m_trackByDay)
   {
      report += "\n[POR DIA DA SEMANA]\n";
      string days[7] = {"Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"};
      for(int i = 0; i < 7; i++)
      {
         if(m_statsByDay[i].TotalTrades > 0)
         {
            report += StringFormat("%s: %d trades | WR: %.1f%% | Lucro: %.2f\n",
                                  days[i],
                                  m_statsByDay[i].TotalTrades,
                                  m_statsByDay[i].WinRate,
                                  m_statsByDay[i].TotalProfit);
         }
      }
   }
   
   //--- Melhores condições
   report += "\n[MELHORES CONDIÇÕES]\n";
   report += StringFormat("Melhor Força: F%d\n", GetBestStrength());
   report += StringFormat("Melhor Sessão: %s\n", GetBestSession());
   
   int bestDay = GetBestTradingDay();
   if(bestDay >= 0)
   {
      string days[7] = {"Domingo", "Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado"};
      report += StringFormat("Melhor Dia: %s\n", days[bestDay]);
   }
   
   double bestHour = GetBestTradingHour();
   if(bestHour >= 0)
      report += StringFormat("Melhor Hora: %02d:00\n", (int)bestHour);
   
   report += separator;
   
   return report;
}

//+------------------------------------------------------------------+
//| Gerar relatório diário                                           |
//+------------------------------------------------------------------+
string CStats::GenerateDailyReport(datetime date)
{
   MqlDateTime targetDt;
   TimeToStruct(date, targetDt);
   
   int tradesCount = 0;
   double totalProfit = 0;
   int wins = 0;
   
   for(int i = 0; i < m_tradesCount; i++)
   {
      MqlDateTime tradeDt;
      TimeToStruct(m_trades[i].OpenTime, tradeDt);
      
      if(tradeDt.year == targetDt.year && 
         tradeDt.mon == targetDt.mon && 
         tradeDt.day == targetDt.day)
      {
         tradesCount++;
         totalProfit += m_trades[i].Profit;
         if(m_trades[i].IsWin) wins++;
      }
   }
   
   double winRate = (tradesCount > 0) ? ((double)wins / tradesCount * 100) : 0;
   
   string report = StringFormat("RELATÓRIO DIÁRIO - %s\n", TimeToString(date, TIME_DATE));
   report += StringFormat("Trades: %d | Wins: %d | WR: %.1f%% | Lucro: %.2f\n",
                         tradesCount, wins, winRate, totalProfit);
   
   return report;
}

//+------------------------------------------------------------------+
//| Gerar relatório semanal                                          |
//+------------------------------------------------------------------+
string CStats::GenerateWeeklyReport()
{
   datetime weekStart = TimeCurrent() - (TimeCurrent() % 604800); // Início da semana
   
   int tradesCount = 0;
   double totalProfit = 0;
   int wins = 0;
   
   for(int i = 0; i < m_tradesCount; i++)
   {
      if(m_trades[i].OpenTime >= weekStart)
      {
         tradesCount++;
         totalProfit += m_trades[i].Profit;
         if(m_trades[i].IsWin) wins++;
      }
   }
   
   double winRate = (tradesCount > 0) ? ((double)wins / tradesCount * 100) : 0;
   
   string report = "RELATÓRIO SEMANAL\n";
   report += StringFormat("Período: %s até agora\n", TimeToString(weekStart, TIME_DATE));
   report += StringFormat("Trades: %d | Wins: %d | WR: %.1f%% | Lucro: %.2f\n",
                         tradesCount, wins, winRate, totalProfit);
   
   return report;
}

//+------------------------------------------------------------------+
//| Imprimir relatório                                               |
//+------------------------------------------------------------------+
void CStats::PrintReport()
{
   Print(GenerateReport());
}

//+------------------------------------------------------------------+
//| Exportar estatísticas                                            |
//+------------------------------------------------------------------+
void CStats::ExportStats()
{
   if(!m_exportToFile)
      return;
   
   //--- Criar arquivo CSV
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   string csvFileName = StringFormat("%s_Stats_%04d%02d%02d_%s.csv",
                                     m_exportPath,
                                     dt.year, dt.mon, dt.day,
                                     Symbol());
   
   int handle = FileOpen(csvFileName, FILE_WRITE|FILE_CSV, ';');
   
   if(handle == INVALID_HANDLE)
   {
      LogError(StringFormat("Erro ao criar arquivo CSV: %d", GetLastError()));
      return;
   }
   
   //--- Cabeçalho
   FileWrite(handle, "OpenTime", "CloseTime", "Symbol", "Type", "Entry", "Exit", 
             "Volume", "Profit", "ProfitPips", "Duration", "Strength", 
             "Session", "DayOfWeek", "Hour", "CloseReason", "Result");
   
   //--- Dados
   for(int i = 0; i < m_tradesCount; i++)
   {
      FileWrite(handle,
               TimeToString(m_trades[i].OpenTime, TIME_DATE|TIME_SECONDS),
               TimeToString(m_trades[i].CloseTime, TIME_DATE|TIME_SECONDS),
               m_trades[i].Symbol,
               (m_trades[i].OrderType == ORDER_TYPE_BUY) ? "BUY" : "SELL",
               DoubleToString(m_trades[i].EntryPrice, 5),
               DoubleToString(m_trades[i].ExitPrice, 5),
               DoubleToString(m_trades[i].Volume, 2),
               DoubleToString(m_trades[i].Profit, 2),
               DoubleToString(m_trades[i].ProfitPips, 1),
               IntegerToString(m_trades[i].Duration),
               IntegerToString(m_trades[i].SignalStrength),
               m_trades[i].Session,
               IntegerToString(m_trades[i].DayOfWeek),
               IntegerToString(m_trades[i].EntryHour),
               m_trades[i].CloseReason,
               m_trades[i].IsWin ? "WIN" : "LOSS");
   }
   
   FileClose(handle);
   LogNormal(StringFormat("Estatísticas exportadas para: %s", csvFileName));
}

//+------------------------------------------------------------------+
//| Reset de todas as estatísticas                                   |
//+------------------------------------------------------------------+
void CStats::ResetStats()
{
   ArrayFree(m_trades);
   m_tradesCount = 0;
   m_currentConsecWins = 0;
   m_currentConsecLosses = 0;
   
   m_statsOverall.Reset();
   for(int i = 0; i < 7; i++)  m_statsByDay[i].Reset();
   for(int i = 0; i < 24; i++) m_statsByHour[i].Reset();
   for(int i = 0; i < 3; i++)  m_statsByStrength[i].Reset();
   for(int i = 0; i < 3; i++)  m_statsBySession[i].Reset();
   
   LogNormal("Estatísticas resetadas");
}

//+------------------------------------------------------------------+
//| Reset de estatísticas diárias                                    |
//+------------------------------------------------------------------+
void CStats::ResetDailyStats()
{
   // Manter trades históricos mas zerar contadores de sequência diária
   m_currentConsecWins = 0;
   m_currentConsecLosses = 0;
   
   LogNormal("Contadores diários resetados");
}

#endif // CSTATS_MQH
//+------------------------------------------------------------------+
