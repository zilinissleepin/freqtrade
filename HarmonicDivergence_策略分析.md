# HarmonicDivergence 策略详细分析

## 📊 策略概述

**HarmonicDivergence** 是一个基于**背离（Divergence）**原理的量化交易策略，通过检测价格与技术指标之间的背离来寻找反转机会。

---

## 🎯 核心原理

### **什么是背离（Divergence）？**

背离是指**价格走势**与**技术指标**走势不一致的现象：

#### **1. 看涨背离（Bullish Divergence）** 🟢
- **价格**：创新低（Lower Low）
- **指标**：走高（Higher Low）
- **含义**：下跌动能减弱，可能反转上涨
- **交易信号**：买入

**示例：**
```
价格:  ↓ 100 → 95 → 90 ← 创新低
指标:  ↑  30 → 32 → 35 ← 走高（背离！）
结论: 可能触底反弹
```

#### **2. 看跌背离（Bearish Divergence）** 🔴
- **价格**：创新高（Higher High）
- **指标**：走低（Lower High）
- **含义**：上涨动能减弱，可能反转下跌
- **交易信号**：卖出

**示例：**
```
价格:  ↑ 100 → 105 → 110 ← 创新高
指标:  ↓  70 →  68 →  65 ← 走低（背离！）
结论: 可能见顶回落
```

---

## 🔧 策略配置参数

### **1. 基础参数**

```python
timeframe = '15m'              # 时间周期：15分钟
minimal_roi = {                # 分阶段止盈
    "0": 0.05,                 # 任何时候利润 ≥5% 就卖出
    "30": 0.03,                # 30分钟后利润 ≥3% 就卖出
    "60": 0.02,                # 60分钟后利润 ≥2% 就卖出
    "300": 0.01,               # 300分钟(5小时)后利润 ≥1% 就卖出
}
stoploss = -0.5                # 固定止损：-50%（但实际使用动态止损）
```

### **2. 追踪止损**

```python
trailing_stop = True                    # 启用追踪止损
trailing_stop_positive = 0.007          # 盈利 >0.7% 后启用追踪
trailing_stop_positive_offset = 0.015   # 盈利达到 1.5% 才触发追踪
trailing_only_offset_is_reached = True  # 只有达到offset才追踪
```

**工作原理：**
1. 当利润达到 **1.5%** 时，开始追踪止损
2. 止损价位跟随最高价，保持 **0.7%** 的距离
3. 如果价格回撤超过 0.7%，触发止损

---

## 📈 技术指标体系

策略使用了 **11 个技术指标** 来检测背离：

### **动量指标（Momentum Indicators）**

| 指标 | 全名 | 用途 | 范围 |
|------|------|------|------|
| **RSI** | 相对强弱指数 | 超买超卖 | 0-100 |
| **Stoch** | 随机指标 | 超买超卖 | 0-100 |
| **ROC** | 变化率 | 价格变动速度 | -∞ to +∞ |
| **UO** | 终极振荡器 | 多周期动量 | 0-100 |
| **AO** | 动量振荡器 | 价格动量 | -∞ to +∞ |
| **MACD** | 指数平滑移动平均线 | 趋势方向 | -∞ to +∞ |
| **CCI** | 商品通道指数 | 超买超卖 | -∞ to +∞ |
| **MFI** | 资金流量指数 | 资金流向 | 0-100 |

### **成交量指标**

| 指标 | 全名 | 用途 |
|------|------|------|
| **CMF** | 蔡金资金流 | 资金流向强度 |
| **OBV** | 能量潮 | 累计成交量 |

### **趋势指标**

| 指标 | 全名 | 用途 |
|------|------|------|
| **ADX** | 平均趋向指数 | 趋势强度 |

### **辅助指标**

```python
# 布林带（Bollinger Bands）
bollinger_upperband = EMA(20) + 2 * StdDev
bollinger_lowerband = EMA(20) - 2 * StdDev

# 肯特纳通道（Keltner Channel）
kc_upperband = EMA(20) + ATR(10)
kc_middleband = EMA(20)
kc_lowerband = EMA(20) - ATR(10)

# 指数移动平均线（EMA）
ema9, ema20, ema50, ema200

# ATR（真实波幅）- 用于动态止损
atr = Average True Range (14期)
```

---

## 🔍 核心算法详解

### **1. 枢轴点检测（Pivot Points）**

**位置：** `pivot_points()` 函数（667-720行）

**作用：** 识别价格的局部高点和低点

