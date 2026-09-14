#ifndef __FOREX_SCALPER_BRIDGE_DATA_QUALITY_MQH__
#define __FOREX_SCALPER_BRIDGE_DATA_QUALITY_MQH__

enum EFeedHealth
  {
   FEED_HEALTH_UNKNOWN = 0,
   FEED_HEALTH_HEALTHY,
   FEED_HEALTH_STALE
  };

class CDataQuality
  {
private:
   datetime m_last_tick_timestamp;
   long m_last_tick_time_msc;
   double m_last_bid;
   double m_last_ask;
   ulong m_duplicate_ticks;
   ulong m_reconnection_events;
   ulong m_data_gaps;
   EFeedHealth m_health;

public:
   CDataQuality() { Initialize(); }

   bool Initialize()
     {
      m_last_tick_timestamp = 0;
      m_last_tick_time_msc = 0;
      m_last_bid = 0.0;
      m_last_ask = 0.0;
      m_duplicate_ticks = 0;
      m_reconnection_events = 0;
      m_data_gaps = 0;
      m_health = FEED_HEALTH_UNKNOWN;
      return true;
     }

   void Update(const MqlTick &tick)
     {
      if(m_last_tick_time_msc > 0 && tick.time_msc <= m_last_tick_time_msc &&
         tick.bid == m_last_bid && tick.ask == m_last_ask)
         m_duplicate_ticks++;

      if(m_last_tick_timestamp > 0 && tick.time - m_last_tick_timestamp > 60)
         m_data_gaps++;

      m_last_tick_timestamp = tick.time;
      m_last_tick_time_msc = tick.time_msc;
      m_last_bid = tick.bid;
      m_last_ask = tick.ask;
      m_health = FEED_HEALTH_HEALTHY;
     }

   datetime GetLastTickTimestamp() const { return m_last_tick_timestamp; }
   int GetTickAgeSeconds() const
     {
      if(m_last_tick_timestamp == 0)
         return -1;
      int age = (int)(TimeCurrent() - m_last_tick_timestamp);
      return age < 0 ? 0 : age;
     }
   ulong GetDuplicateTickCount() const { return m_duplicate_ticks; }
   ulong GetReconnectionEventCount() const { return m_reconnection_events; }
   ulong GetDataGapCount() const { return m_data_gaps; }
   EFeedHealth GetHealth() const { return m_health; }

   void RecordReconnection() { m_reconnection_events++; }

   void Release()
     {
      Initialize();
     }
  };

#endif
