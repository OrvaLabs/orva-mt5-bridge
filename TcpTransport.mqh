#ifndef __FOREX_SCALPER_BRIDGE_TCP_TRANSPORT_MQH__
#define __FOREX_SCALPER_BRIDGE_TCP_TRANSPORT_MQH__

class CTcpTransport
  {
private:
   int m_socket;
   string m_host;
   int m_port;
   string m_token;
   string m_client_id;
   ulong m_sequence;

   long TimestampMilliseconds() const
     {
      return (long)TimeTradeServer() * 1000 + (long)(GetTickCount() % 1000);
     }

   string MessageId()
     {
      m_sequence++;
      return StringFormat("%s-%I64u-%I64u", m_client_id, GetTickCount64(), m_sequence);
     }

   bool SendLine(const string payload)
     {
      if(m_socket == INVALID_HANDLE)
         return false;

      uchar bytes[];
      int length = StringToCharArray(payload + "\n", bytes, 0, WHOLE_ARRAY, CP_UTF8);
      if(length <= 1)
         return false;
      ArrayResize(bytes, length - 1);
      return SocketSend(m_socket, bytes, ArraySize(bytes)) == ArraySize(bytes);
     }

public:
   CTcpTransport()
     {
      m_socket = INVALID_HANDLE;
      m_host = "";
      m_port = 0;
      m_token = "";
      m_client_id = "";
      m_sequence = 0;
     }

   void Configure(const string host, const int port, const string token, const string client_id)
     {
      m_host = host;
      m_port = port;
      m_token = token;
      m_client_id = client_id;
     }

   bool IsConnected() const
     {
      return m_socket != INVALID_HANDLE && SocketIsConnected(m_socket);
     }

   bool Connect()
     {
      if(IsConnected())
         return true;
      Close();
      m_socket = SocketCreate();
      if(m_socket == INVALID_HANDLE)
        {
         PrintFormat("[ForexScalperBridge] SocketCreate failed. error=%d", GetLastError());
         return false;
        }
      if(!SocketConnect(m_socket, m_host, m_port, 3000))
        {
         PrintFormat("[ForexScalperBridge] SocketConnect failed for %s:%d. error=%d",
                     m_host, m_port, GetLastError());
         Close();
         return false;
        }
      PrintFormat("[ForexScalperBridge] TCP connected to %s:%d", m_host, m_port);

      string auth = StringFormat(
         "{\"type\":\"AUTH\",\"version\":1,\"messageId\":\"%s\",\"timestamp\":%I64d,\"clientId\":\"%s\",\"token\":\"%s\"}",
         MessageId(), TimestampMilliseconds(), m_client_id, m_token);
      if(!SendLine(auth))
        {
         PrintFormat("[ForexScalperBridge] AUTH send failed. error=%d", GetLastError());
         Close();
         return false;
        }
      Print("[ForexScalperBridge] AUTH sent");
      return true;
     }

   bool SendTick(const string symbol, const string timeframe, const MqlTick &tick, const double spread)
     {
      if(!IsConnected() && !Connect())
         return false;
      string message = StringFormat(
         "{\"type\":\"TICK\",\"version\":1,\"messageId\":\"%s\",\"timestamp\":%I64d,\"symbol\":\"%s\",\"timeframe\":\"%s\",\"tick\":{\"time\":%I64d,\"timeMsc\":%I64d,\"bid\":%.10f,\"ask\":%.10f,\"last\":%.10f,\"volume\":%I64d,\"volumeReal\":%.10f,\"flags\":%I64d},\"spread\":%.10f}",
         MessageId(), TimestampMilliseconds(), symbol, timeframe, tick.time, tick.time_msc,
         tick.bid, tick.ask, tick.last, tick.volume, tick.volume_real, tick.flags, spread);
      if(SendLine(message))
         return true;
      Close();
      return false;
     }

   bool SendHeartbeat()
     {
      if(!IsConnected())
         return Connect();
      string heartbeat = StringFormat(
         "{\"type\":\"HEARTBEAT\",\"version\":1,\"messageId\":\"%s\",\"timestamp\":%I64d}",
         MessageId(), TimestampMilliseconds());
      if(SendLine(heartbeat))
         return true;
      Close();
      return false;
     }

   bool SendCandle(const string symbol, const string timeframe, const MqlRates &bar)
     {
      if(!IsConnected() && !Connect())
         return false;
      string message = StringFormat(
         "{\"type\":\"CANDLE\",\"version\":1,\"messageId\":\"%s\",\"timestamp\":%I64d,\"symbol\":\"%s\",\"timeframe\":\"%s\",\"candle\":{\"time\":%I64d,\"open\":%.10f,\"high\":%.10f,\"low\":%.10f,\"close\":%.10f,\"tickVolume\":%I64d,\"realVolume\":%I64d,\"spread\":%I64d}}",
         MessageId(), TimestampMilliseconds(), symbol, timeframe, bar.time, bar.open,
         bar.high, bar.low, bar.close, bar.tick_volume, bar.real_volume, bar.spread);
      if(SendLine(message))
         return true;
      Close();
      return false;
     }

   bool SendSymbolInfo(const string symbol, const int digits, const double point,
                       const double tick_size, const double tick_value,
                       const double contract_size, const double volume_min,
                       const double volume_max, const double volume_step,
                       const long trade_mode, const string currency_base,
                       const string currency_profit, const string currency_margin)
     {
      if(!IsConnected() && !Connect())
         return false;
      string message = StringFormat(
         "{\"type\":\"SYMBOL_INFO\",\"version\":1,\"messageId\":\"%s\",\"timestamp\":%I64d,\"symbol\":\"%s\",\"info\":{\"digits\":%d,\"point\":%.10f,\"tickSize\":%.10f,\"tickValue\":%.10f,\"contractSize\":%.10f,\"volumeMin\":%.10f,\"volumeMax\":%.10f,\"volumeStep\":%.10f,\"tradeMode\":%I64d,\"currencyBase\":\"%s\",\"currencyProfit\":\"%s\",\"currencyMargin\":\"%s\"}}",
         MessageId(), TimestampMilliseconds(), symbol, digits, point, tick_size, tick_value,
         contract_size, volume_min, volume_max, volume_step, trade_mode, currency_base,
         currency_profit, currency_margin);
      if(SendLine(message))
         return true;
      Close();
      return false;
     }

   bool SendAccountInfo()
     {
      if(!IsConnected() && !Connect())
         return false;
      string message = StringFormat(
         "{\"type\":\"ACCOUNT_INFO\",\"version\":1,\"messageId\":\"%s\",\"timestamp\":%I64d,\"account\":{\"login\":%I64d,\"balance\":%.10f,\"equity\":%.10f,\"margin\":%.10f,\"freeMargin\":%.10f,\"marginLevel\":%.10f,\"profit\":%.10f,\"currency\":\"%s\",\"leverage\":%I64d}}",
         MessageId(), TimestampMilliseconds(), AccountInfoInteger(ACCOUNT_LOGIN),
         AccountInfoDouble(ACCOUNT_BALANCE), AccountInfoDouble(ACCOUNT_EQUITY),
         AccountInfoDouble(ACCOUNT_MARGIN), AccountInfoDouble(ACCOUNT_MARGIN_FREE),
         AccountInfoDouble(ACCOUNT_MARGIN_LEVEL), AccountInfoDouble(ACCOUNT_PROFIT),
         AccountInfoString(ACCOUNT_CURRENCY), AccountInfoInteger(ACCOUNT_LEVERAGE));
      if(SendLine(message))
         return true;
      Close();
      return false;
     }

   bool SendPosition(const ulong ticket, const string symbol, const string type,
                     const double volume, const double open_price,
                     const double current_price, const double stop_loss,
                     const double take_profit, const double profit,
                     const double swap, const double commission, const long open_time)
     {
      if(!IsConnected() && !Connect())
         return false;
      string message = StringFormat(
         "{\"type\":\"POSITION\",\"version\":1,\"messageId\":\"%s\",\"timestamp\":%I64d,\"position\":{\"ticket\":%I64u,\"symbol\":\"%s\",\"type\":\"%s\",\"volume\":%.10f,\"openPrice\":%.10f,\"currentPrice\":%.10f,\"stopLoss\":%.10f,\"takeProfit\":%.10f,\"profit\":%.10f,\"swap\":%.10f,\"commission\":%.10f,\"openTime\":%I64d}}",
         MessageId(), TimestampMilliseconds(), ticket, symbol, type, volume, open_price,
         current_price, stop_loss, take_profit, profit, swap, commission, open_time);
      if(SendLine(message))
         return true;
      Close();
      return false;
     }

   void Close()
     {
      if(m_socket != INVALID_HANDLE)
         SocketClose(m_socket);
      m_socket = INVALID_HANDLE;
     }
  };

#endif
