@echo off
chcp 65001 >nul
echo ==========================================
echo   个人业务看板 - GitHub 一键部署脚本
echo ==========================================
echo.

REM 检查 git
where git >nul 2>nul
if %errorlevel% neq 0 (
    echo [错误] 未找到 git，请先安装 Git: https://git-scm.com/download/win
    pause
    exit /b 1
)

cd /d "%~dp0"

REM 配置 git 身份（如未配置）
git config user.name >nul 2>nul
if %errorlevel% neq 0 (
    git config user.email "user@example.com"
    git config user.name "Dashboard User"
)

echo 步骤 1/4: 输入 GitHub 用户名
set /p GH_USER=GitHub 用户名: 
if "%GH_USER%"=="" (
    echo [错误] 用户名不能为空
    pause
    exit /b 1
)

echo.
echo 步骤 2/4: 输入仓库名称（默认: business-dashboard）
set /p GH_REPO=仓库名称 [business-dashboard]: 
if "%GH_REPO%"=="" set GH_REPO=business-dashboard

echo.
echo 步骤 3/4: 输入 Personal Access Token
echo   如果没有 Token，请前往: https://github.com/settings/tokens/new
echo   勾选权限: repo (完整仓库权限)
set /p GH_TOKEN=Personal Access Token: 
if "%GH_TOKEN%"=="" (
    echo [错误] Token 不能为空
    pause
    exit /b 1
)

echo.
echo 步骤 4/4: 正在创建 GitHub 仓库并推送...
echo.

REM 调用 GitHub API 创建仓库
curl -s -X POST -H "Authorization: token %GH_TOKEN%" -H "Accept: application/vnd.github.v3+json" "https://api.github.com/user/repos" -d "{\"name\":\"%GH_REPO%\",\"private\":false}" > gh_response.json

REM 检查是否成功
type gh_response.json | findstr "html_url" >nul
if %errorlevel% neq 0 (
    echo [错误] 创建仓库失败，响应内容:
    type gh_response.json
    echo.
    echo 请检查 Token 是否有 repo 权限
    del gh_response.json >nul 2>nul
    pause
    exit /b 1
)

echo [成功] GitHub 仓库已创建: https://github.com/%GH_USER%/%GH_REPO%
echo.

REM 设置 remote 并推送
git remote remove origin >nul 2>nul
git remote add origin https://%GH_USER%:%GH_TOKEN%@github.com/%GH_USER%/%GH_REPO%.git
git branch -M main

echo 正在推送代码...
git push -u origin main

if %errorlevel% neq 0 (
    echo [错误] 推送失败
    del gh_response.json >nul 2>nul
    pause
    exit /b 1
)

del gh_response.json >nul 2>nul

echo.
echo ==========================================
echo [完成] 代码已推送到 GitHub!
echo 仓库地址: https://github.com/%GH_USER%/%GH_REPO%
echo.
echo 接下来启用 GitHub Pages:
echo 1. 打开: https://github.com/%GH_USER%/%GH_REPO%/settings/pages
echo 2. Branch 选择 main，文件夹选 /(root)
echo 3. 点击 Save
echo 4. 等待 1-2 分钟后访问:
echo    https://%GH_USER%.github.io/%GH_REPO%
echo ==========================================
pause
