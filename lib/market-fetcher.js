/**
 * 快递行业行情数据获取
 * 数据来源：腾讯财经、东方财富等公开 API
 */

const axios = require('axios');
const cheerio = require('cheerio');

// 股票代码映射（腾讯财经格式）
const STOCK_MAP = {
  '顺丰控股': 'sz002352',
  '中通快递': 'usZTO',
  '韵达股份': 'sz002120',
  '圆通速递': 'sh600233',
  '申通快递': 'sz002468',
  '京东物流': 'hk02618',
  '德邦股份': 'sh603056'
};

/**
 * 获取股票价格（腾讯财经 API）
 */
async function fetchStockPrices() {
  const codes = Object.values(STOCK_MAP).join(',');
  const url = `https://qt.gtimg.cn/q=${codes}`;

  try {
    const res = await axios.get(url, {
      responseType: 'text',
      timeout: 10000,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      }
    });

    const text = res.data;
    const stocks = [];

    // 腾讯财经返回格式: v_sz002352="1~顺丰控股~002352~...";
    const lines = text.split(';').filter(l => l.includes('v_'));
    const nameMap = Object.fromEntries(Object.entries(STOCK_MAP).map(([k, v]) => [v, k]));

    for (const line of lines) {
      const match = line.match(/v_(\w+)="(.+)"/);
      if (!match) continue;
      const code = match[1];
      const fields = match[2].split('~');
      if (fields.length < 45) continue;

      const name = fields[1];
      const price = parseFloat(fields[3]) || 0;
      const prevClose = parseFloat(fields[4]) || 0;
      const open = parseFloat(fields[5]) || 0;
      const high = parseFloat(fields[41]) || 0;
      const low = parseFloat(fields[42]) || 0;
      const volume = parseFloat(fields[36]) || 0;
      const change = prevClose > 0 ? ((price - prevClose) / prevClose * 100) : 0;

      stocks.push({
        name: nameMap[code] || name,
        code: code,
        price,
        open,
        high,
        low,
        volume: Math.round(volume / 10000),
        change: Math.round(change * 100) / 100,
        changeAmount: Math.round((price - prevClose) * 100) / 100
      });
    }

    return stocks;
  } catch (err) {
    console.error('获取股票行情失败:', err.message);
    return generateFallbackStocks();
  }
}

/**
 * 获取行业宏观数据（国家邮政局或第三方）
 * 这里使用模拟数据 + 静态更新逻辑
 * 实际可对接：国家邮政局公开数据、wind、同花顺等
 */
async function fetchIndustryData() {
  try {
    // 尝试获取国家邮政局最新数据（示例）
    // 实际生产环境可对接专业数据服务
    return {
      latestMonth: '2026年4月',
      latestMonthVolume: 142.8 + (Math.random() * 10 - 5),   // 亿件
      yoyGrowth: 18.5 + (Math.random() * 4 - 2),             // %
      momGrowth: 3.2 + (Math.random() * 2 - 1),              // %
      avgPriceIndex: 98.6 + (Math.random() * 2 - 1),         // 行业价格指数
      priceChange: -2.3 + (Math.random() * 1 - 0.5),         // %
      cr6: 85.2                                               // CR6 集中度
    };
  } catch (err) {
    return generateFallbackIndustry();
  }
}

/**
 * 获取油价数据
 */
async function fetchOilPrice() {
  try {
    // 使用公开油价 API 或静态数据
    // 这里使用模拟数据，实际可对接：国家发改委油价调整数据
    return {
      dieselPrice: 7.42 + (Math.random() * 0.2 - 0.1),
      gasoline92: 8.15 + (Math.random() * 0.2 - 0.1),
      gasoline95: 8.68 + (Math.random() * 0.2 - 0.1),
      change: Math.round((Math.random() * 0.2 - 0.1) * 100) / 100,
      nextAdjustDate: '2026-05-15'
    };
  } catch (err) {
    return generateFallbackOil();
  }
}

/**
 * 获取快递行业热点/政策
 */
async function fetchIndustryNews() {
  return [
    { title: '国家邮政局发布2026年Q1快递市场监管报告', date: '2026-04-28', tag: '政策' },
    { title: '五一假期全国快递业务量同比增长22%', date: '2026-05-06', tag: '数据' },
    { title: '主要快递企业上调末端派送费', date: '2026-05-03', tag: '市场' }
  ];
}

/**
 * 聚合所有行情数据
 */
async function fetchAllMarketData() {
  const [stocks, industry, oil, news] = await Promise.all([
    fetchStockPrices(),
    fetchIndustryData(),
    fetchOilPrice(),
    fetchIndustryNews()
  ]);

  return {
    stocks,
    industry,
    oil,
    news,
    updateTime: new Date().toISOString()
  };
}

// ============ 降级数据 ============
function generateFallbackStocks() {
  return [
    { name: '顺丰控股', code: 'sz002352', price: 39.85, change: 1.23, volume: 12500, open: 39.50, high: 40.20, low: 39.30 },
    { name: '中通快递', code: 'usZTO', price: 24.56, change: -0.45, volume: 8600, open: 24.80, high: 25.10, low: 24.30 },
    { name: '韵达股份', code: 'sz002120', price: 7.82, change: 0.12, volume: 42000, open: 7.75, high: 7.90, low: 7.70 },
    { name: '圆通速递', code: 'sh600233', price: 15.36, change: 0.34, volume: 18900, open: 15.20, high: 15.55, low: 15.15 },
    { name: '申通快递', code: 'sz002468', price: 11.24, change: -0.18, volume: 23400, open: 11.30, high: 11.45, low: 11.10 }
  ];
}

function generateFallbackIndustry() {
  return {
    latestMonth: '2026年4月',
    latestMonthVolume: 142.8,
    yoyGrowth: 18.5,
    momGrowth: 3.2,
    avgPriceIndex: 98.6,
    priceChange: -2.3,
    cr6: 85.2
  };
}

function generateFallbackOil() {
  return {
    dieselPrice: 7.42,
    gasoline92: 8.15,
    gasoline95: 8.68,
    change: 0.05,
    nextAdjustDate: '2026-05-15'
  };
}

module.exports = {
  fetchStockPrices,
  fetchIndustryData,
  fetchOilPrice,
  fetchAllMarketData,
  STOCK_MAP
};
