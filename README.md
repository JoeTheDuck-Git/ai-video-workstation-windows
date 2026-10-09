# AI Video Workstation — Windows 一鍵安裝版

這是獨立的 Windows 原生安裝套件，不需要 WSL。它會安裝或設定：

- 官方 Node.js 22 ZIP，並依 `SHASUMS256.txt` 驗證 SHA-256
- FFmpeg／FFprobe
- Python 3.12（供影片 QC 使用）
- HyperFrames CLI 與核心 Skills
- 即夢畫布 `dreamina-canvas` CLI／Skill
- 隔離的 `canvas-video` Canvas／Three.js renderer
- `canvas-video-pipeline` 與 `video-delivery-qc` Skills

生成影片、快照、登入資料、Cookie、API Key 與 Python 虛擬環境都不會放入此資料夾。

## 系統需求

- Windows 10 1809 以上或 Windows 11
- 64 位元 x64 或 ARM64
- Windows PowerShell 5.1 以上
- Microsoft WinGet；若未安裝，請先從 Microsoft Store 安裝「App Installer」
- 建議至少保留 10 GB 磁碟空間

## 一鍵安裝

解壓縮或 clone 此資料夾後，雙擊：

```text
install.cmd
```

也可以在 PowerShell 中執行：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\install.ps1
```

若要安裝完整 HyperFrames Skill 集合：

```powershell
.\install.ps1 -AllHyperFramesSkills
```

如果暫時不安裝即夢：

```powershell
.\install.ps1 -SkipDreamina
```

安裝器會把受管理的 runtime 放在：

```text
%LOCALAPPDATA%\AI-Video-Workstation\
```

並只把以下受管理路徑加入使用者 PATH：

```text
%LOCALAPPDATA%\AI-Video-Workstation\node22-current
%LOCALAPPDATA%\AI-Video-Workstation\bin
%LOCALAPPDATA%\AI-Video-Workstation\npm
```

## 登入授權

安裝完成後雙擊 `login.cmd`，或執行：

```powershell
.\scripts\login.ps1
```

若也要登入 HyperFrames／HeyGen：

```powershell
.\scripts\login.ps1 -WithHyperFrames
```

登入憑證留在各 CLI 的使用者設定目錄，不會複製進本專案。

## 驗證

雙擊 `verify.cmd`，或執行：

```powershell
.\scripts\verify.ps1
.\scripts\smoke-test.ps1
```

安裝流程本身會執行完整環境檢查和 0.2 秒原生 1080×1920 H.264 冒煙測試。登入即夢前，授權狀態只會顯示警告。

## Canvas Video 使用方式

開啟新的 PowerShell：

```powershell
canvas-video doctor
canvas-video init .\motion-landscape --aspect landscape
canvas-video init .\motion-portrait --aspect portrait
canvas-video render .\motion-portrait --still 2.5
canvas-video render .\motion-portrait
```

橫式模板是原生 1920×1080，直式模板是原生 1080×1920。Canvas 與 HyperFrames 不共用 `node_modules`；Canvas 輸出作為媒體交給 HyperFrames，最終成片再以 QC 實測為準。

## 安全與限制

- 安裝器只會移除並更新 `%LOCALAPPDATA%\AI-Video-Workstation` 下由它管理的 Node 與 Canvas runtime。
- FFmpeg 與 Python 經 WinGet 安裝，可能觸發 Windows 的標準權限提示。
- 即夢安裝器每次從官方 HTTPS 網址下載；本專案無法替官方腳本維護固定 checksum，執行前可先檢閱 `install.ps1`。
- 本版本已做原始碼、Node runtime 與 Skill 驗證，但仍應在實際 Windows x64／ARM64 主機各完成一次端到端驗收後再大規模散布。
