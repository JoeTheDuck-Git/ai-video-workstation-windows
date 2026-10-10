# Third-party components

本資料夾提供 Windows 安裝協調腳本、`canvas-video` runtime 與五個內建 Skills。
Node、FFmpeg、HyperFrames、Playwright 與 Python 相依項在安裝時從各自官方來源取得。

`footage-sifter`、`caption-doctor`、`subtitle-translator` 與 Tacky Templates 的來源資料夾
未發現頂層授權檔。依使用者要求納入本地安裝包；對外公開發布或再散布前，
倉庫擁有者必須先確認相應權利。Canvas B-roll helper 為本倉庫重新實作的確定性程式。

| 元件 | 來源 | 安裝方式 | 授權／條款 |
|---|---|---|---|
| Node.js 22 | `nodejs.org` | 官方 ZIP＋SHA-256 驗證 | Node.js 專案授權條款 |
| FFmpeg | Windows Package Manager／Gyan | WinGet `Gyan.FFmpeg` | 依安裝版本與建置選項而定 |
| Python 3.12 | Python Software Foundation／WinGet | WinGet `Python.Python.3.12` | PSF License |
| HyperFrames | npm／`heygen-com/hyperframes` | npm global prefix、官方 Skill 指令 | Apache-2.0（以官方倉庫為準） |
| Playwright 1.56 | npm／Microsoft | `npm ci` 安裝至獨立 Canvas runtime | Apache-2.0（以套件內授權為準） |
| Three.js 0.170 | npm／mrdoob/three.js | `npm ci` 安裝至獨立 Canvas runtime | MIT（以套件內授權為準） |
| Playwright Core 1.62 | npm／Microsoft | `npm ci` 安裝至獨立 Tacky Templates renderer | Apache-2.0（以套件內授權為準） |
| OpenCC Python | PyPI | 安裝至獨立 AI Video Workstation Python 環境 | Apache-2.0（以套件內授權為準） |
| jieba | PyPI | 安裝至獨立 AI Video Workstation Python 環境 | MIT（以套件內授權為準） |
| 素材／字幕 Skills | 使用者指定的本機來源 | 隨安裝包複製 | 來源未附頂層授權檔；公開散布前須確認權利 |
| Tacky Templates HTML assets | 使用者指定的本機模板來源 | 隨 `canvas-video-pipeline` Skill 安裝 | 來源未附頂層授權檔；公開散布前須確認權利 |

商標與服務名稱分屬其權利人。本專案不表示獲得上述專案或服務背書。
