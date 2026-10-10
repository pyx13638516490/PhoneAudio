# ============================================================
#  手机音频 -> 电脑音箱   一键启动
#  原理: 无线调试(adb) + scrcpy --no-video 转发系统音频
#  用法: 双击 手机音频到电脑.bat（或直接运行本脚本）
#  停止: 在本窗口按 Ctrl+C
# ============================================================

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
try { Clear-Host } catch {}

# ---- 自动定位 scrcpy：脚本同级目录优先，其次常见安装位置 ----
$cands = @(
    (Join-Path $PSScriptRoot 'scrcpy'),
    (Join-Path (Get-Location) 'scrcpy'),
    (Join-Path $env:LOCALAPPDATA 'Programs\scrcpy'),
    (Join-Path $env:USERPROFILE 'scrcpy')
)
$S = $null
foreach ($c in $cands) {
    if ($c -and (Test-Path (Join-Path $c 'scrcpy.exe'))) { $S = $c; break }
}

$adb    = if ($S) { Join-Path $S 'adb.exe' }    else { $null }
$scrcpy = if ($S) { Join-Path $S 'scrcpy.exe' } else { $null }

# ============================================================
#  调优记录（实测数据，勿删，排障时有用）
#   症状: 无线转发音频卡顿
#   诊断: 手机侧 Wi-Fi 重传率 32.7%，ping 抖动尖峰 129ms（电脑侧无异常）
#   处理: 1) 音频缓冲 50 -> 400ms
#         2) 小米 AX1800 后台把 5G「频段带宽」80MHz -> 40MHz
#            协商速率 1201 -> 573Mbps，调制阶数下降
#            重传率 32.7% -> 17.9%，卡顿消失
#   备注: 本机 AX1800 的 5G 信道锁定为 149，「频段带宽」也仅在信道 149 下开放修改
#         所以 149 + 40MHz 是唯一可行组合，实测效果也是最优（17.9%）
#         注意: 早期把 47%~62% 的重传归因于「信道 149 差」是误判
#               那几次频宽其实仍是 80MHz —— 真正的变量自始至终是频宽
# ============================================================
#  音频缓冲（毫秒）：越大越抗卡顿，越小延迟越低
#   还是卡          -> 调到 500 ~ 800
#   看视频要音画同步 -> 降到 80 ~ 100
#   改用 USB 数据线 -> 可降到 50（scrcpy 默认值，延迟最低）
$AudioBufferMs = 400

function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }

# 通过 mDNS 自动发现手机，不用手抄 IP
function Find-Addr([string]$kind) {
    for ($i = 1; $i -le 6; $i++) {
        foreach ($l in (& $adb mdns services 2>&1)) {
            $s = ("$l").Trim()
            if ($s -match "_adb-tls-$kind") {
                $a = ($s -split '\s+')[-1]
                if ($a -match '^\d{1,3}(\.\d{1,3}){3}:\d+$') { return $a }
            }
        }
        Start-Sleep -Seconds 2
    }
    return $null
}

function Is-Online {
    foreach ($l in (& $adb devices 2>&1)) {
        if (("$l").Trim() -match '\sdevice$') { return $true }
    }
    return $false
}

Say ""
Say "  ==========================================" 'Cyan'
Say "        手机音频  ->  电脑音箱" 'Cyan'
Say "  ==========================================" 'Cyan'
Say ""

if (-not $scrcpy) {
    Say "  [X] 找不到 scrcpy，已尝试以下位置:" 'Red'
    $cands | ForEach-Object { Say "      $_" 'DarkGray' }
    Read-Host "  按回车退出"
    exit 1
}

# 已经有实例在跑就先问一句
$run = @(Get-Process scrcpy -ErrorAction SilentlyContinue)
if ($run.Count -gt 0) {
    Say "  [!] scrcpy 已在运行 (PID: $($run.Id -join ', '))" 'Yellow'
    if ((Read-Host "      结束它并重新启动? (y/N)") -notmatch '^[Yy]') { exit 0 }
    $run | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 800
}

& $adb start-server 2>&1 | Out-Null

if (-not (Is-Online)) {
    Say "  [1/3] 未连接，正在局域网搜索手机..." 'Yellow'
    $addr = Find-Addr 'connect'
    if ($addr) {
        Say "        发现: $addr" 'Green'
        Say "  [2/3] 连接中..." 'Yellow'
        (& $adb connect $addr 2>&1) | ForEach-Object { Say "        $_" }
        Start-Sleep -Seconds 2
    }
    else {
        Say "        没搜到手机" 'Yellow'
    }
}

# 没配对过 / 端口变了 -> 走一次性配对
if (-not (Is-Online)) {
    Say ""
    Say "  需要先配对（只需做一次）" 'Yellow'
    Say "    1. 手机: 设置 -> 更多设置 -> 开发者选项 -> 无线调试 (打开)" 'Gray'
    Say "    2. 点『使用配对码配对设备』，弹窗不要关" 'Gray'
    Say ""
    $code = Read-Host "  请输入 6 位配对码 (直接回车放弃)"
    if ($code -match '^\d{6}$') {
        $pa = Find-Addr 'pairing'
        if ($pa) {
            Say "        配对服务: $pa" 'Green'
            (& $adb pair $pa $code 2>&1) | ForEach-Object { Say "        $_" }
            Start-Sleep -Seconds 1
            $ca = Find-Addr 'connect'
            if ($ca) {
                (& $adb connect $ca 2>&1) | ForEach-Object { Say "        $_" }
                Start-Sleep -Seconds 2
            }
        }
        else {
            Say "        没发现配对服务（配对弹窗是不是关了？）" 'Red'
        }
    }
}

if (-not (Is-Online)) {
    Say ""
    Say "  连接失败，请检查:" 'Red'
    Say "    - 手机和电脑连在同一个 WiFi" 'Gray'
    Say "    - 手机上『无线调试』已打开" 'Gray'
    Say "    - 手机重启后需要重新打开『无线调试』" 'Gray'
    Read-Host "  按回车退出"
    exit 1
}

Say ""
Say "  [3/3] 已连接，开始把手机声音送到电脑..." 'Green'
Say "        保持本窗口开着 | 按 Ctrl+C 停止" 'DarkGray'
Say ""

& $scrcpy --no-video --audio-buffer=$AudioBufferMs

Say ""
Say "  已断开。" 'Yellow'
Read-Host "  按回车关闭"
