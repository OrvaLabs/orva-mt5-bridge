// ForexScalperBridge.mq5
// MT5-facing adapter for the Forex Scalper application.
#property copyright "Forex Scalper"
#property version   "001.000"
#property strict

#include "Config.mqh"
#include "MarketData.mqh"
#include "Trading.mqh"
#include "Account.mqh"
#include "SymbolInfo.mqh"
#include "Execution.mqh"
#include "DataQuality.mqh"
#include "TcpTransport.mqh"
#include "HttpTransport.mqh"

input string InpBackendHost = "127.0.0.1";
input int InpBackendPort = 8080;
input int InpHttpPort = 3000;
input string InpBackendToken = "change-me";
input int InpHeartbeatIntervalSeconds = 10;
input int InpSnapshotIntervalSeconds = 30;
input string InpTransport = "HTTP";

CBridgeConfig g_config;
CMarketData g_market_data;
CTrading g_trading;
CAccount g_account;
CSymbolInfo g_symbol_info;
CExecution g_execution;
CDataQuality g_data_quality;
CTcpTransport g_transport;
CHttpTransport g_http_transport;
datetime g_last_snapshot_time = 0;

string BridgeTimeframe()
  {
   switch(_Period)
     {
      case PERIOD_M1: return "M1";
      case PERIOD_M2: return "M2";
      case PERIOD_M3: return "M3";
      case PERIOD_M4: return "M4";
      case PERIOD_M5: return "M5";
      case PERIOD_M6: return "M6";
      case PERIOD_M10: return "M10";
      case PERIOD_M12: return "M12";
      case PERIOD_M15: return "M15";
      case PERIOD_M20: return "M20";
      case PERIOD_M30: return "M30";
      case PERIOD_H1: return "H1";
      case PERIOD_H2: return "H2";
      case PERIOD_H3: return "H3";
      case PERIOD_H4: return "H4";
      case PERIOD_H6: return "H6";
      case PERIOD_H8: return "H8";
      case PERIOD_H12: return "H12";
      case PERIOD_D1: return "D1";
      case PERIOD_W1: return "W1";
      case PERIOD_MN1: return "MN1";
     }
   return "";
  }

void ReleaseBridge()
  {
   g_trading.Release();
   g_execution.Release();
   g_data_quality.Release();
   g_symbol_info.Release();
   g_account.Release();
   g_market_data.Release();
   g_config.Release();
   g_transport.Close();
  }

int OnInit()
  {
   if(!g_config.Initialize(_Symbol, InpBackendHost, InpBackendPort, InpBackendToken))
      return INIT_FAILED;
   g_transport.Configure(InpBackendHost, InpBackendPort, InpBackendToken,
                         "mt5-" + IntegerToString((int)GetTickCount()));
   string client_id = "mt5-" + IntegerToString((int)GetTickCount());
   g_http_transport.Configure(InpBackendHost, InpHttpPort, InpBackendToken, client_id);
   bool connected = InpTransport == "HTTP" ? g_http_transport.Connect() : g_transport.Connect();
   if(!connected)
      PrintFormat("[ForexScalperBridge] Initial TCP connection failed to %s:%d",
                  InpBackendHost, InpBackendPort);
   EventSetTimer(InpHeartbeatIntervalSeconds);

   if(!g_market_data.Initialize(g_config.Symbol))
      {
       ReleaseBridge();
       return INIT_FAILED;
      }
   if(!g_account.Initialize())
      {
       ReleaseBridge();
       return INIT_FAILED;
      }
   if(!g_symbol_info.Initialize(g_config.Symbol))
      {
       ReleaseBridge();
       return INIT_FAILED;
      }
   if(!g_data_quality.Initialize())
      {
       ReleaseBridge();
       return INIT_FAILED;
      }
   if(!g_execution.Initialize())
      {
       ReleaseBridge();
       return INIT_FAILED;
      }
   if(!g_trading.Initialize(g_execution))
      {
       ReleaseBridge();
       return INIT_FAILED;
      }

   g_config.Log("ForexScalperBridge initialized for " + g_config.Symbol);
   return INIT_SUCCEEDED;
  }

