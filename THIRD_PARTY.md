# Third-party components

本資料夾提供 Windows 安裝協調腳本、自製的 `canvas-video` runtime、`canvas-video-pipeline` Skill 與 `video-delivery-qc` Skill；不重新散布第三方二進位檔或第三方 Skill 原始碼。

| 元件 | 來源 | 安裝方式 | 授權／條款 |
|---|---|---|---|
| Node.js 22 | `nodejs.org` | 官方 ZIP＋SHA-256 驗證 | Node.js 專案授權條款 |
| FFmpeg | Windows Package Manager／Gyan | WinGet `Gyan.FFmpeg` | 依安裝版本與建置選項而定 |
| Python 3.12 | Python Software Foundation／WinGet | WinGet `Python.Python.3.12` | PSF License |
| HyperFrames | npm／`heygen-com/hyperframes` | npm global prefix、官方 Skill 指令 | Apache-2.0（以官方倉庫為準） |
| 即夢畫布 CLI／Skill | `jimeng.jianying.com` | 即夢官方 PowerShell 安裝器 | 即夢官方條款 |
| Playwright 1.56 | npm／Microsoft | `npm ci` 安裝至獨立 Canvas runtime | Apache-2.0（以套件內授權為準） |
| Three.js 0.170 | npm／mrdoob/three.js | `npm ci` 安裝至獨立 Canvas runtime | MIT（以套件內授權為準） |

商標與服務名稱分屬其權利人。本專案不表示獲得上述專案或服務背書。
