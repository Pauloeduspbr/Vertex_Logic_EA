//+------------------------------------------------------------------+
//|                                                 CTradeEngine.mqh |
//|                                 Copyright 2025, Pauloeduspbr     |
//|                      FGM Trend Rider - Versão Platina Final      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Pauloeduspbr"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include "CAssetSpecs.mqh"

//+------------------------------------------------------------------+
//| Estrutura de dados da posição                                    |
//+------------------------------------------------------------------+
struct PositionData
{
   ulong    ticket;              // Ticket da posição
   string   symbol;              // Símbolo
   int      type;                // POSITION_TYPE_BUY ou SELL
   double   volume;              // Volume atual
   double   priceOpen;           // Preço de abertura
   double   priceCurrent;        // Preço atual
   double   sl;                  // Stop Loss
   double   tp;                  // Take Profit
   double   profit;              // Lucro/Prejuízo
   double   swap;                // Swap
   datetime timeOpen;            // Tempo de abertura
   long     magic;               // Magic number
   string   comment;             // Comentário
   
   //--- Dados adicionais para gestão
   double   originalVolume;      // Volume original
   double   tp1Price;            // Preço do TP1
   double   tp2Price;            // Preço do TP2
   double   bePrice;             // Preço do break-even
   bool     tp1Hit;              // TP1 foi atingido
   bool     tp2Hit;              // TP2 foi atingido
   bool     beActivated;         // Break-even ativado
   int      trailingMode;        // Modo de trailing ativo
};

//+------------------------------------------------------------------+
//| Enumeração de modo de trailing                                   |
//+------------------------------------------------------------------+
enum ENUM_TRAILING_MODE
{
   TRAIL_NONE,        // Sem trailing
   TRAIL_FIXED,       // Distância fixa
   TRAIL_ATR,         // Baseado em ATR
   TRAIL_EMA8,        // Seguir EMA8
   TRAIL_EMA21,       // Seguir EMA21
   TRAIL_EMA50        // Seguir EMA50
};

//+------------------------------------------------------------------+
//| Estrutura de resultado de operação                               |
//+------------------------------------------------------------------+
struct TradeResult
{
   bool     success;             // Operação bem-sucedida
   ulong    ticket;              // Ticket (se aplicável)
   uint     retcode;             // Código de retorno
   string   retcodeDesc;         // Descrição do código
   string   message;             // Mensagem adicional
   double   price;               // Preço executado
   double   volume;              // Volume executado
};

//+------------------------------------------------------------------+
//| Classe de Engine de Trade                                        |
//+------------------------------------------------------------------+
class CTradeEngine
{
private:
   CTrade            m_trade;            // Objeto de trade
   CPositionInfo     m_position;         // Objeto de posição
   CAssetSpecs*      m_asset;            // Especificações do ativo
   
   bool              m_initialized;      // Flag de inicialização
   string            m_lastError;        // Último erro
   long              m_magicNumber;      // Magic number
   string            m_comment;          // Comentário das ordens
   int               m_slippage;         // Slippage máximo
   int               m_maxRetries;       // Tentativas máximas
   
   //--- Dados da posição atual
   PositionData      m_currentPos;       // Dados da posição atual
   bool              m_hasPosition;      // Tem posição aberta
   
   //--- Métodos privados
   void              UpdatePositionData();
   TradeResult       ProcessResult(bool success, const MqlTradeResult& result, string operation);
   string            GetRetcodeDescription(uint retcode);
   bool              WaitForPosition(ulong ticket, int timeoutMs = 1000);
   
public:
                     CTradeEngine();
                    ~CTradeEngine();
   
   //--- Inicialização
   bool              Init(CAssetSpecs* asset, long magic, string comment = "FGM_TR", int slippage = 10);
   void              Deinit();
   bool              IsInitialized() { return m_initialized; }
   string            GetLastError() { return m_lastError; }
   
   //--- Configuração
   void              SetMagicNumber(long magic) { m_magicNumber = magic; m_trade.SetExpertMagicNumber(magic); }
   void              SetComment(string comment) { m_comment = comment; }
   void              SetSlippage(int slippage) { m_slippage = slippage; m_trade.SetDeviationInPoints(slippage); }
   void              SetMaxRetries(int retries) { m_maxRetries = retries; }
   long              GetMagicNumber() { return m_magicNumber; }
   
   //--- Verificação de posição
   bool              HasPosition();
   bool              HasPositionByMagic(long magic);
   int               CountPositions();
   int               CountPositionsByMagic(long magic);
   PositionData      GetPositionData();
   bool              IsLong();
   bool              IsShort();
   double            GetPositionVolume();
   double            GetPositionProfit();
   
   //--- Abertura de posição
   TradeResult       OpenBuy(double volume, double sl, double tp, string comment = "");
   TradeResult       OpenSell(double volume, double sl, double tp, string comment = "");
   TradeResult       OpenPosition(bool isBuy, double volume, double sl, double tp, string comment = "");
   