**算法：**
```python
window = 5  # 左右各5根K线

# 检测高点
if close[i] > close[i-5:i] and close[i] > close[i+1:i+6]:
    pivot_highs[i] = close[i]  # 标记为枢轴高点

# 检测低点
if close[i] < close[i-5:i] and close[i] < close[i+1:i+6]:
    pivot_lows[i] = close[i]   # 标记为枢轴低点
```

**可视化：**
```
价格: 100 → 105 → 110 → 108 → 106 → 104 → 102
           ↑
         枢轴高点（110是前后5根K线的最高点）
```

---

### **2. 背离检测（Divergence Finder）**

**位置：** `divergence_finder_dataframe()` 函数（528-632行）

**核心逻辑：**

#### **看涨背离检测（Bullish）** 🟢

```python
def bullish_divergence_finder(dataframe, indicator, low_iterator, index):
    if 当前是枢轴低点:
        current_pivot = 当前枢轴
        # 查找前5个枢轴低点
        for prev_pivot in 前5个枢轴低点:
            # 条件1：价格走低，指标走高（经典背离）
            if (价格[current] < 价格[prev] and 指标[current] > 指标[prev]):
                return (prev_pivot, current_pivot)

            # 条件2：价格走高，指标走低（隐藏背离）
            if (价格[current] > 价格[prev] and 指标[current] < 指标[prev]):
                return (prev_pivot, current_pivot)
```

**检测步骤：**
1. 找到当前枢轴低点
2. 向前查找最多5个历史枢轴低点
3. 比较价格和指标的走势
4. 如果发现背离，记录并绘制连接线

#### **看跌背离检测（Bearish）** 🔴

```python
def bearish_divergence_finder(dataframe, indicator, high_iterator, index):
    if 当前是枢轴高点:
        current_pivot = 当前枢轴
        for prev_pivot in 前5个枢轴高点:
            # 条件1：价格走高，指标走低（经典背离）
            if (价格[current] > 价格[prev] and 指标[current] < 指标[prev]):
                return (prev_pivot, current_pivot)

            # 条件2：价格走低，指标走高（隐藏背离）
            if (价格[current] < 价格[prev] and 指标[current] > 指标[prev]):
                return (prev_pivot, current_pivot)
```

---

### **3. 多指标背离统计**

**位置：** `add_divergences()` 函数（519-526行）

策略对 **11 个指标** 都进行背离检测：

```python
add_divergences(dataframe, 'rsi')    # RSI 背离
add_divergences(dataframe, 'stoch')  # 随机指标背离
add_divergences(dataframe, 'roc')    # ROC 背离
add_divergences(dataframe, 'uo')     # 终极振荡器背离
add_divergences(dataframe, 'ao')     # 动量振荡器背离
add_divergences(dataframe, 'macd')   # MACD 背离
add_divergences(dataframe, 'cci')    # CCI 背离
add_divergences(dataframe, 'cmf')    # CMF 背离
add_divergences(dataframe, 'obv')    # OBV 背离
add_divergences(dataframe, 'mfi')    # MFI 背离
add_divergences(dataframe, 'adx')    # ADX 背离
```

**汇总统计：**
- `total_bullish_divergences_count`：看涨背离数量
- `total_bullish_divergences_names`：哪些指标出现背离（如 "RSI<br>MACD<br>CCI"）
- `total_bearish_divergences_count`：看跌背离数量
- `total_bearish_divergences_names`：看跌背离指标名称

---

## 🎯 入场条件（Buy Signal）

**位置：** `populate_entry_trend()` 函数（383-409行）

### **入场逻辑：**

```python
买入 if (
    # 条件1：检测到看涨背离（滞后1根K线确认）
    total_bullish_divergences.shift() > 0

    # 条件2：通道过滤 - 价格不能在极端位置
    & two_bands_check(dataframe)

    # 条件3：有成交量
    & volume > 0
)
```

### **条件详解：**

#### **1. 看涨背离确认**
```python
dataframe['total_bullish_divergences'].shift() > 0
```
- 前一根K线检测到看涨背离
- 使用 `shift()` 避免未来数据泄露

#### **2. 通道过滤（two_bands_check）**

**位置：** `two_bands_check()` 函数（466-473行）

```python
def two_bands_check(dataframe):
    # 检测是否同时穿透KC通道上下轨（极端波动）
    extreme_volatility = (
        (low < kc_lowerband) & (high > kc_upperband)
    )
    # 返回非极端波动的情况（~表示取反）
    return ~extreme_volatility
```

**含义：**
- ✅ **允许**：价格在正常范围内
- ❌ **拒绝**：价格同时触及KC通道上下轨（异常波动，可能是假信号）

---

## 🚪 离场条件（Sell Signal）

