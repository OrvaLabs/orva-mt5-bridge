# orva-mt5-bridge

> A MetaTrader 5 market-data bridge that captures broker-native ticks,
> candles, account details, symbol specifications, and open positions, then
> delivers them to a backend over HTTP or TCP.

![ForexScalperBridge in MetaEditor](https://github.com/user-attachments/assets/c57f858b-820a-4499-9138-1cb073add29c)

`ForexScalperBridge` is the MetaTrader 5 (MT5) Expert Advisor module that
connects a broker terminal to the Forex Scalper backend.

It reads information that is already available inside MT5, converts that
information into versioned JSON messages, and sends the messages to the
backend over HTTP or TCP.

This README documents this module only.

It does not describe the complete Forex Scalper application, its strategy,
its dashboard, or its backend implementation.

## What this module actually does

The module runs inside an MT5 terminal as an Expert Advisor.

It is attached to a chart and uses that chart's symbol and timeframe.

On every incoming market tick, it:

1. Refreshes the current MT5 tick.
2. Reads bid, ask, last price, volume, and tick timestamps.
3. Calculates the current spread.
4. Records basic feed-quality information.
5. Sends a `TICK` message to the backend.
6. Reads the latest one-bar candle for the chart timeframe.
7. Sends a `CANDLE` message to the backend.
8. Periodically sends account and symbol snapshots.
9. Periodically sends open-position snapshots.

On a timer, it:

- Sends a `HEARTBEAT` message.
- Checks whether periodic snapshots are due.
- Sends account, symbol, and position data when required.

When the Expert Advisor starts, it:

- Validates the selected symbol and backend token.
- Configures both available transports.
- Authenticates with the backend.
- Initializes market data, account, symbol, quality, execution, and trading
  boundaries.

When it stops, it:

- Stops the timer.
- Releases module state.
- Closes the TCP socket when TCP is selected.

## What this module does not do

This module is intentionally a data bridge.

It does not:

- Implement a trading strategy.
- Generate buy or sell signals.
- Place market orders.
- Place pending orders.
- Close positions.
- Cancel orders.
- Manage risk.
- Store historical market data.
- Render a dashboard.
- Replace the broker or MT5 terminal.
- Authenticate a human user.
- Send broker passwords or account credentials.

The `CTrading` methods are boundaries for future execution work. They currently
print a placeholder message and return `false`; they do not trade.

The `CExecution` class currently defines an execution report model and order
statuses. It does not submit requests or receive execution events.

## Where it runs

The module is compiled and executed by MetaTrader 5.

The source is written in MQL5.

The main Expert Advisor file is:

```text
Experts/ForexScalperBridge/ForexScalperBridge.mq5
```

The module is normally attached once per symbol and timeframe during
development.

For example, separate chart instances can be used for:

- `EURUSD / M1`
- `GBPUSD / M5`
- `USDJPY / M15`

Each instance identifies itself with a generated client ID.

## High-level data flow

```text
Broker feed
    |
    v
MetaTrader 5 terminal
    |
    v
ForexScalperBridge Expert Advisor
    |
    +--> MarketData
    +--> DataQuality
    +--> Account
    +--> SymbolInfo
    |
    +--> HTTP transport ----> POST /mt5/ingest
    |
    +--> TCP transport -----> newline-delimited JSON socket
                                  |
                                  v
                            MT5 market-data gateway
```

The Expert Advisor is the composition root.

It owns the module instances and decides when each message is sent.

The data readers do not decide where data is delivered.

The transport classes do not read MT5 state directly except when building
their message payloads from values supplied by the Expert Advisor.

## Module files

| File | Responsibility |
| --- | --- |
| `ForexScalperBridge.mq5` | Expert Advisor entry point and lifecycle orchestration |
| `Config.mqh` | Symbol, backend, token, and logging configuration |
| `MarketData.mqh` | Current bid/ask tick retrieval and spread calculation |
| `Account.mqh` | Account balance, equity, margin, and currency accessors |
| `SymbolInfo.mqh` | Broker contract and volume specification accessors |
| `DataQuality.mqh` | Duplicate, gap, age, and feed-health tracking |
| `TcpTransport.mqh` | Persistent socket transport for supported MT5 environments |
| `HttpTransport.mqh` | HTTP POST transport using MT5 `WebRequest()` |
| `Execution.mqh` | Future execution report and order-status model |
| `Trading.mqh` | Future order-operation boundary; no live trading yet |

## Expert Advisor lifecycle

### `OnInit`

`OnInit` is called when MT5 loads the Expert Advisor.

The module first initializes `CBridgeConfig` with:

- The chart symbol from `_Symbol`.
- The configured backend host.
- The configured backend port.
- The configured authentication token.

Initialization fails if the chart symbol is empty or the token is empty.

Both transports are configured so the selected transport can be used.

The selected transport is determined by `InpTransport`.

With the default value, the HTTP transport sends an `AUTH` message to the
configured HTTP endpoint.

When TCP is selected, the TCP transport opens a socket and sends the same
authentication information as a newline-delimited JSON message.

The module then starts the MT5 timer using
`InpHeartbeatIntervalSeconds`.

After the connection attempt, the data and model classes are initialized.

If one of these initializations fails, already-created resources are released
and `INIT_FAILED` is returned.

### `OnTick`

`OnTick` runs when MT5 receives a tick for the attached chart.

The module first calls `CMarketData.Refresh()`.

If MT5 cannot provide a current tick, the event is ignored.

The tick is passed to `CDataQuality.Update()`.

The current tick is then sent with:

- Symbol.
- Chart timeframe.
- Tick server time.
- Tick millisecond time.
- Bid.
- Ask.
- Last price.
- Integer tick volume.
- Real tick volume.
- Tick flags.
- Calculated spread.

The module then requests one current bar using `CopyRates()`.

If a bar is available, it sends a `CANDLE` message with open, high, low,
close, volume, and spread information.

Finally, `SendPeriodicSnapshots()` checks whether account, symbol, and
position data should be sent.

### `OnTimer`

`OnTimer` runs at the configured heartbeat interval.

It sends a `HEARTBEAT` message through the selected transport.

It also calls `SendPeriodicSnapshots()` so snapshots continue to be published
even when the market is temporarily quiet.

### `OnDeinit`

`OnDeinit` stops the timer and releases the bridge components.

The TCP transport closes its socket.

The HTTP transport does not hold a persistent socket in this module; each
message is sent using an individual MT5 `WebRequest()` call.

## Messages sent by the module

Every message includes:

- `type`
- `version`
- `messageId`
- `timestamp`

The `messageId` is generated from the client ID, MT5 tick-count values, and a
per-transport sequence number.

The timestamp is represented in milliseconds.

### `AUTH`

Sent when a transport connects.

The message identifies the bridge instance and includes the configured backend
token.

The TCP transport sends this as the first line after opening the socket.

The HTTP transport sends it as a POST request to the ingestion endpoint.

### `TICK`

Sent for each successfully refreshed MT5 tick.

The payload contains the selected symbol, chart timeframe, nested tick data,
and the calculated bid/ask spread.

This is the primary real-time market-data message.

### `CANDLE`

Sent for the latest bar on the chart timeframe.

The payload includes:

- Bar open time.
- Open price.
- High price.
- Low price.
- Close price.
- Tick volume.
- Real volume.
- Broker-reported bar spread.

The module requests one bar per tick, but only publishes it when
`CopyRates()` returns exactly one bar.

### `SYMBOL_INFO`

Sent during periodic snapshots.

The payload describes the broker's contract settings for the attached symbol:

- Digits.
- Point size.
- Tick size.
- Tick value.
- Contract size.
- Minimum volume.
- Maximum volume.
- Volume step.
- Trade mode.
- Base currency.
- Profit currency.
- Margin currency.

### `ACCOUNT_INFO`

Sent during periodic snapshots.

The payload contains the current MT5 account values:

- Login.
- Balance.
- Equity.
- Margin.
- Free margin.
- Margin level.
- Current profit.
- Account currency.
- Leverage.

### `POSITION`

One message is sent for each open MT5 position during a periodic snapshot.

The payload contains:

- Position ticket.
- Symbol.
- Direction (`BUY` or `SELL`).
- Volume.
- Open price.
- Current price.
- Stop-loss.
- Take-profit.
- Profit.
- Swap.
- Commission field.
- Open time.

The current implementation supplies `0.0` for the commission value when it
builds position snapshots.

### `HEARTBEAT`

Sent from `OnTimer`.

It allows the backend to determine that the bridge instance is still alive,
even if no market tick has arrived recently.

## Transport modes

### HTTP mode

HTTP is the default mode in the Expert Advisor inputs.

The endpoint is constructed as:

```text
http://<InpBackendHost>:<InpHttpPort>/mt5/ingest
```

Each message is sent with an HTTP `POST`.

The request includes:

```text
Content-Type: application/json
X-MT5-Auth-Token: <InpBackendToken>
```

The response is considered successful only for a status code from `200` to
`299`.

HTTP mode is the recommended mode for MT5 running on macOS because it uses
MT5's `WebRequest()` API.

The URL must be added to MT5's allowed WebRequest list.

### TCP mode

TCP mode uses MT5's socket API.

The transport opens a connection to:

```text
<InpBackendHost>:<InpBackendPort>
```

Messages are UTF-8 JSON lines.

Each message ends with a newline.

The socket is reused while it remains connected.

If a send fails, the socket is closed.

The next send attempts to reconnect and sends `AUTH` again.

TCP mode is intended for supported Windows MT5 environments where the backend
provides the raw market-data gateway.

MT5 may require the destination to be added to its permitted socket address
list.

## Configuration inputs

The Expert Advisor exposes these inputs:

| Input | Default | Purpose |
| --- | --- | --- |
| `InpBackendHost` | `127.0.0.1` | Backend host name or IP address |
| `InpBackendPort` | `8080` | TCP gateway port |
| `InpHttpPort` | `3000` | HTTP ingestion port |
| `InpBackendToken` | `change-me` | Shared bridge authentication token |
| `InpHeartbeatIntervalSeconds` | `10` | Timer and heartbeat interval |
| `InpSnapshotIntervalSeconds` | `30` | Account, symbol, and position interval |
| `InpTransport` | `HTTP` | Selects `HTTP` or `TCP` |

The chart symbol and timeframe are not input fields.

They come from the chart to which the Expert Advisor is attached.

For HTTP mode, use `InpHttpPort`.

For TCP mode, use `InpBackendPort`.

The configured token must match the backend's expected MT5 ingestion token.

Do not use `change-me` outside a local development environment.

## Installation

1. Open MetaTrader 5.
2. Choose **File > Open Data Folder**.
3. Open the `MQL5/Experts` directory.
4. Copy the `ForexScalperBridge` directory into `MQL5/Experts`.
5. Open `ForexScalperBridge.mq5` in MetaEditor.
6. Compile with **F7**.
7. Refresh **Expert Advisors** in the MT5 Navigator.
8. Attach the Expert Advisor to a chart.
9. Set the backend inputs.
10. Enable the HTTP URL or TCP address in MT5 permissions.
11. Confirm the connection and data messages in the Experts log.

MetaEditor is the authoritative compiler for this MQL5 module.

The generated `.ex5` file is a compiler artifact.

The source of truth is the `.mq5` file and its included `.mqh` files.

## Permissions

### HTTP permission

For HTTP mode, add the exact URL to:

**Tools > Options > Expert Advisors > Allow WebRequest for listed URL**

For the default local configuration, add:

```text
http://127.0.0.1:3000
```

If the backend runs on another host or port, add that exact base URL instead.

### TCP permission

For TCP mode, allow the configured host and port in MT5's socket permissions
when the terminal requests or requires it.

If the connection fails, inspect the printed `SocketConnect` error code.

## Logs and troubleshooting

The module writes logs with the `[ForexScalperBridge]` prefix.

A successful TCP startup normally includes:

```text
[ForexScalperBridge] TCP connected to 127.0.0.1:8080
[ForexScalperBridge] AUTH sent
```

A successful HTTP startup includes:

```text
[ForexScalperBridge] HTTP AUTH sent
```

If the Expert Advisor fails during initialization:

- Confirm a non-empty backend token.
- Confirm the chart has a valid symbol.
- Confirm the selected transport spelling is `HTTP` or `TCP`.
- Confirm the backend host and port.
- Confirm the backend is running.
- Confirm MT5 permissions.
- Review the Experts and Journal tabs.

If ticks are not arriving:

- Confirm the market is open.
- Confirm the chart is receiving broker ticks.
- Confirm the symbol is visible in Market Watch.
- Confirm the Expert Advisor is enabled.
- Confirm the Experts log does not show transport errors.

If HTTP requests fail:

- Confirm the URL is in MT5's WebRequest allow-list.
- Confirm the HTTP port, not the TCP port, is configured for HTTP.
- Confirm the backend accepts `POST /mt5/ingest`.
- Confirm the authentication token.

If TCP messages fail:

- Confirm the raw gateway is listening on the TCP port.
- Confirm the host is reachable from the MT5 machine.
- Confirm socket permissions.
- Check the printed MT5 socket error code.

## Feed-quality tracking

`CDataQuality` records lightweight local diagnostics.

It marks the feed healthy after a valid tick update.

It increments the duplicate counter when a tick has a non-increasing
millisecond timestamp and the same bid and ask as the previous tick.

It increments the data-gap counter when the tick timestamp jumps by more than
60 seconds.

It can report the age of the latest tick.

It exposes a reconnection counter for future transport integration.

The current transport code does not automatically call
`RecordReconnection()` when a reconnect occurs.

These counters are module-local.

They are not currently published as a separate backend message.

## Design boundaries

The module uses one-way responsibilities:

```text
ForexScalperBridge.mq5
    |
    +--> Reads MT5 data
    +--> Updates quality state
    +--> Chooses a transport
    +--> Publishes JSON messages
```

`MarketData` knows how to read a tick.

`Account` knows how to read account values.

`SymbolInfo` knows how to read broker contract values.

`DataQuality` knows how to compare incoming ticks.

`HttpTransport` knows how to post messages.

`TcpTransport` knows how to send newline-delimited socket messages.

`Trading` and `Execution` reserve the future order-execution boundary.

This separation keeps the current bridge focused on data collection and
delivery rather than mixing transport code with trading logic.

## Current limitations

- The module sends data but does not execute trades.
- HTTP sends one request per message.
- TCP support depends on the MT5 environment and backend gateway.
- The position commission field is currently sent as zero.
- Feed-quality counters are local and not published.
- Reconnection events are not yet wired into `CDataQuality`.
- The current bar is checked on every tick rather than deduplicated locally.
- JSON strings are assembled inside the transport classes.
- There is no local message queue when the backend is unavailable.
- There is no durable retry store.
- Backend response bodies are not used after a successful HTTP status.
- The bridge expects the backend ingestion contract to remain compatible.

These limitations are intentional boundaries for the current module version,
not an indication that the Expert Advisor is a complete trading engine.

## Safe usage

Run the module on a demo account while integrating it.

Use a dedicated backend token for local development.

Do not place secrets directly into source files for shared deployments.

Do not treat a successful bridge connection as proof that a trading strategy
is profitable or that order execution is enabled.

The module only reports what MT5 exposes and forwards those values.

## Development checklist

Before changing this module:

- Identify whether the change affects data collection or transport.
- Preserve the message `type` and `version` contract unless coordinated.
- Keep HTTP and TCP payload shapes equivalent.
- Keep chart symbol and timeframe behavior unchanged.
- Preserve explicit error logging.
- Avoid adding trading behavior to a data-only boundary.

After changing this module:

- Compile `ForexScalperBridge.mq5` in MetaEditor.
- Attach it to a demo chart.
- Confirm authentication.
- Confirm tick and candle messages.
- Wait for a snapshot interval.
- Confirm account, symbol, and position messages.
- Confirm heartbeat messages.
- Stop the Expert Advisor and confirm clean shutdown.

## Summary

`ForexScalperBridge` is the MT5-side adapter for the Forex Scalper system.

Its job is to bridge broker-native MT5 data to a backend ingestion interface.

It collects ticks, candles, account information, symbol specifications, and
open positions.

It also sends heartbeats and tracks basic feed quality.

It supports HTTP and TCP delivery.

It does not contain the strategy and it does not place trades.