   //--- Fechamento de posição
   TradeResult       ClosePosition();
   TradeResult       ClosePositionPartial(double volumeToClose);
   TradeResult       ClosePositionPercent(int percent);
   TradeResult       CloseAllByMagic(long magic);
   
   //--- Modificação de posição
   TradeResult       ModifySL(double newSL);
   TradeResult       ModifyTP(double newTP);
   TradeResult       ModifySLTP(double newSL, double newTP);
   
   //--- Break-even
   bool              MoveToBreakeven(double offset = 0);
   bool              ShouldMoveToBreakeven(double triggerPrice);
   
   //--- Trailing Stop
   bool              UpdateTrailingStop(ENUM_TRAILING_MODE mode, double value);
   bool              TrailingByFixed(double distance, double step);
   bool              TrailingByATR(double atrValue, double multiplier);
   bool              TrailingByEMA(double emaValue, double buffer);
   
   //--- Verificação de TP
   bool              CheckTP1Hit(double tp1Price);
   bool              CheckTP2Hit(double tp2Price);
   
   //--- Gestão de dados da posição
   void              SetTP1Price(double price) { m_currentPos.tp1Price = price; }
   void              SetTP2Price(double price) { m_currentPos.tp2Price = price; }
   void              SetBEPrice(double price) { m_currentPos.bePrice = price; }
   void              SetOriginalVolume(double vol) { m_currentPos.originalVolume = vol; }
   void              SetTP1Hit(bool hit) { m_currentPos.tp1Hit = hit; }
   void              SetTP2Hit(bool hit) { m_currentPos.tp2Hit = hit; }
   void              SetBEActivated(bool activated) { m_currentPos.beActivated = activated; }
   void              SetTrailingMode(int mode) { m_currentPos.trailingMode = mode; }
   
   bool              IsTP1Hit() { return m_currentPos.tp1Hit; }
   bool              IsTP2Hit() { return m_currentPos.tp2Hit; }
   bool              IsBEActivated() { return m_currentPos.beActivated; }
   double            GetTP1Price() { return m_currentPos.tp1Price; }
   double            GetTP2Price() { return m_currentPos.tp2Price; }
   double            GetBEPrice() { return m_currentPos.bePrice; }
   int               GetTrailingMode() { return m_currentPos.trailingMode; }
   
   //--- Utilitários
   bool              IsTradeAllowed();
   bool              ValidateVolume(double volume);
   double            GetCurrentBid();
   double            GetCurrentAsk();
   
   //--- Debug
   void              PrintPositionInfo();
   void              PrintTradeResult(const TradeResult& result);
};

//+------------------------------------------------------------------+
//| Construtor                                                        |
//+------------------------------------------------------------------+
CTradeEngine::CTradeEngine()
{
   m_asset = NULL;
   m_initialized = false;
   m_lastError = "";
   m_magicNumber = 0;
   m_comment = "FGM_TR";
   m_slippage = 10;
   m_maxRetries = 3;
   m_hasPosition = false;
   
   ZeroMemory(m_currentPos);
}

//+------------------------------------------------------------------+
//| Destrutor                                                         |
//+------------------------------------------------------------------+
CTradeEngine::~CTradeEngine()
{
   Deinit();
}

//+------------------------------------------------------------------+
//| Inicialização                                                     |
//+------------------------------------------------------------------+
bool CTradeEngine::Init(CAssetSpecs* asset, long magic, string comment = "FGM_TR", int slippage = 10)
{
   if(asset == NULL || !asset.IsInitialized())
   {
      m_lastError = "CAssetSpecs inválido ou não inicializado";
      return false;
   }
   
   m_asset = asset;
   m_magicNumber = magic;
   m_comment = comment;
   m_slippage = slippage;
   
   //--- Configurar objeto de trade
   m_trade.SetExpertMagicNumber(magic);
   m_trade.SetDeviationInPoints(slippage);
   m_trade.SetTypeFilling(ORDER_FILLING_FOK);
   m_trade.SetTypeFillingBySymbol(m_asset.GetSymbol());
   
   //--- Verificar se tem posição aberta
   m_hasPosition = HasPosition();
   if(m_hasPosition)
      UpdatePositionData();
   
   m_initialized = true;
   Print("CTradeEngine: Inicializado. Magic: ", magic, " | Symbol: ", m_asset.GetSymbol());
   
   return true;
}

//+------------------------------------------------------------------+
//| Deinicialização                                                   |
//+------------------------------------------------------------------+
void CTradeEngine::Deinit()
{
   m_initialized = false;
}