策略使用 **多重离场机制**：

### **1. 手动离场信号（几乎不触发）**

```python
def populate_exit_trend(dataframe, metadata):
    # 实际上总是返回 0（不卖出）
    dataframe.loc[(volume > 0), 'exit_long'] = 0
```

### **2. ROI 分阶段止盈** 💰

```python
minimal_roi = {
    "0": 0.05,      # 立即卖出如果利润 ≥5%
    "30": 0.03,     # 30分钟后卖出如果利润 ≥3%
    "60": 0.02,     # 60分钟后卖出如果利润 ≥2%
    "300": 0.01,    # 300分钟后卖出如果利润 ≥1%
}
```

**实际效果：**
- 开仓后任何时刻利润达到 5%，立即止盈
- 持仓 30 分钟后，利润 3% 就可以止盈
- 持仓 5 小时后，只要盈利 1% 就止盈

### **3. 动态止损（custom_stoploss）** 🛑

**位置：** `custom_stoploss()` 函数（442-460行）

```python
def custom_stoploss(pair, trade, current_time, current_rate, current_profit):
    # 找到买入那根K线
    buy_candle = 找到开仓K线

    # 动态止损 = 买入K线的最低价 - ATR
    stoploss = buy_candle['low'] - buy_candle['atr']

    # 转换为百分比
    return (stoploss / current_rate) - 1
```

**示例计算：**
```
买入价格: 100 USDT
买入K线最低价: 98 USDT
ATR: 2 USDT
止损价 = 98 - 2 = 96 USDT
止损百分比 = (96 / 100) - 1 = -4%
```

**优点：**
- ✅ 根据市场波动（ATR）动态调整
- ✅ 波动大时止损宽松，波动小时止损紧密
- ✅ 基于技术结构（支撑位）而非固定百分比

### **4. 追踪止损（Trailing Stop）** 📈

```python
trailing_stop = True
trailing_stop_positive = 0.007          # 盈利后保持0.7%距离
trailing_stop_positive_offset = 0.015   # 盈利1.5%才启动
trailing_only_offset_is_reached = True  # 必须达到offset
```

**工作流程：**
```
开仓价: 100 USDT
价格涨到 101.5 USDT (利润 +1.5%) → 启动追踪止损
止损价设在: 101.5 * (1 - 0.007) = 100.79 USDT

价格继续涨到 105 USDT → 止损价上移
止损价更新为: 105 * (1 - 0.007) = 104.27 USDT

价格回落到 104.2 USDT → 触发止损，平仓
最终利润: +4.2%
```

---

## 📊 回测结果分析（LINK/USDT）

### **测试参数：**
- **时间范围**：2024-10-22 到 2025-10-21（1年）
- **交易对**：LINK/USDT（现货）
- **时间周期**：15分钟
- **初始资金**：1000 USDT

### **核心指标：**

| 指标 | 数值 | 说明 |
|------|------|------|
| **总收益率** | **+133.94%** | 🎉 年化收益 |
| **最终余额** | 2339.38 USDT | 本金翻倍+ |
| **交易次数** | 1047 笔 | 平均每天 2.88 笔 |
| **胜率** | 62.3% | 652胜/395亏 |
| **平均持仓** | 3小时18分 | 短线策略 |
| **最大回撤** | 5.64% | ✅ 非常小 |
| **Sharpe Ratio** | 9.28 | 🌟 极优秀 |
| **Sortino Ratio** | 20.35 | 🌟 风险调整后收益极佳 |
| **盈亏比** | 1.45 | 平均盈利 > 平均亏损 |

### **离场原因分布：**

| 离场方式 | 次数 | 占比 | 平均收益 | 总收益 |
|---------|------|------|---------|--------|
| **ROI 止盈** | 265 | 25.2% | **+1.52%** | +2220 USDT ✅ |
| **追踪止损** | 781 | 74.6% | **-0.18%** | -880 USDT |
| **手动信号** | 1 | 0.1% | -0.09% | -0.7 USDT |
| **Force Exit** | 0 | 0% | - | - |

### **关键洞察：**

#### ✅ **策略优势：**

1. **高胜率 ROI**：
   - 265笔达到止盈目标（1%-5%）
   - 100%胜率（全部盈利）
   - 贡献了 +2220 USDT 利润

2. **追踪止损保护**：
   - 781笔由追踪止损离场
   - 平均只亏 -0.18%（非常小）
   - 虽然有 394 笔亏损，但总体只亏 -880 USDT

3. **风险控制极佳**：
   - 最大回撤仅 5.64%
   - Sharpe 9.28（>3就算优秀，>5极优秀）
   - 回撤持续时间短（15天）

