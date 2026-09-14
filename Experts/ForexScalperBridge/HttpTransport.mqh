#ifndef __FOREX_SCALPER_BRIDGE_HTTP_TRANSPORT_MQH__
#define __FOREX_SCALPER_BRIDGE_HTTP_TRANSPORT_MQH__

class CHttpTransport
  {
private:
   string m_url;
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

   bool Post(const string payload)
     {
      char body[];
      char response[];
      string response_headers;
      string headers = "Content-Type: application/json\r\nX-MT5-Auth-Token: " + m_token + "\r\n";
      int length = StringToCharArray(payload, body, 0, WHOLE_ARRAY, CP_UTF8);
      if(length <= 1)
         return false;
      ArrayResize(body, length - 1);
      ResetLastError();
      int status = WebRequest("POST", m_url, headers, 3000, body, response, response_headers);
      if(status < 200 || status >= 300)
        {
         PrintFormat("[ForexScalperBridge] HTTP POST failed. status=%d error=%d", status, GetLastError());
         return false;
        }
      return true;
     }

public:
   CHttpTransport() { m_url = ""; m_token = ""; m_client_id = ""; m_sequence = 0; }

   void Configure(const string host, const int port, const string token, const string client_id)
     {
      m_url = StringFormat("http://%s:%d/mt5/ingest", host, port);
      m_token = token;
      m_client_id = client_id;
     }

   bool Connect()
     {
      string auth = StringFormat(
         "{\"type\":\"AUTH\",\"version\":1,\"messageId\":\"%s\",\"timestamp\":%I64d,\"clientId\":\"%s\",\"token\":\"%s\"}",
         MessageId(), TimestampMilliseconds(), m_client_id, m_token);
      bool connected = Post(auth);
      if(connected)
         Print("[ForexScalperBridge] HTTP AUTH sent");
      return connected;
     }

   bool SendTick(const string symbol, const string timeframe, const MqlTick &tick, const double spread)
     {
      string message = StringFormat(
         "{\"type\":\"TICK\",\"version\":1,\"messageId\":\"%s\",\"timestamp\":%I64d,\"symbol\":\"%s\",\"timeframe\":\"%s\",\"tick\":{\"time\":%I64d,\"timeMsc\":%I64d,\"bid\":%.10f,\"ask\":%.10f,\"last\":%.10f,\"volume\":%I64d,\"volumeReal\":%.10f,\"flags\":%I64d},\"spread\":%.10f}",
         MessageId(), TimestampMilliseconds(), symbol, timeframe, tick.time, tick.time_msc,
         tick.bid, tick.ask, tick.last, tick.volume, tick.volume_real, tick.flags, spread);
      return Post(message);
     }

   bool SendCandle(const string symbol, const string timeframe, const MqlRates &bar)
     {
      string message = StringFormat(
         "{\"type\":\"CANDLE\",\"version\":1,\"messageId\":\"%s\",\"timestamp\":%I64d,\"symbol\":\"%s\",\"timeframe\":\"%s\",\"candle\":{\"time\":%I64d,\"open\":%.10f,\"high\":%.10f,\"low\":%.10f,\"close\":%.10f,\"tickVolume\":%I64d,\"realVolume\":%I64d,\"spread\":%I64d}}",
         MessageId(), TimestampMilliseconds(), symbol, timeframe, bar.time, bar.open,
         bar.high, bar.low, bar.close, bar.tick_volume, bar.real_volume, bar.spread);
      return Post(message);
     }

   bool SendHeartbeat()
     {
      return Post(StringFormat(
         "{\"type\":\"HEARTBEAT\",\"version\":1,\"messageId\":\"%s\",\"timestamp\":%I64d}",
         MessageId(), TimestampMilliseconds()));
     }

   bool SendSymbolInfo(const string symbol, const int digits, const double point,
                       const double tick_size, const double tick_value,
                       const double contract_size, const double volume_min,
                       const double volume_max, const double volume_step,
                       const long trade_mode, const string currency_base,
                       const string currency_profit, const string currency_margin)
     {
      return Post(StringFormat(
         "{\"type\":\"SYMBOL_INFO\",\"version\":1,\"messageId\":\"%s\",\"timestamp\":%I64d,\"symbol\":\"%s\",\"info\":{\"digits\":%d,\"point\":%.10f,\"tickSize\":%.10f,\"tickValue\":%.10f,\"contractSize\":%.10f,\"volumeMin\":%.10f,\"volumeMax\":%.10f,\"volumeStep\":%.10f,\"tradeMode\":%I64d,\"currencyBase\":\"%s\",\"currencyProfit\":\"%s\",\"currencyMargin\":\"%s\"}}",
         MessageId(), TimestampMilliseconds(), symbol, digits, point, tick_size, tick_value,
         contract_size, volume_min, volume_max, volume_step, trade_mode, currency_base,
         currency_profit, currency_margin));
     }

   bool SendAccountInfo()
     {
      return Post(StringFormat(
         "{\"type\":\"ACCOUNT_INFO\",\"version\":1,\"messageId\":\"%s\",\"timestamp\":%I64d,\"account\":{\"login\":%I64d,\"balance\":%.10f,\"equity\":%.10f,\"margin\":%.10f,\"freeMargin\":%.10f,\"marginLevel\":%.10f,\"profit\":%.10f,\"currency\":\"%s\",\"leverage\":%I64d}}",
         MessageId(), TimestampMilliseconds(), AccountInfoInteger(ACCOUNT_LOGIN),
         AccountInfoDouble(ACCOUNT_BALANCE), AccountInfoDouble(ACCOUNT_EQUITY),
         AccountInfoDouble(ACCOUNT_MARGIN), AccountInfoDouble(ACCOUNT_MARGIN_FREE),
         AccountInfoDouble(ACCOUNT_MARGIN_LEVEL), AccountInfoDouble(ACCOUNT_PROFIT),
         AccountInfoString(ACCOUNT_CURRENCY), AccountInfoInteger(ACCOUNT_LEVERAGE)));
     }

   bool SendPosition(const ulong ticket, const string symbol, const string type,
                     const double volume, const double open_price,
                     const double current_price, const double stop_loss,
                     const double take_profit, const double profit,
                     const double swap, const double commission, const long open_time)
     {
      return Post(StringFormat(
         "{\"type\":\"POSITION\",\"version\":1,\"messageId\":\"%s\",\"timestamp\":%I64d,\"position\":{\"ticket\":%I64u,\"symbol\":\"%s\",\"type\":\"%s\",\"volume\":%.10f,\"openPrice\":%.10f,\"currentPrice\":%.10f,\"stopLoss\":%.10f,\"takeProfit\":%.10f,\"profit\":%.10f,\"swap\":%.10f,\"commission\":%.10f,\"openTime\":%I64d}}",
         MessageId(), TimestampMilliseconds(), ticket, symbol, type, volume, open_price,
         current_price, stop_loss, take_profit, profit, swap, commission, open_time));
     }
  };

#endif