//+------------------------------------------------------------------+
//| Verificar se tem posição aberta                                  |
//+------------------------------------------------------------------+
bool CTradeEngine::HasPosition()
{
   if(!m_initialized || m_asset == NULL)
      return false;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == m_asset.GetSymbol() && 
            m_position.Magic() == m_magicNumber)
         {
            m_hasPosition = true;
            return true;
         }
      }
   }
   
   m_hasPosition = false;
   return false;
}

//+------------------------------------------------------------------+
//| Verificar se tem posição por magic number                        |
//+------------------------------------------------------------------+
bool CTradeEngine::HasPositionByMagic(long magic)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Magic() == magic)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Contar posições                                                  |
//+------------------------------------------------------------------+
int CTradeEngine::CountPositions()
{
   if(!m_initialized || m_asset == NULL)
      return 0;
   
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == m_asset.GetSymbol())
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Contar posições por magic                                        |
//+------------------------------------------------------------------+
int CTradeEngine::CountPositionsByMagic(long magic)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Magic() == magic)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Atualizar dados da posição                                       |
//+------------------------------------------------------------------+
void CTradeEngine::UpdatePositionData()
{
   if(!m_initialized || m_asset == NULL)
      return;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == m_asset.GetSymbol() && 
            m_position.Magic() == m_magicNumber)
         {
            m_currentPos.ticket = m_position.Ticket();
            m_currentPos.symbol = m_position.Symbol();
            m_currentPos.type = (int)m_position.PositionType();
            m_currentPos.volume = m_position.Volume();
            m_currentPos.priceOpen = m_position.PriceOpen();
            m_currentPos.priceCurrent = m_position.PriceCurrent();
            m_currentPos.sl = m_position.StopLoss();
            m_currentPos.tp = m_position.TakeProfit();
            m_currentPos.profit = m_position.Profit();
            m_currentPos.swap = m_position.Swap();
            m_currentPos.timeOpen = m_position.Time();
            m_currentPos.magic = m_position.Magic();
            m_currentPos.comment = m_position.Comment();
            
            m_hasPosition = true;
            return;
         }
      }
   }
   
   m_hasPosition = false;
}

//+------------------------------------------------------------------+
//| Obter dados da posição                                           |
//+------------------------------------------------------------------+
PositionData CTradeEngine::GetPositionData()
{
   UpdatePositionData();
   return m_currentPos;
}

//+------------------------------------------------------------------+
//| Verificar se é compra                                            |
//+------------------------------------------------------------------+
bool CTradeEngine::IsLong()
{
   if(!HasPosition())
      return false;
   
   UpdatePositionData();
   return (m_currentPos.type == POSITION_TYPE_BUY);
}

//+------------------------------------------------------------------+
//| Verificar se é venda                                             |
//+------------------------------------------------------------------+
bool CTradeEngine::IsShort()
{
   if(!HasPosition())
      return false;
   
   UpdatePositionData();
   return (m_currentPos.type == POSITION_TYPE_SELL);
}

//+------------------------------------------------------------------+
//| Obter volume da posição                                          |
//+------------------------------------------------------------------+
double CTradeEngine::GetPositionVolume()
{
   if(!HasPosition())
      return 0;
   
   UpdatePositionData();
   return m_currentPos.volume;
}

//+------------------------------------------------------------------+
//| Obter lucro da posição                                           |
//+------------------------------------------------------------------+
double CTradeEngine::GetPositionProfit()
{
   if(!HasPosition())
      return 0;
   
   UpdatePositionData();
   return m_currentPos.profit;
}

//+------------------------------------------------------------------+
//| Abrir posição de compra                                          |
//+------------------------------------------------------------------+
TradeResult CTradeEngine::OpenBuy(double volume, double sl, double tp, string comment = "")
{
   return OpenPosition(true, volume, sl, tp, comment);
}

//+------------------------------------------------------------------+
//| Abrir posição de venda                                           |
//+------------------------------------------------------------------+
TradeResult CTradeEngine::OpenSell(double volume, double sl, double tp, string comment = "")
{
   return OpenPosition(false, volume, sl, tp, comment);
}

