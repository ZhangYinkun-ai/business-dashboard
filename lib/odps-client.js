/**
 * ODPS (MaxCompute) 客户端封装
 * 使用方法：
 *   1. 在环境变量中配置 ODPS_ACCESS_KEY_ID / ODPS_ACCESS_KEY_SECRET / ODPS_PROJECT / ODPS_ENDPOINT
 *   2. 或在 .env 文件中配置
 */

const ODPS = require('@alicloud/odps');

const config = {
  accessKeyId: process.env.ODPS_ACCESS_KEY_ID || '',
  accessKeySecret: process.env.ODPS_ACCESS_KEY_SECRET || '',
  project: process.env.ODPS_PROJECT || '',
  endpoint: process.env.ODPS_ENDPOINT || 'http://service.odps.aliyun.com/api',
  tunnelEndpoint: process.env.ODPS_TUNNEL_ENDPOINT || undefined
};

let odps = null;

function getClient() {
  if (!config.accessKeyId || !config.accessKeySecret || !config.project) {
    throw new Error('ODPS 未配置，请设置环境变量: ODPS_ACCESS_KEY_ID, ODPS_ACCESS_KEY_SECRET, ODPS_PROJECT');
  }
  if (!odps) {
    odps = new ODPS(config);
  }
  return odps;
}

/**
 * 执行业务数据查询
 * 请根据实际表结构调整 SQL
 */
async function getBusinessData() {
  const client = getClient();

  // ============ 请根据实际表名和字段修改以下 SQL ============
  const projectSqlMap = {
    '商家寄件': `
      SELECT 
        carrier_name,
        budget_amount / 10000 AS budget,
        ordered_amount / 10000 AS ordered,
        savings_target / 10000 AS savings_target,
        savings_actual / 10000 AS savings_actual,
        bid_volume / 10000 AS bid_volume,
        year_month,
        daily_avg_volume
      FROM your_project.merchant_delivery_summary
      WHERE year = 2026
    `,
    '送货上门': `
      SELECT 
        carrier_name,
        budget_amount / 10000 AS budget,
        ordered_amount / 10000 AS ordered,
        savings_target / 10000 AS savings_target,
        savings_actual / 10000 AS savings_actual,
        bid_volume / 10000 AS bid_volume,
        year_month,
        daily_avg_volume
      FROM your_project.door_to_door_summary
      WHERE year = 2026
    `,
    '快递拦截': `
      SELECT 
        carrier_name,
        budget_amount / 10000 AS budget,
        ordered_amount / 10000 AS ordered,
        savings_target / 10000 AS savings_target,
        savings_actual / 10000 AS savings_actual,
        bid_volume / 10000 AS bid_volume,
        year_month,
        daily_avg_volume
      FROM your_project.express_intercept_summary
      WHERE year = 2026
    `
  };

  const carriers = ['顺丰速运', '中通快递', '韵达快递', '圆通速递', '申通快递', '极兔速递', '邮政电商标快'];
  const projects = ['商家寄件', '送货上门', '快递拦截'];

  const result = {
    carriers: [],
    projects: [],
    summary: {
      totalBudget: 0,
      totalOrdered: 0,
      totalSavingsTarget: 0,
      totalSavingsActual: 0,
      totalBidVolume: 0
    }
  };

  // 由于 ODPS 查询可能涉及多张表，这里提供框架
  // 实际使用时，请根据您的数据模型调整 SQL 和数据组装逻辑

  for (const projectName of projects) {
    const sql = projectSqlMap[projectName];
    try {
      // 执行 ODPS SQL（同步查询示例）
      // 注意：实际生产环境建议使用 instance 方式执行异步查询
      const instances = await client.instances.create({
        projectName: config.project,
        type: 'SQL',
        query: sql
      });
      
      // 等待实例完成并获取结果（简化示例）
      // 实际使用时请参考 ODPS SDK 文档
    } catch (e) {
      console.warn(`查询 ${projectName} 数据失败:`, e.message);
    }
  }

  // 如果 ODPS 查询成功，组装结果
  // 否则抛出错误，让上层返回演示数据
  throw new Error('请根据实际表结构配置 ODPS SQL 查询');
}

module.exports = {
  getClient,
  getBusinessData,
  config
};
