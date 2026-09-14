// Centralized bridge configuration for the local MT5 -> NestJS feed.
#ifndef __FOREX_SCALPER_BRIDGE_CONFIG_MQH__
#define __FOREX_SCALPER_BRIDGE_CONFIG_MQH__

#define BRIDGE_DEFAULT_BACKEND_HOST "127.0.0.1"
#define BRIDGE_DEFAULT_BACKEND_PORT 8080

class CBridgeConfig
  {
public:
   string Symbol;
   bool DebugLogging;
   bool BackendEnabled;
   string BackendHost;
   int BackendPort;
   string BackendToken;

   CBridgeConfig()
     {
      Symbol = "";
      DebugLogging = true;
      BackendEnabled = true;
      BackendHost = BRIDGE_DEFAULT_BACKEND_HOST;
      BackendPort = BRIDGE_DEFAULT_BACKEND_PORT;
      BackendToken = "";
     }

   bool Initialize(const string symbol, const string host, const int port, const string token)
     {
      Symbol = symbol;
      BackendHost = host;
      BackendPort = port;
      BackendToken = token;
      if(Symbol == "")
         return false;
      return BackendToken != "";
     }

   void Log(const string message) const
     {
      if(DebugLogging)
         Print("[ForexScalperBridge] ", message);
     }

   void Release()
     {
      // Reserved for future configuration/resource cleanup.
     }
  };

#endif
