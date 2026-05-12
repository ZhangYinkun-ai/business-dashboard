# 个人业务看板

业务数据 + 快递行业行情一体化看板，支持 ODPS 数据源接入，行情每日 12:00 自动更新。

## 功能模块

### 1. 业务数据
- **商家寄件**、**送货上门**、**快递拦截** 三大项目切换
- 各快递服务商数据：预算金额、已下单金额、降本金额、已降本金额、中标单量
- 2026 年各月日均单量趋势图
- 预算 vs 已下单对比图、降本进度图

### 2. 行业行情
- 快递上市公司实时股价（顺丰、中通、韵达、圆通、申通）
- 行业宏观数据：业务量、同比增速、价格指数
- 油价数据：0 号柴油、92/95 号汽油
- 行业动态新闻

## 本地运行

```bash
npm install
npm start
```

访问 http://localhost:3000

## 部署到 Vercel（推荐）

### 1. 安装 Vercel CLI
```bash
npm i -g vercel
```

### 2. 登录并部署
```bash
cd dashboard
vercel --prod
```

### 3. 配置环境变量（ODPS 数据源）
在 Vercel Dashboard → Project Settings → Environment Variables 中添加：

| 变量名 | 说明 |
|--------|------|
| ODPS_ACCESS_KEY_ID | 阿里云 AccessKey ID |
| ODPS_ACCESS_KEY_SECRET | 阿里云 AccessKey Secret |
| ODPS_PROJECT | ODPS 项目名称 |
| ODPS_ENDPOINT | ODPS 服务地址（默认即可） |

### 4. 配置 ODPS SQL

修改 `lib/odps-client.js` 中的 SQL，匹配您的实际表名和字段：

```javascript
const projectSqlMap = {
  '商家寄件': `SELECT carrier_name, ... FROM your_db.merchant_delivery_summary WHERE year = 2026`,
  '送货上门': `SELECT carrier_name, ... FROM your_db.door_to_door_summary WHERE year = 2026`,
  '快递拦截': `SELECT carrier_name, ... FROM your_db.express_intercept_summary WHERE year = 2026`
};
```

## 定时任务

- **行情更新**：每天 12:00（Asia/Shanghai）自动更新
- **业务数据**：每小时自动刷新
- 支持手动点击"刷新数据"按钮即时更新

## 数据降级

若 ODPS 未配置或连接失败，看板会自动展示演示数据，不影响页面正常浏览。

## 技术栈

- 后端：Node.js + Express
- 前端：原生 HTML + Chart.js + Tailwind CSS
- 行情数据：腾讯财经 API
- 定时任务：node-cron