//+------------------------------------------------------------------+
//| Abrir posição                                                    |
//+------------------------------------------------------------------+
TradeResult CTradeEngine::OpenPosition(bool isBuy, double volume, double sl, double tp, string comment = "")
{
   TradeResult result;
   ZeroMemory(result);
   result.success = false;
   
   if(!m_initialized || m_asset == NULL)
   {
      result.message = "TradeEngine não inicializado";
      return result;
   }
   
   if(!IsTradeAllowed())
   {
      result.message = "Trading não permitido";
      return result;
   }
   
   //--- Validar volume
   volume = m_asset.NormalizeLot(volume);
   if(!ValidateVolume(volume))
   {
      result.message = "Volume inválido: " + DoubleToString(volume, 2);
      return result;
   }
   
   //--- Normalizar preços
   sl = m_asset.NormalizeSL(sl, isBuy);
   if(tp > 0)
      tp = m_asset.NormalizeTP(tp, isBuy);
   
   //--- Obter preço
   double price = isBuy ? GetCurrentAsk() : GetCurrentBid();
   
   //--- Definir comentário
   string orderComment = (comment != "") ? comment : m_comment;
   
   //--- Tentar executar com retries
   bool success = false;
   MqlTradeResult tradeResult;
   
   for(int attempt = 1; attempt <= m_maxRetries; attempt++)
   {
      if(isBuy)
         success = m_trade.Buy(volume, m_asset.GetSymbol(), price, sl, tp, orderComment);
      else
         success = m_trade.Sell(volume, m_asset.GetSymbol(), price, sl, tp, orderComment);
      
      if(m_trade.ResultRetcode() == TRADE_RETCODE_DONE)
      {
         m_trade.Result(tradeResult);
         success = true;
         break;
      }
      
      //--- Log tentativa
      Print("CTradeEngine: Tentativa ", attempt, "/", m_maxRetries, 
            " - Código: ", m_trade.ResultRetcode(), 
            " - ", GetRetcodeDescription(m_trade.ResultRetcode()));
      
      //--- Aguardar antes de próxima tentativa
      if(attempt < m_maxRetries)
         Sleep(500);
   }
   
   //--- Processar resultado
   MqlTradeResult finalResult;
   m_trade.Result(finalResult);
   result = ProcessResult(success, finalResult, isBuy ? "BUY" : "SELL");
   
   //--- Se sucesso, atualizar dados
   if(result.success)
   {
      //--- Aguardar posição ser registrada
      if(WaitForPosition(result.ticket, 1000))
      {
         UpdatePositionData();
         m_currentPos.originalVolume = volume;
         m_currentPos.tp1Hit = false;
         m_currentPos.tp2Hit = false;
         m_currentPos.beActivated = false;
         m_currentPos.trailingMode = TRAIL_NONE;
      }
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Fechar posição                                                   |
//+------------------------------------------------------------------+
TradeResult CTradeEngine::ClosePosition()
{
   TradeResult result;
   ZeroMemory(result);
   result.success = false;
   
   if(!m_initialized || m_asset == NULL)
   {
      result.message = "TradeEngine não inicializado";
      return result;
   }
   
   if(!HasPosition())
   {
      result.message = "Sem posição aberta";
      return result;
   }
   
   UpdatePositionData();
   
   //--- Fechar posição
   bool success = m_trade.PositionClose(m_currentPos.ticket);
   
   MqlTradeResult closeResult;
   m_trade.Result(closeResult);
   result = ProcessResult(success, closeResult, "CLOSE");
   
   if(result.success)
   {
      m_hasPosition = false;
      ZeroMemory(m_currentPos);
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Fechar posição parcialmente                                      |
//+------------------------------------------------------------------+
TradeResult CTradeEngine::ClosePositionPartial(double volumeToClose)
{
   TradeResult result;
   ZeroMemory(result);
   result.success = false;
   
   if(!m_initialized || m_asset == NULL)
   {
      result.message = "TradeEngine não inicializado";
      return result;
   }
   
   if(!HasPosition())
   {
      result.message = "Sem posição aberta";
      return result;
   }
   
   UpdatePositionData();
   
   //--- Validar volume
   volumeToClose = m_asset.NormalizeLot(volumeToClose);
   if(volumeToClose <= 0)
   {
      result.message = "Volume para fechar inválido";
      return result;
   }
   
   if(volumeToClose >= m_currentPos.volume)
   {
      //--- Fechar tudo
      return ClosePosition();
   }
   
   //--- Verificar volume mínimo restante
   double remainingVolume = m_currentPos.volume - volumeToClose;
   if(remainingVolume < m_asset.GetVolumeMin())
   {
      //--- Fechar tudo se restante for menor que mínimo
      return ClosePosition();
   }
   
   //--- Fechar parcial
   bool success = m_trade.PositionClosePartial(m_currentPos.ticket, volumeToClose);
   
   MqlTradeResult partialResult;
   m_trade.Result(partialResult);
   result = ProcessResult(success, partialResult, "PARTIAL_CLOSE");
   
   if(result.success)
   {
      //--- Aguardar atualização
      Sleep(100);
      UpdatePositionData();
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Fechar percentual da posição                                     |
//+------------------------------------------------------------------+
TradeResult CTradeEngine::ClosePositionPercent(int percent)
{
   TradeResult result;
   ZeroMemory(result);
   result.success = false;
   
   if(percent <= 0 || percent > 100)
   {
      result.message = "Percentual inválido";
      return result;
   }
   
   if(!HasPosition())
   {
      result.message = "Sem posição aberta";
      return result;
   }
   
   UpdatePositionData();
   
   double volumeToClose = m_currentPos.volume * (percent / 100.0);
   volumeToClose = m_asset.NormalizeLot(volumeToClose);
   
   return ClosePositionPartial(volumeToClose);
}

//+------------------------------------------------------------------+
//| Fechar todas posições por magic                                  |
//+------------------------------------------------------------------+
TradeResult CTradeEngine::CloseAllByMagic(long magic)
{
   TradeResult result;
   ZeroMemory(result);
   result.success = true;
   
   int closed = 0;
   int errors = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Magic() == magic)
         {
            if(m_trade.PositionClose(m_position.Ticket()))
               closed++;
            else
               errors++;
         }
      }
   }
   
   result.message = StringFormat("Fechadas: %d | Erros: %d", closed, errors);
   result.success = (errors == 0);
   
   return result;
}

//+------------------------------------------------------------------+
//| Modificar SL                                                     |
//+------------------------------------------------------------------+
TradeResult CTradeEngine::ModifySL(double newSL)
{
   TradeResult result;
   ZeroMemory(result);
   result.success = false;
   
   if(!m_initialized || m_asset == NULL)
   {
      result.message = "TradeEngine não inicializado";
      return result;
   }
   
   if(!HasPosition())
   {
      result.message = "Sem posição aberta";
      return result;
   }
   
   UpdatePositionData();
   
   //--- Normalizar SL
   bool isBuy = (m_currentPos.type == POSITION_TYPE_BUY);
   newSL = m_asset.NormalizeSL(newSL, isBuy);
   
   //--- Verificar se é melhor que o atual
   if(isBuy)
   {
      if(newSL <= m_currentPos.sl && m_currentPos.sl > 0)
      {
         result.message = "Novo SL não é melhor que o atual";
         return result;
      }
   }
   else
   {
      if(newSL >= m_currentPos.sl && m_currentPos.sl > 0)
      {
         result.message = "Novo SL não é melhor que o atual";
         return result;
      }
   }
   
   //--- Modificar
   bool success = m_trade.PositionModify(m_currentPos.ticket, newSL, m_currentPos.tp);
   
   MqlTradeResult modifySLResult;
   m_trade.Result(modifySLResult);
   result = ProcessResult(success, modifySLResult, "MODIFY_SL");
   
   if(result.success)
      UpdatePositionData();
   
   return result;
}

//+------------------------------------------------------------------+
//| Modificar TP                                                     |
//+------------------------------------------------------------------+
TradeResult CTradeEngine::ModifyTP(double newTP)
{
   TradeResult result;
   ZeroMemory(result);
   result.success = false;
   
   if(!m_initialized || m_asset == NULL)
   {
      result.message = "TradeEngine não inicializado";
      return result;
   }
   
   if(!HasPosition())
   {
      result.message = "Sem posição aberta";
      return result;
   }
   
   UpdatePositionData();
   
   //--- Normalizar TP
   bool isBuy = (m_currentPos.type == POSITION_TYPE_BUY);
   if(newTP > 0)
      newTP = m_asset.NormalizeTP(newTP, isBuy);
   
   //--- Modificar
   bool success = m_trade.PositionModify(m_currentPos.ticket, m_currentPos.sl, newTP);
   
   MqlTradeResult modifyTPResult;
   m_trade.Result(modifyTPResult);
   result = ProcessResult(success, modifyTPResult, "MODIFY_TP");
   
   if(result.success)
      UpdatePositionData();
   
   return result;
}

//+------------------------------------------------------------------+
//| Modificar SL e TP                                                |
//+------------------------------------------------------------------+
TradeResult CTradeEngine::ModifySLTP(double newSL, double newTP)
{
   TradeResult result;
   ZeroMemory(result);
   result.success = false;
   
   if(!m_initialized || m_asset == NULL)
   {
      result.message = "TradeEngine não inicializado";
      return result;
   }
   
   if(!HasPosition())
   {
      result.message = "Sem posição aberta";
      return result;
   }
   
   UpdatePositionData();
   
   //--- Normalizar preços
   bool isBuy = (m_currentPos.type == POSITION_TYPE_BUY);
   newSL = m_asset.NormalizeSL(newSL, isBuy);
   if(newTP > 0)
      newTP = m_asset.NormalizeTP(newTP, isBuy);
   
   //--- Modificar
   bool success = m_trade.PositionModify(m_currentPos.ticket, newSL, newTP);
   
   MqlTradeResult modifySLTPResult;
   m_trade.Result(modifySLTPResult);
   result = ProcessResult(success, modifySLTPResult, "MODIFY_SLTP");
   
   if(result.success)
      UpdatePositionData();
   
   return result;
}

//+------------------------------------------------------------------+
//| Mover para break-even                                            |
//+------------------------------------------------------------------+
bool CTradeEngine::MoveToBreakeven(double offset = 0)
{
   if(!m_initialized || m_asset == NULL || !HasPosition())
      return false;
   
   UpdatePositionData();
   
   //--- Calcular preço do BE
   double bePrice = m_currentPos.priceOpen;
   bool isBuy = (m_currentPos.type == POSITION_TYPE_BUY);
   
   if(offset > 0)
   {
      double offsetPrice = offset * m_asset.GetPointValue();
      if(isBuy)
         bePrice = bePrice + offsetPrice;
      else
         bePrice = bePrice - offsetPrice;
   }
   
   //--- Verificar se faz sentido
   double currentPrice = isBuy ? GetCurrentBid() : GetCurrentAsk();
   
   if(isBuy)
   {
      //--- Para compra, preço deve estar acima do BE
      if(currentPrice <= bePrice)
         return false;
      
      //--- SL atual já está no BE ou melhor?
      if(m_currentPos.sl >= bePrice && m_currentPos.sl > 0)
         return true; // Já está em BE
   }
   else
   {
      //--- Para venda, preço deve estar abaixo do BE
      if(currentPrice >= bePrice)
         return false;
      
      //--- SL atual já está no BE ou melhor?
      if(m_currentPos.sl <= bePrice && m_currentPos.sl > 0)
         return true; // Já está em BE
   }
   
   //--- Normalizar e modificar
   bePrice = m_asset.NormalizeSL(bePrice, isBuy);
   TradeResult result = ModifySL(bePrice);
   
   if(result.success)
   {
      m_currentPos.beActivated = true;
      Print("CTradeEngine: Break-even ativado em ", DoubleToString(bePrice, _Digits));
   }
   
   return result.success;
}

//+------------------------------------------------------------------+
//| Verificar se deve mover para break-even                          |
//+------------------------------------------------------------------+
bool CTradeEngine::ShouldMoveToBreakeven(double triggerPrice)
{
   if(!HasPosition())
      return false;
   
   UpdatePositionData();
   
   bool isBuy = (m_currentPos.type == POSITION_TYPE_BUY);
   double currentPrice = isBuy ? GetCurrentBid() : GetCurrentAsk();
   
   if(isBuy)
      return (currentPrice >= triggerPrice);
   else
      return (currentPrice <= triggerPrice);
}

//+------------------------------------------------------------------+
//| Atualizar trailing stop                                          |
//+------------------------------------------------------------------+
bool CTradeEngine::UpdateTrailingStop(ENUM_TRAILING_MODE mode, double value)
{
   if(!m_initialized || m_asset == NULL || !HasPosition())
      return false;
   
   switch(mode)
   {
      case TRAIL_FIXED:
         return TrailingByFixed(value, value * 0.2); // Step = 20% da distância
         
      case TRAIL_ATR:
         return TrailingByATR(value, 1.5);
         
      case TRAIL_EMA8:
      case TRAIL_EMA21:
      case TRAIL_EMA50:
         return TrailingByEMA(value, m_asset.GetPointValue() * 5); // Buffer de 5 pontos
         
      default:
         return false;
   }
}

//+------------------------------------------------------------------+
//| Trailing por distância fixa                                      |
//+------------------------------------------------------------------+
bool CTradeEngine::TrailingByFixed(double distance, double step)
{
   if(!HasPosition())
      return false;
   
   UpdatePositionData();
   
   bool isBuy = (m_currentPos.type == POSITION_TYPE_BUY);
   double currentPrice = isBuy ? GetCurrentBid() : GetCurrentAsk();
   
   double newSL;
   if(isBuy)
   {
      newSL = currentPrice - distance;
      
      //--- Só move se for melhor
      if(m_currentPos.sl > 0 && newSL <= m_currentPos.sl + step)
         return false;
   }
   else
   {
      newSL = currentPrice + distance;
      
      //--- Só move se for melhor
      if(m_currentPos.sl > 0 && newSL >= m_currentPos.sl - step)
         return false;
   }
   
   TradeResult result = ModifySL(newSL);
   return result.success;
}

//+------------------------------------------------------------------+
//| Trailing por ATR                                                 |
//+------------------------------------------------------------------+
bool CTradeEngine::TrailingByATR(double atrValue, double multiplier)
{
   if(!HasPosition() || atrValue <= 0)
      return false;
   
   double distance = atrValue * multiplier;
   return TrailingByFixed(distance, atrValue * 0.3);
}

//+------------------------------------------------------------------+
//| Trailing por EMA                                                 |
//+------------------------------------------------------------------+
bool CTradeEngine::TrailingByEMA(double emaValue, double buffer)
{
   if(!HasPosition() || emaValue <= 0)
      return false;
   
   UpdatePositionData();
   
   bool isBuy = (m_currentPos.type == POSITION_TYPE_BUY);
   double currentPrice = isBuy ? GetCurrentBid() : GetCurrentAsk();
   
   double newSL;
   if(isBuy)
   {
      //--- SL abaixo da EMA
      newSL = emaValue - buffer;
      
      //--- Verificar se preço está acima da EMA
      if(currentPrice < emaValue)
         return false;
      
      //--- Só move se for melhor
      if(m_currentPos.sl > 0 && newSL <= m_currentPos.sl)
         return false;
   }
   else
   {
      //--- SL acima da EMA
      newSL = emaValue + buffer;
      
      //--- Verificar se preço está abaixo da EMA
      if(currentPrice > emaValue)
         return false;
      
      //--- Só move se for melhor
      if(m_currentPos.sl > 0 && newSL >= m_currentPos.sl)
         return false;
   }
   
   TradeResult result = ModifySL(newSL);
   return result.success;
}

//+------------------------------------------------------------------+
//| Verificar se TP1 foi atingido                                    |
//+------------------------------------------------------------------+
bool CTradeEngine::CheckTP1Hit(double tp1Price)
{
   if(!HasPosition())
      return false;
   
   UpdatePositionData();
   
   bool isBuy = (m_currentPos.type == POSITION_TYPE_BUY);
   double currentPrice = isBuy ? GetCurrentBid() : GetCurrentAsk();
   
   if(isBuy)
      return (currentPrice >= tp1Price);
   else
      return (currentPrice <= tp1Price);
}

//+------------------------------------------------------------------+
//| Verificar se TP2 foi atingido                                    |
//+------------------------------------------------------------------+
bool CTradeEngine::CheckTP2Hit(double tp2Price)
{
   return CheckTP1Hit(tp2Price); // Mesma lógica
}

//+------------------------------------------------------------------+
//| Processar resultado da operação                                  |
//+------------------------------------------------------------------+
TradeResult CTradeEngine::ProcessResult(bool success, const MqlTradeResult& result, string operation)
{
   TradeResult tr;
   ZeroMemory(tr);
   
   tr.success = success && (result.retcode == TRADE_RETCODE_DONE);
   tr.ticket = result.deal > 0 ? result.deal : result.order;
   tr.retcode = result.retcode;
   tr.retcodeDesc = GetRetcodeDescription(result.retcode);
   tr.price = result.price;
   tr.volume = result.volume;
   
   if(tr.success)
   {
      tr.message = StringFormat("%s executado com sucesso. Ticket: %d", operation, tr.ticket);
      Print("CTradeEngine: ", tr.message);
   }
   else
   {
      tr.message = StringFormat("%s falhou. Código: %d - %s", operation, tr.retcode, tr.retcodeDesc);
      m_lastError = tr.message;
      Print("CTradeEngine Error: ", tr.message);
   }
   
   return tr;
}

//+------------------------------------------------------------------+
//| Obter descrição do código de retorno                             |
//+------------------------------------------------------------------+
string CTradeEngine::GetRetcodeDescription(uint retcode)
{
   switch(retcode)
   {
      case TRADE_RETCODE_DONE:            return "Executado";
      case TRADE_RETCODE_REQUOTE:         return "Requote";
      case TRADE_RETCODE_REJECT:          return "Rejeitado";
      case TRADE_RETCODE_CANCEL:          return "Cancelado";
      case TRADE_RETCODE_PLACED:          return "Ordem colocada";
      case TRADE_RETCODE_DONE_PARTIAL:    return "Execução parcial";
      case TRADE_RETCODE_ERROR:           return "Erro";
      case TRADE_RETCODE_TIMEOUT:         return "Timeout";
      case TRADE_RETCODE_INVALID:         return "Requisição inválida";
      case TRADE_RETCODE_INVALID_VOLUME:  return "Volume inválido";
      case TRADE_RETCODE_INVALID_PRICE:   return "Preço inválido";
      case TRADE_RETCODE_INVALID_STOPS:   return "Stops inválidos";
      case TRADE_RETCODE_TRADE_DISABLED:  return "Trade desabilitado";
      case TRADE_RETCODE_MARKET_CLOSED:   return "Mercado fechado";
      case TRADE_RETCODE_NO_MONEY:        return "Saldo insuficiente";
      case TRADE_RETCODE_PRICE_CHANGED:   return "Preço alterado";
      case TRADE_RETCODE_PRICE_OFF:       return "Preço fora do mercado";
      case TRADE_RETCODE_INVALID_EXPIRATION: return "Expiração inválida";
      case TRADE_RETCODE_ORDER_CHANGED:   return "Ordem alterada";
      case TRADE_RETCODE_TOO_MANY_REQUESTS: return "Muitas requisições";
      case TRADE_RETCODE_NO_CHANGES:      return "Sem alterações";
      case TRADE_RETCODE_CONNECTION:      return "Sem conexão";
      case TRADE_RETCODE_FROZEN:          return "Ordem congelada";
      case TRADE_RETCODE_LIMIT_ORDERS:    return "Limite de ordens";
      case TRADE_RETCODE_LIMIT_VOLUME:    return "Limite de volume";
      default:                            return "Código desconhecido";
   }
}

//+------------------------------------------------------------------+
//| Aguardar posição ser registrada                                  |
//+------------------------------------------------------------------+
bool CTradeEngine::WaitForPosition(ulong ticket, int timeoutMs = 1000)
{
   int waited = 0;
   int step = 50;
   
   while(waited < timeoutMs)
   {
      if(HasPosition())
         return true;
      
      Sleep(step);
      waited += step;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Verificar se trading é permitido                                 |
//+------------------------------------------------------------------+
bool CTradeEngine::IsTradeAllowed()
{
   //--- Verificar permissões
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      m_lastError = "Trading não permitido pelo terminal";
      return false;
   }
   
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
   {
      m_lastError = "Trading não permitido pela conta";
      return false;
   }
   
   if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
   {
      m_lastError = "EAs não permitidos na conta";
      return false;
   }
   
   //--- Verificar conexão
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
   {
      m_lastError = "Terminal desconectado";
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Validar volume                                                   |
//+------------------------------------------------------------------+
bool CTradeEngine::ValidateVolume(double volume)
{
   if(!m_initialized || m_asset == NULL)
      return false;
   
   if(volume < m_asset.GetVolumeMin())
      return false;
   
   if(volume > m_asset.GetVolumeMax())
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Obter bid atual                                                  |
//+------------------------------------------------------------------+
double CTradeEngine::GetCurrentBid()
{
   if(m_asset != NULL)
      return SymbolInfoDouble(m_asset.GetSymbol(), SYMBOL_BID);
   return SymbolInfoDouble(_Symbol, SYMBOL_BID);
}

//+------------------------------------------------------------------+
//| Obter ask atual                                                  |
//+------------------------------------------------------------------+
double CTradeEngine::GetCurrentAsk()
{
   if(m_asset != NULL)
      return SymbolInfoDouble(m_asset.GetSymbol(), SYMBOL_ASK);
   return SymbolInfoDouble(_Symbol, SYMBOL_ASK);
}

//+------------------------------------------------------------------+
//| Imprimir informações da posição (debug)                          |
//+------------------------------------------------------------------+
void CTradeEngine::PrintPositionInfo()
{
   if(!HasPosition())
   {
      Print("CTradeEngine: Sem posição aberta");
      return;
   }
   
   UpdatePositionData();
   
   Print("═══════════════════════════════════════════════════════════");
   Print("CTradeEngine - Informações da Posição");
   Print("═══════════════════════════════════════════════════════════");
   Print("Ticket:        ", m_currentPos.ticket);
   Print("Símbolo:       ", m_currentPos.symbol);
   Print("Tipo:          ", m_currentPos.type == POSITION_TYPE_BUY ? "BUY" : "SELL");
   Print("Volume:        ", DoubleToString(m_currentPos.volume, 2));
   Print("Vol Original:  ", DoubleToString(m_currentPos.originalVolume, 2));
   Print("───────────────────────────────────────────────────────────");
   Print("Preço Abertura:", DoubleToString(m_currentPos.priceOpen, _Digits));
   Print("Preço Atual:   ", DoubleToString(m_currentPos.priceCurrent, _Digits));
   Print("Stop Loss:     ", DoubleToString(m_currentPos.sl, _Digits));
   Print("Take Profit:   ", DoubleToString(m_currentPos.tp, _Digits));
   Print("───────────────────────────────────────────────────────────");
   Print("TP1:           ", DoubleToString(m_currentPos.tp1Price, _Digits), m_currentPos.tp1Hit ? " [HIT]" : "");
   Print("TP2:           ", DoubleToString(m_currentPos.tp2Price, _Digits), m_currentPos.tp2Hit ? " [HIT]" : "");
   Print("Break-even:    ", DoubleToString(m_currentPos.bePrice, _Digits), m_currentPos.beActivated ? " [ATIVO]" : "");
   Print("───────────────────────────────────────────────────────────");
   Print("Lucro:         ", DoubleToString(m_currentPos.profit, 2));
   Print("Swap:          ", DoubleToString(m_currentPos.swap, 2));
   Print("Tempo Aberta:  ", TimeToString(m_currentPos.timeOpen, TIME_DATE|TIME_MINUTES));
   Print("═══════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Imprimir resultado do trade (debug)                              |
//+------------------------------------------------------------------+
void CTradeEngine::PrintTradeResult(const TradeResult& result)
{
   Print("═══════════════════════════════════════════════════════════");
   Print("CTradeEngine - Resultado da Operação");
   Print("═══════════════════════════════════════════════════════════");
   Print("Sucesso:       ", result.success ? "SIM" : "NÃO");
   Print("Ticket:        ", result.ticket);
   Print("Código:        ", result.retcode, " - ", result.retcodeDesc);
   Print("Preço:         ", DoubleToString(result.price, _Digits));
   Print("Volume:        ", DoubleToString(result.volume, 2));
   Print("Mensagem:      ", result.message);
   Print("═══════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
