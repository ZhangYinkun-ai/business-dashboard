const express = require('express');
const cors = require('cors');
const path = require('path');
const cron = require('node-cron');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// ============ 内存数据缓存 ============
let businessDataCache = null;
let marketDataCache = null;
let lastUpdateTime = null;

// ============ ODPS 业务数据 API ============
app.get('/api/business', async (req, res) => {
  try {
    const { getBusinessData } = require('./lib/odps-client');
    const data = await getBusinessData();
    businessDataCache = data;
    res.json({ success: true, data, updateTime: new Date().toISOString() });
  } catch (err) {
    // 如果 ODPS 未配置，返回演示数据
    const demoData = generateDemoBusinessData();
    businessDataCache = demoData;
    res.json({ success: true, data: demoData, updateTime: new Date().toISOString(), note: '演示数据，请配置ODPS连接' });
  }
});

// ============ 行情数据 API ============
app.get('/api/market', async (req, res) => {
  try {
    const { fetchAllMarketData } = require('./lib/market-fetcher');
    const data = await fetchAllMarketData();
    marketDataCache = data;
    lastUpdateTime = new Date().toISOString();
    res.json({ success: true, data, updateTime: lastUpdateTime });
  } catch (err) {
    console.error('行情数据获取失败:', err.message);
    // 返回缓存或演示数据
    const fallback = marketDataCache || generateDemoMarketData();
    res.json({ success: true, data: fallback, updateTime: lastUpdateTime || new Date().toISOString(), note: '使用缓存/演示数据' });
  }
});

// ============ 健康检查 ============
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', time: new Date().toISOString() });
});

// ============ 演示数据生成器 ============
function generateDemoBusinessData() {
  const carriers = [
    { name: '顺丰速运', code: 'sf' },
    { name: '中通快递', code: 'zt' },
    { name: '韵达快递', code: 'yd' },
    { name: '圆通速递', code: 'yt' },
    { name: '申通快递', code: 'st' },
    { name: '极兔速递', code: 'jt' },
    { name: '邮政电商标快', code: 'yz' }
  ];

  const projects = ['商家寄件', '送货上门', '快递拦截'];

  const monthlyDailyAvg = {};
  for (let m = 1; m <= 12; m++) {
    const daysInMonth = new Date(2026, m, 0).getDate();
    const isFuture = new Date(2026, m - 1, 1) > new Date();
    const today = new Date();
    const currentMonth = today.getMonth() + 1;
    
    if (isFuture) {
      monthlyDailyAvg[m] = null;
    } else if (m === currentMonth) {
      const passedDays = today.getDate() - 1;
      const totalOrders = passedDays * (150000 + Math.floor(Math.random() * 50000));
      monthlyDailyAvg[m] = Math.round(totalOrders / passedDays);
    } else {
      monthlyDailyAvg[m] = 150000 + Math.floor(Math.random() * 100000);
    }
  }

  return {
    carriers: carriers.map(c => ({
      ...c,
      budget: Math.round((500 + Math.random() * 1500) * 100) / 100,        // 预算（万元）
      ordered: Math.round((300 + Math.random() * 1200) * 100) / 100,        // 已下单（万元）
      savingsTarget: Math.round((50 + Math.random() * 200) * 100) / 100,    // 降本金额（万元）
      savingsActual: Math.round((30 + Math.random() * 150) * 100) / 100,    // 已降本金额（万元）
      bidVolume: Math.round((10 + Math.random() * 90) * 100) / 100,         // 中标单量（万单）
      monthlyDailyAvg
    })),
    projects: projects.map(p => ({
      name: p,
      budget: Math.round((800 + Math.random() * 2000) * 100) / 100,
      ordered: Math.round((500 + Math.random() * 1500) * 100) / 100,
      savingsTarget: Math.round((100 + Math.random() * 400) * 100) / 100,
      savingsActual: Math.round((60 + Math.random() * 300) * 100) / 100,
      bidVolume: Math.round((50 + Math.random() * 200) * 100) / 100
    })),
    summary: {
      totalBudget: 0,
      totalOrdered: 0,
      totalSavingsTarget: 0,
      totalSavingsActual: 0,
      totalBidVolume: 0
    }
  };
}

function generateDemoMarketData() {
  const stocks = [
    { name: '顺丰控股', code: '002352.SZ', price: 39.85, change: 1.23 },
    { name: '中通快递', code: 'ZTO.N', price: 24.56, change: -0.45 },
    { name: '韵达股份', code: '002120.SZ', price: 7.82, change: 0.12 },
    { name: '圆通速递', code: '600233.SH', price: 15.36, change: 0.34 },
    { name: '申通快递', code: '002468.SZ', price: 11.24, change: -0.18 }
  ];

  return {
    stocks,
    industry: {
      latestMonthVolume: 142.8,   // 亿件
      yoyGrowth: 18.5,            // %
      avgPriceIndex: 98.6,        // 价格指数
      priceChange: -2.3           // %
    },
    oil: {
      dieselPrice: 7.42,
      gasolinePrice: 8.15,
      change: 0.05
    },
    updateTime: new Date().toISOString()
  };
}

// ============ 定时任务：每天12:00更新行情 ============
cron.schedule('0 12 * * *', async () => {
  console.log(`[${new Date().toISOString()}] 开始定时更新行情数据...`);
  try {
    const { fetchAllMarketData } = require('./lib/market-fetcher');
    marketDataCache = await fetchAllMarketData();
    lastUpdateTime = new Date().toISOString();
    console.log('行情数据更新成功');
  } catch (err) {
    console.error('行情数据定时更新失败:', err.message);
  }
}, {
  timezone: 'Asia/Shanghai'
});

// 只在直接运行时启动服务器（本地开发）
// Vercel Serverless 环境下不调用 listen
if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`看板服务已启动: http://localhost:${PORT}`);
    console.log('定时任务已配置: 每天 12:00 (Asia/Shanghai) 自动更新行情');
  });
}

module.exports = app;
