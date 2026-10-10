# ============================================================
#  PhoneAudio - 环境准备脚本
#  自动下载 scrcpy 到脚本同级目录，让你可以直接开始使用
#  用法：右键「使用 PowerShell 运行」，或双击 setup.bat
# ============================================================

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$root    = $PSScriptRoot
$target  = Join-Path $root 'scrcpy'
$version = 'v4.1'
$zipName = "scrcpy-win64-$version.zip"

function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }

Say ""
Say "  ==========================================" 'Cyan'
Say "          PhoneAudio   环境准备" 'Cyan'
Say "  ==========================================" 'Cyan'
Say ""

# 已经装好就直接跳过
if (Test-Path (Join-Path $target 'scrcpy.exe')) {
    Say "  [OK] scrcpy 已就位：$target" 'Green'
    Say "       现在可以直接双击『手机音频到电脑.bat』使用。" 'Gray'
    Say ""
    Read-Host "  按回车退出"
    exit 0
}

# 下载源：GitHub 官方优先，失败则回退到国内镜像
$official = "https://github.com/Genymobile/scrcpy/releases/download/$version/$zipName"
$urls = @(
    $official,
    "https://ghfast.top/$official",
    "https://gh-proxy.com/$official",
    "https://ghproxy.net/$official"
)

$tmp = Join-Path $env:TEMP $zipName
$ok  = $false

foreach ($u in $urls) {
    $host_ = ([uri]$u).Host
    Say "  正在尝试下载（$host_）..." 'Yellow'
    try {
        if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
            & curl.exe -L --no-progress-meter --retry 2 --max-time 300 -o $tmp $u
            if ($LASTEXITCODE -eq 0 -and (Test-Path $tmp) -and (Get-Item $tmp).Length -gt 1MB) { $ok = $true }
        }
        else {
            Invoke-WebRequest -Uri $u -OutFile $tmp -UseBasicParsing
            if ((Test-Path $tmp) -and (Get-Item $tmp).Length -gt 1MB) { $ok = $true }
        }
    }
    catch { $ok = $false }

    if ($ok) {
        Say ("  下载成功：{0:N1} MB" -f ((Get-Item $tmp).Length / 1MB)) 'Green'
        break
    }
    Say "  该源不可用，换下一个..." 'DarkGray'
}

if (-not $ok) {
    Say ""
    Say "  [X] 自动下载失败（网络受限）。" 'Red'
    Say "      请手动下载 scrcpy，解压后把整个文件夹放到：" 'Yellow'
    Say "        $target" 'Gray'
    Say "      下载地址：https://github.com/Genymobile/scrcpy/releases" 'Gray'
    Say ""
    Read-Host "  按回车退出"
    exit 1
}

# 解压并部署
Say "  正在解压..." 'Yellow'
$ex = Join-Path $env:TEMP 'scrcpy-extract'
if (Test-Path $ex) { Remove-Item $ex -Recurse -Force }
Expand-Archive -Path $tmp -DestinationPath $ex -Force

$inner = (Get-ChildItem $ex -Directory | Select-Object -First 1).FullName
if (-not $inner) { $inner = $ex }

if (-not (Test-Path $target)) { New-Item -ItemType Directory -Path $target -Force | Out-Null }
Copy-Item (Join-Path $inner '*') $target -Recurse -Force

Say ""
if (Test-Path (Join-Path $target 'scrcpy.exe')) {
    Say "  [OK] 部署完成！scrcpy 已安装到：" 'Green'
    Say "       $target" 'Gray'
    Say ""
    Say "       下一步：双击『手机音频到电脑.bat』开始使用。" 'Cyan'
    Say "       首次使用需要配对手机，步骤见 README.md。" 'Gray'
}
else {
    Say "  [X] 解压后没找到 scrcpy.exe，请手动部署。" 'Red'
}

# 清理临时文件
Remove-Item $tmp -Force -ErrorAction SilentlyContinue
Remove-Item $ex  -Recurse -Force -ErrorAction SilentlyContinue

Say ""
Read-Host "  按回车退出"