void SendPeriodicSnapshots()
  {
   datetime now = TimeCurrent();
   if(g_last_snapshot_time != 0 &&
      now - g_last_snapshot_time < InpSnapshotIntervalSeconds)
      return;
   g_last_snapshot_time = now;

   if(InpTransport == "HTTP")
     {
      g_http_transport.SendSymbolInfo(
         g_config.Symbol, g_symbol_info.GetDigits(), g_symbol_info.GetPoint(),
         g_symbol_info.GetTickSize(), g_symbol_info.GetTickValue(),
         g_symbol_info.GetContractSize(), g_symbol_info.GetMinimumVolume(),
         g_symbol_info.GetMaximumVolume(), g_symbol_info.GetVolumeStep(),
         SymbolInfoInteger(g_config.Symbol, SYMBOL_TRADE_MODE),
         SymbolInfoString(g_config.Symbol, SYMBOL_CURRENCY_BASE),
         SymbolInfoString(g_config.Symbol, SYMBOL_CURRENCY_PROFIT),
         SymbolInfoString(g_config.Symbol, SYMBOL_CURRENCY_MARGIN));
      g_http_transport.SendAccountInfo();
     }
   else
     {
      g_transport.SendSymbolInfo(
         g_config.Symbol, g_symbol_info.GetDigits(), g_symbol_info.GetPoint(),
         g_symbol_info.GetTickSize(), g_symbol_info.GetTickValue(),
         g_symbol_info.GetContractSize(), g_symbol_info.GetMinimumVolume(),
         g_symbol_info.GetMaximumVolume(), g_symbol_info.GetVolumeStep(),
         SymbolInfoInteger(g_config.Symbol, SYMBOL_TRADE_MODE),
         SymbolInfoString(g_config.Symbol, SYMBOL_CURRENCY_BASE),
         SymbolInfoString(g_config.Symbol, SYMBOL_CURRENCY_PROFIT),
         SymbolInfoString(g_config.Symbol, SYMBOL_CURRENCY_MARGIN));
      g_transport.SendAccountInfo();
     }

   for(int index = PositionsTotal() - 1; index >= 0; index--)
     {
      ulong ticket = PositionGetTicket(index);
      if(ticket == 0)
         continue;
      string position_symbol = PositionGetString(POSITION_SYMBOL);
      string position_type = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? "BUY" : "SELL";
      if(InpTransport == "HTTP")
         g_http_transport.SendPosition(ticket, position_symbol, position_type,
            PositionGetDouble(POSITION_VOLUME), PositionGetDouble(POSITION_PRICE_OPEN),
            PositionGetDouble(POSITION_PRICE_CURRENT), PositionGetDouble(POSITION_SL),
            PositionGetDouble(POSITION_TP), PositionGetDouble(POSITION_PROFIT),
            PositionGetDouble(POSITION_SWAP), 0.0, PositionGetInteger(POSITION_TIME));
      else
         g_transport.SendPosition(ticket, position_symbol, position_type,
            PositionGetDouble(POSITION_VOLUME), PositionGetDouble(POSITION_PRICE_OPEN),
            PositionGetDouble(POSITION_PRICE_CURRENT), PositionGetDouble(POSITION_SL),
            PositionGetDouble(POSITION_TP), PositionGetDouble(POSITION_PROFIT),
            PositionGetDouble(POSITION_SWAP), 0.0, PositionGetInteger(POSITION_TIME));
     }
  }

  void OnTick()
  {
      if(!g_market_data.Refresh())
          return;
  
      g_data_quality.Update(g_market_data.GetTick());
      if(InpTransport == "HTTP")
         g_http_transport.SendTick(g_config.Symbol, BridgeTimeframe(),
                                   g_market_data.GetTick(), g_market_data.GetSpread());
      else
         g_transport.SendTick(g_config.Symbol, BridgeTimeframe(),
                              g_market_data.GetTick(), g_market_data.GetSpread());
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      if(CopyRates(g_config.Symbol, _Period, 0, 1, rates) == 1)
         if(InpTransport == "HTTP")
            g_http_transport.SendCandle(g_config.Symbol, BridgeTimeframe(), rates[0]);
         else
            g_transport.SendCandle(g_config.Symbol, BridgeTimeframe(), rates[0]);
      SendPeriodicSnapshots();
  }

void OnTimer()
  {
   if(InpTransport == "HTTP")
      g_http_transport.SendHeartbeat();
   else
      g_transport.SendHeartbeat();
   SendPeriodicSnapshots();
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   ReleaseBridge();

   PrintFormat("ForexScalperBridge stopped (reasofn=%d)", reason);
  }
