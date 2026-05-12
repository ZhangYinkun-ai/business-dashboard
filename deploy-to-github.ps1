# 个人业务看板 - GitHub 一键部署脚本 (PowerShell)
$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  个人业务看板 - GitHub 一键部署脚本" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 检查 git
$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) {
    Write-Host "[错误] 未找到 git，请先安装 Git: https://git-scm.com/download/win" -ForegroundColor Red
    Read-Host "按 Enter 退出"
    exit 1
}

Set-Location $PSScriptRoot

# 配置 git 身份
$gitName = git config user.name 2>$null
if (-not $gitName) {
    git config user.email "user@example.com"
    git config user.name "Dashboard User"
}

Write-Host "步骤 1/4: 输入 GitHub 用户名" -ForegroundColor Yellow
$GH_USER = Read-Host "GitHub 用户名"
if ([string]::IsNullOrWhiteSpace($GH_USER)) {
    Write-Host "[错误] 用户名不能为空" -ForegroundColor Red
    Read-Host "按 Enter 退出"
    exit 1
}

Write-Host ""
Write-Host "步骤 2/4: 输入仓库名称（默认: business-dashboard）" -ForegroundColor Yellow
$GH_REPO = Read-Host "仓库名称 [business-dashboard]"
if ([string]::IsNullOrWhiteSpace($GH_REPO)) { $GH_REPO = "business-dashboard" }

Write-Host ""
Write-Host "步骤 3/4: 输入 Personal Access Token" -ForegroundColor Yellow
Write-Host "  如果没有 Token，请前往: https://github.com/settings/tokens/new" -ForegroundColor Gray
Write-Host "  勾选权限: repo (完整仓库权限)" -ForegroundColor Gray
$GH_TOKEN = Read-Host "Personal Access Token"
if ([string]::IsNullOrWhiteSpace($GH_TOKEN)) {
    Write-Host "[错误] Token 不能为空" -ForegroundColor Red
    Read-Host "按 Enter 退出"
    exit 1
}

Write-Host ""
Write-Host "步骤 4/4: 正在创建 GitHub 仓库并推送..." -ForegroundColor Yellow
Write-Host ""

try {
    # 调用 GitHub API 创建仓库
    $body = @{ name = $GH_REPO; private = $false } | ConvertTo-Json -Compress
    $headers = @{
        Authorization = "token $GH_TOKEN"
        Accept = "application/vnd.github.v3+json"
    }
    $response = Invoke-RestMethod -Uri "https://api.github.com/user/repos" -Method Post -Headers $headers -Body $body -ContentType "application/json"

    Write-Host "[成功] GitHub 仓库已创建: $($response.html_url)" -ForegroundColor Green
    Write-Host ""

    # 设置 remote 并推送
    git remote remove origin 2>$null
    git remote add origin "https://$GH_USER`:$GH_TOKEN@github.com/$GH_USER/$GH_REPO.git"
    git branch -M main

    Write-Host "正在推送代码..." -ForegroundColor Yellow
    git push -u origin main

    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "[完成] 代码已推送到 GitHub!" -ForegroundColor Green
    Write-Host "仓库地址: https://github.com/$GH_USER/$GH_REPO" -ForegroundColor Green
    Write-Host ""
    Write-Host "接下来启用 GitHub Pages:" -ForegroundColor Cyan
    Write-Host "1. 打开: https://github.com/$GH_USER/$GH_REPO/settings/pages" -ForegroundColor White
    Write-Host "2. Branch 选择 main，文件夹选 /(root)" -ForegroundColor White
    Write-Host "3. 点击 Save" -ForegroundColor White
    Write-Host "4. 等待 1-2 分钟后访问:" -ForegroundColor White
    Write-Host "   https://$GH_USER.github.io/$GH_REPO" -ForegroundColor Yellow
    Write-Host "==========================================" -ForegroundColor Green
} catch {
    Write-Host "[错误] 部署失败: $_" -ForegroundColor Red
    Read-Host "按 Enter 退出"
    exit 1
}

Read-Host "按 Enter 退出"
