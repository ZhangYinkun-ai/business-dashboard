# 个人业务看板 - 一键更新数据并推送到 GitHub Pages
# 使用方法：修改 src/data.json 后，运行此脚本自动推送
# 或：配置 ODPS 信息后，脚本自动拉取最新数据

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  个人业务看板 - 数据更新推送" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Set-Location $PSScriptRoot

# 检查 git
$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) {
    Write-Host "[错误] 未找到 git" -ForegroundColor Red
    Read-Host "按 Enter 退出"
    exit 1
}

Write-Host "步骤 1/3: 检查数据文件" -ForegroundColor Yellow
if (Test-Path "src/data.json") {
    $json = Get-Content "src/data.json" -Raw | ConvertFrom-Json
    Write-Host "  数据文件存在，最后更新: $($json.lastUpdated)" -ForegroundColor Green
} else {
    Write-Host "[警告] 未找到 src/data.json，将使用演示数据" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "步骤 2/3: 提交数据变更" -ForegroundColor Yellow

git add src/data.json
$hasChanges = (git diff --cached --name-only).Count -gt 0

if (-not $hasChanges) {
    Write-Host "  数据无变更，跳过提交" -ForegroundColor Gray
} else {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
    git commit -m "update: 业务数据更新 ($timestamp)"
    Write-Host "  提交成功" -ForegroundColor Green
}

Write-Host ""
Write-Host "步骤 3/3: 推送到 GitHub" -ForegroundColor Yellow

try {
    git push
    Write-Host "  推送成功!" -ForegroundColor Green
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "[完成] GitHub Pages 将在 1-2 分钟后自动更新" -ForegroundColor Green
    Write-Host "访问链接: https://zhangyinkun-ai.github.io/business-dashboard/" -ForegroundColor Yellow
    Write-Host "==========================================" -ForegroundColor Green
} catch {
    Write-Host "[错误] 推送失败: $_" -ForegroundColor Red
    Read-Host "按 Enter 退出"
    exit 1
}

Read-Host "按 Enter 退出"
