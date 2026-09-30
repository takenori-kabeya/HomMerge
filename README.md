# HomMerge

**HomMerge** is a file comparison and merging tool designed exclusively for Mac.
The name is a portmanteau of **"Homage"** and **"Merge,"** chosen to express deep respect for the great tool known as "WinMerge."

![Folder comparison](https://github.com/takenori-kabeya/HomMerge/blob/main/assets/folder-compare.png)

![File comparison](https://github.com/takenori-kabeya/HomMerge/blob/main/assets/file-compare.png)

## Features

- Compare, merge, and edit two files
- Compare, copy, and delete folder trees
- Cross-file comparison in the folder comparison window (compare two files with different names)
- Select two items in Finder and start comparison via the Services menu
- Support for UTF-8 and Shift_JIS
- Support for CR, CRLF, and LF line endings

## Requirements

- macOS 14 or later
- Xcode 26.6 or later (for development)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (generates `.xcodeproj` from `project.yml`)
- [Pandoc](https://pandoc.org/) (generates `EULA.rtf`; install via `brew install pandoc`)

## Structure

```text
HomMerge/
  App/                    # Launch, windows, tabs, sessions
  FileCompare/            # File comparison UI / panes
  FolderCompare/          # Folder comparison UI
  Assets.xcassets/
HomMergeTests/            # Unit tests for the app (@testable import HomMerge)
HomMergeUITests/          # XCUITest (app launch UI tests)
Packages/DiffEngine/
  Sources/DiffEngine/
    Core/                 # Myers / TextDiffer / Models
    FileCompare/          # File state, merging, layout
    FolderCompare/        # Folder traversal, PathKind
  Tests/DiffEngineTests/
project.yml               # XcodeGen definition
```

## Setup

```bash
# Generate .xcodeproj (initial setup or after modifying project.yml)
xcodegen generate

# Build the app (requires pandoc to generate EULA.rtf for the About screen)
xcodebuild -scheme HomMerge -configuration Debug build

# Test DiffEngine (package-only)
swift test --package-path Packages/DiffEngine

# Test via the HomMerge scheme
xcodebuild -scheme HomMerge -destination 'platform=macOS' test
```

To open in Xcode:

```bash
xcodegen generate
open HomMerge.xcodeproj
```

### Code Signing (Development Team)

The Apple Developer **Team ID is not included** in the public repository. Please configure the following in Xcode upon your first setup:

1. Open the `HomMerge`, `HomMergeTests`, and `HomMergeUITests` targets.
2. Select your **Team** under **Signing & Capabilities**.
3. (Optional) Set `DEVELOPMENT_TEAM` in `project.yml` locally and run `xcodegen generate`. Do not commit this change.

## Branches and Releases

We use GitHub Flow.

- The default branch is `main` (kept in a buildable state at all times).
- Changes are submitted via Pull Requests from short-lived branches.
- Releases are managed using version tags (e.g., `0.1.6-53`) and GitHub Releases.

Please refer to [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.

## License

- Source code: [MIT](LICENSE)
- App usage: [EULA (End-User License Agreement)](docs/EULA.md)

## Disclaimer

While we respect the usability and philosophy of WinMerge, this project was developed completely independently and does not reuse any of its source code.
This project is unaffiliated with the official WinMerge project.

---

**HomMerge** は、Mac専用のファイル比較・マージツールです。
アプリ名は **「Homage（オマージュ）」** と **「Merge（マージ）」** を掛け合わせたダブルミーニングであり、偉大なツールである「WinMerge」への深いリスペクトを込めて名付けられました。

## できること

- 2ファイルの比較、マージ、編集
- フォルダツリーの比較、コピー、削除
- フォルダ比較ウィンドウでのクロスファイル比較（異なるファイル名の2ファイルを比較）
- Finder で2項目を選び、サービスメニューから比較を開始
- UTF-8/Shift_JISのサポート
- CR/CRLF/LFの改行コードサポート

## 必要環境

- macOS 14 以降
- Xcode 26.6 以降（開発時）
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)（`project.yml` から `.xcodeproj` を生成）
- [Pandoc](https://pandoc.org/)（EULA.rtf 生成。`brew install pandoc`）

## 構成

```text
HomMerge/
  App/                    # 起動・ウィンドウ・タブ・セッション
  FileCompare/            # ファイル比較 UI / ペイン
  FolderCompare/          # フォルダ比較 UI
  Assets.xcassets/
HomMergeTests/            # アプリ本体ユニットテスト（@testable import HomMerge）
HomMergeUITests/          # XCUITest（アプリ起動 UI テスト）
Packages/DiffEngine/
  Sources/DiffEngine/
    Core/                 # Myers / TextDiffer / モデル
    FileCompare/          # ファイル状態・マージ・レイアウト
    FolderCompare/        # フォルダ走査・PathKind
  Tests/DiffEngineTests/
project.yml               # XcodeGen 定義
```

## セットアップ

```bash
# .xcodeproj を生成（初回・project.yml 変更時）
xcodegen generate

# アプリをビルド（About 画面用 EULA.rtf 生成に pandoc が必要）
xcodebuild -scheme HomMerge -configuration Debug build

# DiffEngine のテスト（パッケージ単体）
swift test --package-path Packages/DiffEngine

# HomMerge スキーム経由のテスト
xcodebuild -scheme HomMerge -destination 'platform=macOS' test
```

Xcode で開く場合:

```bash
xcodegen generate
open HomMerge.xcodeproj
```

### コード署名（Development Team）

公開リポジトリには Apple Developer の **Team ID を含めていません**。初回は Xcode で次を設定してください。

1. `HomMerge` / `HomMergeTests` / `HomMergeUITests` ターゲットを開く
2. **Signing & Capabilities** で自分の **Team** を選ぶ
3. （任意）ローカルだけで `project.yml` の `DEVELOPMENT_TEAM` を設定し、`xcodegen generate` する。その変更はコミットしない

## ブランチとリリース

GitHub Flow を使います。

- デフォルトブランチは `main`（常にビルド可能な状態を保つ）
- 変更は短命ブランチから Pull Request
- リリースはバージョンタグ（例: `0.1.6-53`）と GitHub Releases

貢献の手順は [CONTRIBUTING.md](CONTRIBUTING.md) を参照してください。

## ライセンス

- ソースコード: [MIT](LICENSE)
- アプリの利用: [EULA（エンドユーザーライセンス契約）](docs/EULA.md)

## 免責

WinMergeの使い勝手や思想をリスペクトしていますが、ソースコードの流用はなく、完全に独立して開発されています。
本プロジェクトは WinMerge 公式とは無関係です。
