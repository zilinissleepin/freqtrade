# Freqtrade 项目分析

## 概述

Freqtrade 是一个开源的加密货币量化交易框架，使用 Python 编写，支持现货与合约（期货）交易，内置回测、超参数优化、可视化、风控保护、Telegram/WebUI 控制，并可选通过 FreqAI 进行机器学习增强策略。

适合人群：有一定 Python 基础、了解技术分析/量化交易流程、希望自定义策略并快速验证的人群。

---

## 核心能力

- 策略开发：基于 `IStrategy` 接口，使用各类指标/数据构建信号。
- 回测与分析：快速模拟历史绩效、生成交易明细与图表。
- 超参数优化：内置 `hyperopt`，可优化阈值/周期等参数。
- 可视化：`plot-dataframe` 支持绘制价格、指标、信号、标注信息。
- 交易接入：集成 CCXT，支持 Binance/OKX/Bybit 等主流交易所（含部分期货）。
- 运行控制：Telegram、内置 WebUI 操控；API Server 统一管理。
- 风险控制：多种保护机制（如止损保护、最大回撤、低收益过滤等）。
- 持久化：sqlite 记录交易、订单与统计。

---

## 关键目录与模块

- 策略接口与工具：`freqtrade/strategy`
  - `interface.py`：定义 `IStrategy` 接口（信号列、回调、ROI/止损/保护等）。
  - `strategy_helper.py`、`parameters.py`：策略辅助工具、超参容器。
- 交易所对接：`freqtrade/exchange`（CCXT 封装与交易细节）。
- 数据与回测：`freqtrade/data`、`freqtrade/optimize`（下载数据、回测与超参）。
- 持久化：`freqtrade/persistence`（sqlite ORM，持仓/订单/交易记录）。
- 控制层：`freqtrade/rpc`（Telegram/WebUI），`freqtrade/main.py`（入口）。
- 用户空间：`user_data`（配置、策略、数据、回测结果、图表等）。

---

## 策略接口 IStrategy（要点）

- 生命周期方法：
  - `populate_indicators(df, metadata)`：计算并写入自定义技术指标列。
  - `populate_entry_trend(df, metadata)`：设置入场信号列 `enter_long/enter_short`。
  - `populate_exit_trend(df, metadata)`：设置离场信号列 `exit_long/exit_short`（可选）。
  - 回调：`custom_stoploss`、`custom_exit`、`custom_stake_amount` 等用于风控和下单细节微调。
- 信号列（最终由框架读取并执行）：`enter_long`、`exit_long`、`enter_short`、`exit_short`。
- 交易逻辑：
  - ROI（`minimal_roi`）与固定/自定义止损（`stoploss`/`custom_stoploss`）。
  - 追踪止损（`trailing_stop*`）可选。
  - 保护机制（`protections`）控制冷却/回撤/亏损风控。
- 时间框架：策略级 `timeframe`，可用 @informative 读高周期数据合并到主周期。

注：当前仓库模板中 `enter_long/exit_long` 已是主流字段，兼容 `INTERFACE_VERSION=2/3`。

---

## 配置与运行

用户配置文件位于 `user_data/config.json`：

- 账户与交易所：`exchange.name/key/secret`，`trading_mode`（`spot|futures`），`margin_mode`（`isolated|cross`）。
- 资金与风控：`max_open_trades`、`stake_currency`、`stake_amount`、`tradable_balance_ratio`。
- 订单与定价：`entry_pricing`、`exit_pricing`、`unfilledtimeout`。
- 交易对：`pair_whitelist`/`pair_blacklist`。
- 运行模式：`dry_run` 干跑，`api_server`、`telegram` 控制。

常用命令（示例）：

```bash
# 下载数据（15m）
freqtrade download-data --timeframes 15m -p BTC/USDT:USDT

# 回测
freqtrade backtesting -c user_data/config_backtest.json -s HarmonicDivergence --timeframe 15m --timerange 20240101-20241001 --enable-protections

# 画图（信号/指标）
freqtrade plot-dataframe -c user_data/config_backtest.json -s HarmonicDivergence -p BTC/USDT:USDT --timeframe 15m --timerange 20240901-20241001

# 实时干跑
freqtrade trade -c user_data/config.json -s HarmonicDivergence
```

---

## 运行流程（简化）

1) 解析配置 → 初始化交易所、数据提供器、策略实例。
2) 拉取/刷新 K 线（OHLCV）→ `populate_indicators` 计算指标。
3) `populate_entry_trend/exit_trend` 生成信号列。
4) 框架读取最新一根 K 线信号 → 应用 ROI/止损/保护 → 下单。
5) 订单/持仓/交易写入 sqlite（可通过 WebUI/Telegram 查询）。

---

## 数据与时间框架

- K 线列：`date, open, high, low, close, volume`，指标以自定义列追加。
- `startup_candle_count`：指策略需要的最少 K 线数量，避免指标 NaN 触发误信号。
- Informative（高周期数据）：通过装饰器或 `merge_informative_pair` 合并至主周期（避免未来函数，使用 `ffill`）。

---

## 风控与保护

- 固定止损（`stoploss`）与自定义止损（`custom_stoploss`）。
- 追踪止损（`trailing_stop_positive` 等）在达标后动态抬升止损位。
- 保护（`protections`）：如 `StoplossGuard`、`MaxDrawdown`、`LowProfitPairs`，用于在连续亏损/回撤/低收益时临时停交易或降频。

---

## 开发与最佳实践

- 只在新 K 线计算：`process_only_new_candles = True`，提升性能与一致性。
- 明确 `startup_candle_count`，与指标最小周期对齐（如用到 `EMA200`，建议 ≥200）。
- 坚持无“未来函数”（避免使用当前 K 线的收盘后数据触发信号）。
- 将阈值做成可优化参数（`IntParameter`/`DecimalParameter`），便于 `hyperopt`。
- 使用 `plot_config` 可视化关键变量、调试信号边界。
- 回测覆盖多币种和多周期，关注胜率/盈亏比/回撤/交易次数。

---

## 常见注意事项

- `INTERFACE_VERSION` 与信号列字段需匹配（v3 同时支持多空与杠杆）。
- Futures 模式需关注保证金与强平风险；`margin_mode` 与杠杆配置需与交易所权限一致。
- Telegram/WebUI 涉及敏感凭据，注意配置安全与本地网络可达。
- 回测手续费/滑点参数影响较大，应尽量贴近实盘。

---

## 参考文件与位置（本仓库）

- 策略接口：`freqtrade/strategy/interface.py`
- 策略示例：`freqtrade/templates/sample_strategy.py`、`user_data/strategies/*.py`
- 你的策略：`user_data/strategies/HarmonicDivergence.py`
- 配置：`user_data/config.json`、`user_data/config_backtest.json`
- 文档：`README.md`、`docs/`

---

## 小结

Freqtrade 提供了完整的量化交易“开发-验证-运行”闭环：以 `IStrategy` 为核心，配合回测/优化/可视化与风控模块，可快速验证想法并迭代策略。在进入实盘前务必进行充分回测与前置干跑，结合保护机制与稳健资金管理，降低极端行情与模型失效带来的风险。