4. **高频交易**：
   - 日均 2.88 笔交易
   - 抓住短期反转机会
   - 快进快出

#### ⚠️ **潜在问题：**

1. **追踪止损过早**：
   - 74.6%的交易由追踪止损离场
   - 可能错失更大涨幅
   - 建议：调整 `trailing_stop_positive_offset` 从 1.5% → 2.5%

2. **交易频率高**：
   - 日均3笔交易，手续费开销较大
   - 假设0.1%手续费，1047笔 × 2（买卖）× 0.1% = 约 2% 利润被手续费吃掉

3. **单一币种**：
   - 只在 LINK 上测试
   - 需要在多个币种上验证稳定性

---

## 🎨 可视化配置

策略提供了强大的图表功能（PlotConfig类）：

### **主图显示：**
- 布林带（上下轨 + 阴影填充）
- 肯特纳通道（上中下轨）
- EMA 9, 20, 50, 200
- 枢轴高低点（钻石标记）
- **背离标记**：
  - 🟢 绿色菱形 = 看涨背离
  - 🔴 红色菱形 = 看跌背离
  - 虚线连接枢轴点

### **副图显示：**
- ATR（真实波幅）

---

## 💡 策略改进建议

### **1. 背离质量筛选**

当前策略对所有背离一视同仁，可以增加权重：

```python
# 高权重指标（准确性高）
high_weight = ['rsi', 'macd', 'mfi']

# 中权重指标
mid_weight = ['stoch', 'cci', 'ao']

# 低权重指标
low_weight = ['roc', 'uo', 'adx']

# 只有高权重指标出现 ≥2 个背离才入场
if count_divergences(high_weight) >= 2:
    enter_long = 1
```

### **2. 趋势过滤**

添加大趋势判断，避免逆势交易：

```python
# 只在上升趋势中做多
trend_filter = (ema50 > ema200) & (close > ema50)
enter_long = bullish_divergence & trend_filter
```

### **3. 动态ROI**

根据市场波动调整止盈：

```python
def custom_exit(self, trade, current_profit):
    atr_pct = atr / close  # ATR百分比

    if atr_pct > 0.03:  # 高波动
        target_profit = 0.08  # 8%止盈
    else:  # 低波动
        target_profit = 0.03  # 3%止盈

    return current_profit > target_profit
```

### **4. 多时间周期确认**

```python
# 检查更高时间周期（如1小时）的背离
informative_1h = get_pair_dataframe(pair, '1h')
add_divergences(informative_1h, 'rsi')

# 15分钟和1小时同时出现背离，信号更强
strong_signal = (
    divergence_15m > 0 &
    divergence_1h > 0
)
```

---

## 📚 关键函数速查表

| 函数 | 位置 | 功能 |
|------|------|------|
| `populate_indicators()` | 260-381 | 计算所有技术指标 |
| `populate_entry_trend()` | 383-409 | 生成买入信号 |
| `populate_exit_trend()` | 411-423 | 生成卖出信号（几乎不用） |
| `custom_stoploss()` | 442-460 | 动态止损逻辑 |
| `pivot_points()` | 667-720 | 检测枢轴高低点 |
| `divergence_finder_dataframe()` | 528-632 | 核心背离检测 |
| `bullish_divergence_finder()` | 648-660 | 看涨背离查找 |
| `bearish_divergence_finder()` | 634-646 | 看跌背离查找 |
| `two_bands_check()` | 466-473 | 通道过滤 |
| `emaKeltner()` | 734-741 | 计算肯特纳通道 |

---

## 🎯 总结

### **策略特点：**

✅ **优势：**
1. 多指标背离，信号可靠性高
2. 风险控制严格（动态止损 + 追踪止损）
3. 回测表现优异（133% 年化收益，5.64% 回撤）
4. 高频短线，资金利用率高
5. 可视化完善，便于分析

⚠️ **局限：**
1. 背离检测计算量大（11个指标）
2. 追踪止损可能过早离场
3. 依赖枢轴点检测，对噪音敏感
4. 单边做多策略（未使用看跌背离做空）

### **适用场景：**
- ✅ 震荡市、区间市
- ✅ 15分钟短线交易
- ✅ 波动适中的币种
- ❌ 强趋势市场（可能频繁止损）
- ❌ 低流动性币种（枢轴点不准确）

### **推荐配置：**
- **时间周期**：15m（已优化）
- **最大持仓**：3-5个
- **资金管理**：每笔2-5%仓位
- **币种选择**：主流币（BTC/ETH/LINK等）
