# HarmonicDivergence 策略分析（新版）

## 概述

HarmonicDivergence 是一个基于“价格-指标背离”原理的多头策略，核心思想是在局部拐点（枢轴点）处检测价格与多类技术指标（动量/量能/趋势）之间的背离来捕捉潜在反转机会，并配合通道过滤、分段 ROI、动态 ATR 止损与风控保护实现快进快出。

策略文件：`user_data/strategies/HarmonicDivergence.py`

---

## 核心参数与风控

- 周期：`timeframe = '15m'`（user_data/strategies/HarmonicDivergence.py:229）
- 分段止盈（ROI）：（203-214）
  - 0 分钟：≥ 5%
  - 30 分钟：≥ 3%
  - 60 分钟：≥ 2%
  - 300 分钟：≥ 1%
- 固定止损：`stoploss = -0.5`，但启用自定义止损（216-220, 473-491）
- 追踪止损：参数存在但默认关闭 `trailing_stop = False`（222-226）
- 启动 K 线数：`startup_candle_count = 30`（239-240）
- 保护（Protections）（260-286）：
  - StoplossGuard：累计亏损保护 / 冷却
  - MaxDrawdown：最大回撤保护
  - LowProfitPairs：短期低收益过滤

---

## 指标体系与通道

- 动量/量能/趋势指标（310-331）：
  - RSI、Stoch、ROC、UO、AO、MACD、CCI、CMF、OBV、MFI、ADX
- 波动/均线（333-343, 765-772）：
  - ATR(14)、EMA(9/20/50/200)
  - 肯特纳通道（`EMA20 ± ATR10`）
  - 布林带（20, 2）

---

## 枢轴点与背离检测

### 枢轴点（Pivot）

- 函数：`pivot_points(dataframe, window=5, pivot_source=Close)`（698-751）
- 逻辑：以 `window=5` 为中心窗口，若当前点在左右各 5 根内为局部极大/极小（默认用 `close`），则标记为枢轴高/低点（字段：`pivot_highs/pivot_lows`）。

### 背离（Divergence）

- 看涨（Bullish）：价格新低但指标抬高，或价格抬高但指标走低（隐藏背离）（650-691, 667-691）
- 看跌（Bearish）：价格新高但指标走低，或价格走低但指标抬高（隐藏背离）（673-691）
- 对 11 个指标逐一检测（360-373, 538-557）：
  - 将“每个指标”的背离落点合并统计到：
    - `total_bullish_divergences`（值为 close，非 0/1）
    - `total_bullish_divergences_count / _names`
    - `total_bearish_divergences` 及对应 `count / names`
- 可视化（139-178）：主图打点+文字标注背离数量与来源指标名。

---

## 入场与过滤

### 入场（多头）

```python
df.loc[
  (df['total_bullish_divergences'].shift() > 0)
  & two_bands_check(df)
  & (df['volume'] > 0),
  'enter_long'] = 1
```

- 背离确认：使用 `shift()`，避免未来函数（上一根 K 线出现看涨背离）。
- 通道过滤（two_bands_check，497-504）：排除同一根 K 线同时触碰 KC 上下轨的“极端波动”情形，减少假信号。
- 成交量要求：`volume > 0`。

### 退出（信号）

- `populate_exit_trend` 恒设 `exit_long = 0`（不以常规卖出信号离场），离场主要由 ROI / 止损 / 回调处理（442-454）。

---

## 自定义止损与离场回调

### 自定义止损（推荐关注）

- 函数：`custom_stoploss`（473-491）
- 逻辑：找到开仓对应的“买入 K 线的上一根 K 线”，设止损价 = `low - ATR`，转为相对当前价的比例返回。
- 优势：与当时波动关联，较静态止损更灵敏。

### 自定义离场（当前未启用）

- 函数：`custom_exit`（456-471）
- 现状：计算了一个 `takeprofit = prev_high + ATR`，但未返回触发条件（未实际执行）。如需启用，可根据 ATR/盈亏比/通道位置返回 `True` 或自定义字符串（作为离场原因）。

---

## 绘图配置（PlotConfig）

- 主图：布林带（阴影）、肯特纳通道（上中下轨）、EMA 9/20/50/200。
- 副图：ATR。
- 背离总计：在主图添加标注，显示“看涨/看跌背离数量与来源指标”。

命令（示例）：

```bash
freqtrade plot-dataframe -c user_data/config_backtest.json -s HarmonicDivergence -p BTC/USDT:USDT --timeframe 15m --timerange 20240901-20241001
```

---

## 接口版本与兼容

- `INTERFACE_VERSION = 2`，但策略已使用 `enter_long/exit_long` 列，框架会做兼容映射。若后续扩展做空/杠杆，建议迁移至 `INTERFACE_VERSION = 3` 并补全相关回调。

---

## 性能与稳健性建议

- 仅在新 K 线计算：将 `process_only_new_candles` 设为 `True` 可显著降耗与稳定行为。
- 启动 K 线数：若后续用到 `EMA200` 等长周期指标，应将 `startup_candle_count` 提升至 ≥200。
- 复核“枢轴/背离”窗口：`window=5` 可做成可优化参数，适配不同波动环境。
- 合理过滤：可增加趋势过滤（如 `ema50 > ema200` 且 `close > ema50`）避免强趋势逆势操作。

---

## 可选增强（改进建议）

1) 背离质量分层：
   - 高权重（如 RSI/MACD/MFI），中权重（Stoch/CCI/AO），低权重（ROC/UO/ADX）。
   - 仅当高权重指标出现 ≥ N 个背离时才入场，减少噪声。

2) 趋势过滤：
   - 只在 `ema50 > ema200` 且 `close > ema50` 的上升趋势中做多。

3) 自定义离场（ATR/盈亏比）：
   - 根据 `ATR%` 自适应止盈：高波动设置更高止盈，低波动降低止盈目标。
   - 或者基于 1:2 风险收益比（入场 ATR 止损确定风险，目标利润=2×风险）。

4) 多周期共振：
   - 在 15m 出现背离的同时，检查 1h 是否也出现背离，增强信号置信度。

5) 参数可优化：
   - `window`、`ATR` 倍数、`two_bands_check` 过滤强度、趋势过滤条件做成 `*Parameter`，配合 `hyperopt` 自动搜索最优组合。

---

## 验证流程与命令

1) 下载数据：

```bash
freqtrade download-data --timeframes 15m -p BTC/USDT:USDT
```

2) 回测：

```bash
freqtrade backtesting -c user_data/config_backtest.json -s HarmonicDivergence --timeframe 15m --timerange 20240101-20241001 --enable-protections
```

3) 可视化：

```bash
freqtrade plot-dataframe -c user_data/config_backtest.json -s HarmonicDivergence -p BTC/USDT:USDT --timeframe 15m --timerange 20240901-20241001
```

4) 干跑/实盘（谨慎）：

```bash
freqtrade trade -c user_data/config.json -s HarmonicDivergence
```

---

## 风险提示

- 背离是“动能变化”信号，强趋势行情下可能失效。结合趋势过滤与保护策略更稳健。
- 期货/杠杆风险较高，务必控制仓位、使用隔离保证金与严格止损。
- 回测与实盘存在滑点与流动性差异。手续费+滑点参数应尽量贴近真实环境。

---

## 小结

HarmonicDivergence 通过“枢轴+多指标背离”定位潜在反转，配合通道过滤与 ATR 止损，能在 15m 周期内进行较高频的反转交易。配合趋势过滤、离场优化与参数化超参搜索，有望进一步提高稳健性与收益风险比。实盘前建议在多币种、多周期上回测与干跑，验证稳定性后再小额上线。

