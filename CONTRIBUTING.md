# Contributing to HomMerge

Thank you for your contribution. This document outlines the development process for this public repository.

## Branching Strategy (GitHub Flow)

- Perform work on short-lived branches created from `main`.
- Branch name examples: `feat/finder-compare`, `fix/settings-close`, `docs/readme`.
- Merge changes into `main` via a Pull Request (PR).
- You may delete the working branch after merging.
- The same applies to hotfixes (`main` → short `fix/...` branch → PR → tag if necessary).

Long-lived branches such as `develop` or `release/*` are not used.

## Preparation

1. Fork or clone the repository.
2. Install required tools (refer to the environment requirements in [README.md](README.md)).
3. Generate the Xcode project using `xcodegen generate`.
4. Configure **your own Development Team** in Xcode (the repository does not include a Team ID).

## Development Workflow

1. Fetch the latest `main`.
2. Create a working branch.
3. Make changes (following the coding guidelines below).
4. Run tests.
5. Submit a PR (briefly describe the purpose and verification method).

### Testing

Run at least the relevant tests based on the changes made.

```bash
# DiffEngine
swift test --package-path Packages/DiffEngine

# App unit tests
xcodebuild -scheme HomMerge -destination 'platform=macOS' -only-testing:HomMergeTests test

# Full test suite (may take time)
xcodebuild -scheme HomMerge -destination 'platform=macOS' test
```

### Commit Messages

Please write them in English using the following format: 

```
Prefix: Main message
- Supplementary point 1
- Supplementary point 2
```

Prefixes:

| Prefix | Usage |
|--------|-------|
| `feat:` | New feature |
| `fix:` | Bug fix |
| `spec:` | Specification change to an existing feature (not a bug fix) |
| `docs:` | Documentation only |
| `style:` | Formatting changes that do not affect logic |
| `refactor:` | Code restructuring (excluding new features or bug fixes) |
| `perf:` | Performance improvement |
| `test:` | Adding or modifying tests |
| `chore:` | Build, tooling, or miscellaneous tasks |

- Keep the main message (including the prefix) to approximately 50 characters or less.
- Do not end the message with a period.

### Coding Guidelines (Key Points)

- **Write tests first for new features** (or include tests in the PR).
- Do not implement special-case code just to make specific tests pass; implement according to the specifications.
- If a test fails, do not simply loosen the test to match the implementation; explain your interpretation of the specifications in the PR.
- Do not include personal `DEVELOPMENT_TEAM` settings, certificates, API keys, or personal passwords in changes intended for public release.

## Pull Requests

Please include the following in your PR:

- **Purpose of the change** (summary)
- **Verification method** (tests run or manual steps)
- **Breaking changes or follow-up tasks** (if applicable)

Maintainers will merge the PR after confirming that CI (or equivalent local tests) passes.

## License

Contributed code is provided under the repository's [MIT License](LICENSE). Please refer to the [EULA](docs/EULA.md) for application terms of use.

## Questions & Discussions

For major specification changes, please share your proposed approach in an Issue first, if possible. Feel free to submit a PR directly for minor fixes, documentation updates, or additional tests.

---

# HomMerge への貢献

貢献ありがとうございます。この文書は、公開リポジトリでの開発の進め方をまとめたものです。

## ブランチ戦略（GitHub Flow）

- 作業は `main` から短命ブランチを切って行う
- ブランチ名の例: `feat/finder-compare`、`fix/settings-close`、`docs/readme`
- 変更は Pull Request（PR）で `main` にマージする
- マージ後は作業ブランチを削除してよい
- ホットフィックスも同様（`main` → 短い `fix/...` ブランチ → PR → 必要ならタグ）

`develop` / `release/*` などの長期ブランチは使いません。

## 事前準備

1. リポジトリを fork するか clone する
2. 依存ツールを入れる（[README.md](README.md) の必要環境を参照）
3. `xcodegen generate` で Xcode プロジェクトを生成する
4. Xcode で **自分の Development Team** を設定する（リポジトリに Team ID は含まれていない）

## 開発の流れ

1. 最新の `main` を取得する
2. 作業ブランチを作る
3. 変更を加える（下記のコーディング方針に従う）
4. テストを通す
5. PR を出す（目的と確認方法を短く書く）

### テスト

変更内容に応じて、少なくとも関係するテストを実行してください。

```bash
# DiffEngine
swift test --package-path Packages/DiffEngine

# アプリ本体ユニットテスト
xcodebuild -scheme HomMerge -destination 'platform=macOS' -only-testing:HomMergeTests test

# フル（時間がかかる場合あり）
xcodebuild -scheme HomMerge -destination 'platform=macOS' test
```

### コミットメッセージ

英語で、次の形式を推奨します。

```
プレフィクス: 主メッセージ
- 補足1
- 補足2
```

プレフィクス:

| プレフィクス | 用途 |
|--------------|------|
| `feat:` | 新規機能 |
| `fix:` | 不具合修正 |
| `spec:` | 不具合ではない既存機能の仕様変更 |
| `docs:` | ドキュメントのみ |
| `style:` | 意味に影響しない整形 |
| `refactor:` | 機能追加・不具合修正以外の整理 |
| `perf:` | 性能改善 |
| `test:` | テスト追加・修正 |
| `chore:` | ビルド・ツール・雑務 |

- 主メッセージはプレフィクス込みでおおよそ 50 文字以内
- 文末に句点は付けない

### コーディング方針（要点）

- **新機能はテストを先に書く**（または PR にテストを含める）
- 特定のテストだけ通すための特例実装はしない。仕様に沿った実装にする
- テストが落ちる場合、安易にテスト側を「実装に合わせて」緩めない。仕様の解釈を PR で説明する
- 公開用の変更に、自分専用の `DEVELOPMENT_TEAM`・証明書・API キー・個人パスを含めない

## Pull Request

PR には次を書いてください。

- **何のための変更か**（要約）
- **確認方法**（実行したテストや手動手順）
- 破壊的変更やフォローアップがあればその旨

メンテナは CI（またはローカル同等のテスト）が通ることを確認してからマージします。

## ライセンス

貢献するコードは、リポジトリの [MIT ライセンス](LICENSE) の下で提供されるものとします。アプリ利用条件は [EULA](docs/EULA.md) を参照してください。

## 質問・議論

大きな仕様変更は、可能なら Issue で先に方針を共有してください。小さな修正・ドキュメント・テスト追加はそのまま PR で構いません。
