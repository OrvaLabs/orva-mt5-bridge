// Execution data model and future execution boundary.
#ifndef __FOREX_SCALPER_BRIDGE_EXECUTION_MQH__
#define __FOREX_SCALPER_BRIDGE_EXECUTION_MQH__

enum EOrderStatus
  {
   ORDER_STATUS_UNKNOWN = 0,
   ORDER_STATUS_REQUESTED,
   ORDER_STATUS_FILLED,
   ORDER_STATUS_PARTIALLY_FILLED,
   ORDER_STATUS_REJECTED,
   ORDER_STATUS_CANCELLED
  };

struct SExecutionReport
  {
   double requested_price;
   double filled_price;
   double slippage;
   long execution_latency_ms;
   double commission;
   double swap;
   EOrderStatus status;
  };

class CExecution
  {
private:
   bool m_initialized;
   SExecutionReport m_last_report;

public:
   CExecution()
     {
      m_initialized = false;
      ZeroMemory(m_last_report);
      m_last_report.status = ORDER_STATUS_UNKNOWN;
     }

   bool Initialize()
     {
      m_initialized = true;
      return true;
     }

   SExecutionReport GetLastReport() const { return m_last_report; }

   void Release()
     {
      m_initialized = false;
      ZeroMemory(m_last_report);
      m_last_report.status = ORDER_STATUS_UNKNOWN;
     }
  };

#endif
