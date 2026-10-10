# AI Video Workstation — Windows 一鍵安裝版

這是獨立的 Windows 原生安裝套件，不需要 WSL。它會安裝或設定：

- 官方 Node.js 22 ZIP，並依 `SHASUMS256.txt` 驗證 SHA-256
- FFmpeg／FFprobe
- Python 3.12（供影片 QC 使用）
- HyperFrames CLI 與核心 Skills
- 隔離的 `canvas-video` Canvas／Three.js renderer
- `canvas-video-pipeline` 與 `video-delivery-qc` Skills
- 預設內建 `footage-sifter`、`caption-doctor` 與 `subtitle-translator`
- Canvas Skill 同時提供 B-roll 效果 API，
  並隨附重新命名為 **Tacky Templates** 的 10 種風格、31 個 HTML 模板與
  31 效果展示頁

生成影片、快照、登入資料、Cookie、API Key 與 Python 虛擬環境都不會放入此資料夾。
基本安裝不會安裝、登入或驗證任何生成式媒體供應商；可使用本機素材、授權素材庫，或使用者自行選擇並另外安裝的生成工具。

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

若只使用其中一個 AI 工具：

```powershell
.\install.ps1 -CodexOnly
.\install.ps1 -ClaudeOnly
```

安裝器預設把五個內建 Skill 同時複製到 `%USERPROFILE%\.codex\skills\` 與
`%USERPROFILE%\.claude\skills\`，
並在 `%LOCALAPPDATA%\AI-Video-Workstation\python-venv\` 建立隔離 Python 環境，
安裝 OpenCC 與 jieba，不會修改系統 Python 套件。

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

## 選配雲端授權

只有需要 HyperFrames／HeyGen 雲端功能時，才需要雙擊 `login.cmd`，或執行：

```powershell
.\scripts\login.ps1
```

登入憑證留在各 CLI 的使用者設定目錄，不會複製進本專案。

## 驗證

雙擊 `verify.cmd`，或執行：

```powershell
.\scripts\verify.ps1
.\scripts\smoke-test.ps1
```

安裝流程本身會執行完整本機工具鏈檢查和 0.2 秒原生 1080×1920 H.264 冒煙測試，不檢查任何生成式媒體供應商的安裝或登入狀態。

## Canvas Video 使用方式

開啟新的 PowerShell：

```powershell
canvas-video doctor
canvas-video init .\motion-landscape --aspect landscape
canvas-video init .\motion-portrait --aspect portrait
canvas-video render .\motion-portrait --still 2.5
canvas-video render .\motion-portrait
```

`canvas-video-pipeline\assets\broll-effects.js` 提供 documentary marker、minimal bars、
comic burst、VHS、terminal、editorial、neon、glass、split-flap、kinetic type、shape morph、
particle reveal、infinite zoom、parallax、timeline path、exploded view、預先計算音訊包絡、
Bento 與 match cut 等可重現的 Canvas helper。

完整 Tacky 動態版型會安裝到已選擇 AI 工具的 Skill 目錄，例如：

```text
%USERPROFILE%\.codex\skills\canvas-video-pipeline\assets\tacky-templates\
%USERPROFILE%\.claude\skills\canvas-video-pipeline\assets\tacky-templates\
```

其 renderer 使用獨立 `node_modules`。可用以下命令列出或複製素材：

```powershell
canvas-video tacky list
canvas-video tacky copy-template vox .\title-card.html
canvas-video tacky render-template .\title-card.html .\title-card.mp4 --dur=8 --ffmpeg=ffmpeg
```

`assets\tacky-scenes\` 只保留 31 項通用動效展示，用於挑選並重建當前故事需要的
動效；不把展示頁當成完成場景直接交付。

橫式模板是原生 1920×1080，直式模板是原生 1080×1920。Canvas 與 HyperFrames 不共用 `node_modules`；Canvas 輸出作為媒體交給 HyperFrames，最終成片再以 QC 實測為準。

## 安全與限制

- 安裝器只會移除並更新 `%LOCALAPPDATA%\AI-Video-Workstation` 下由它管理的 Node 與 Canvas runtime。
- FFmpeg 與 Python 經 WinGet 安裝，可能觸發 Windows 的標準權限提示。
- 本版本已做原始碼、Node runtime 與 Skill 驗證，但仍應在實際 Windows x64／ARM64 主機各完成一次端到端驗收後再大規模散布。
