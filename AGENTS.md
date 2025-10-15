# AGENTS.md テンプレート

このドキュメントは、`datastream` プロジェクトにおける自動化エージェント（スクリプトやマネージドサービス、ワークフロー）を横断的に把握するためのテンプレートです。チームで運用を引き継ぐ際や、変更時の影響範囲を判断する際の基礎資料として利用します。

## 1. ドキュメントメタ情報
- **最終更新日**: <!-- YYYY-MM-DD -->
- **作成者**: <!-- 例: Data Platform Team -->
- **関連ドキュメント**: <!-- 例: README.md, architecture.drawio など -->
- **更新履歴**:
  | 版 | 日付 | 変更者 | 概要 |
  | --- | --- | --- | --- |
  | 0.1 | <!-- YYYY-MM-DD --> | <!-- Name --> | 初版作成 |

## 2. 全体概要
- **目的**: <!-- プロジェクト内でエージェントが果たす役割の概要 -->
- **ハイレベルフロー**:
  ```
  (データ発生源) --> (エージェントA) --> (中間リソース) --> (エージェントB) --> (分析/保存先)
  ```
- **関連リソースの位置づけ**:
  | リソース | 役割 | 担当者/連絡先 | 備考 |
  | --- | --- | --- | --- |
  | `sensor.py` | デバイスからのテレメトリ生成 | <!-- Owner --> | Python スクリプト |
  | `resources/kinesis-firehose/` | ストリーミング転送設定 | <!-- Owner --> | IAM ポリシー等 |
  | `resources/glue-job/temperature_etl.py` | ETL 処理 | <!-- Owner --> | AWS Glue ETL |
  | `resources/glue-crawler/` | データカタログ更新 | <!-- Owner --> | Glue Crawler |

## 3. エージェント一覧（要約）
| エージェントID | ロール / 目的 | 実装 / サービス | 主な入出力 | 実行トリガ | 管理者 |
| --- | --- | --- | --- | --- | --- |
| `agent-producer` | テレメトリを生成し Kinesis に送信 | `sensor.py` (Python) | 出力: `temperature-stream` | `while True` ループ | <!-- Owner --> |
| `agent-firehose` | ストリームをバケットへ配信 | Amazon Kinesis Data Firehose | 入力: `temperature-stream`<br>出力: S3 バケット | マネージド (常時) | <!-- Owner --> |
| `agent-glue-etl` | S3 の生データを加工してクレンジング | AWS Glue Job (`temperature_etl.py`) | 入力: S3 生データ<br>出力: curated テーブル | スケジュール / イベント | <!-- Owner --> |
| `agent-glue-crawler` | カタログ更新とスキーマ同期 | AWS Glue Crawler | 入力: curated バケット | スケジュール / 手動 | <!-- Owner --> |

> 新規エージェントを追加した場合は、上記表に行を追加して全体像を更新します。

## 4. エージェント詳細セクション
以下テンプレートをコピーし、エージェントごとの詳細を記載してください。

---

### エージェント名（例: Agent Producer）
- **エージェントID**: `agent-producer`
- **役割サマリ**: <!-- 例: IoT デバイスからのテレメトリを模擬し、1 秒間隔で Kinesis ストリームへ送信する -->
- **ライフサイクル種別**: <!-- 常駐 / バッチ / オンデマンド -->
- **実装**:
  - コード / アーティファクト: <!-- 例: sensor.py -->
  - 実行環境: <!-- 例: EC2, Lambda, ローカル端末 -->
  - 依存ライブラリ / ランタイム: <!-- 例: Python 3.11, boto3 -->
- **主な入力**:
  - ソース: <!-- 例: 疑似デバイス -->
  - 入力形式: <!-- 例: dict -->
- **主な出力**:
  - 宛先: <!-- 例: temperature-stream (Kinesis Data Stream) -->
  - データ形式: <!-- 例: JSON -->
- **スケジュール / トリガ**:
  - 起動条件: <!-- 例: 手動起動 / cron / EventBridge -->
  - 実行頻度: <!-- 例: 常駐 -->
- **権限 / IAM 設定**:
  - ポリシー: <!-- resources/.../policy.json 参照など -->
  - ロール: <!-- 例: sensor-writer-role -->
- **状態監視 / アラート**:
  - メトリクス: <!-- 例: Kinesis PutRecord 失敗率 -->
  - アラート先: <!-- 例: Slack #alerts -->
- **異常時対応**:
  1. <!-- 例: ログの確認方法 -->
  2. <!-- 例: 再起動手順 -->
  3. <!-- 例: エスカレーション先 -->
- **既知の制約 / TODO**:
  - <!-- 例: スループット制限、改善予定 -->
- **参考リンク / Runbook**:
  - <!-- 例: dashboards/producer.json -->

---

（上記テンプレートをエージェントの数だけ繰り返してください）

## 5. ワークフロー & ハンドオフ
- **データフロー図**: <!-- mermaid や画像パス -->
- **ハンドオフ順序**:
  1. <!-- 例: agent-producer が Kinesis に書き込む -->
  2. <!-- 例: agent-firehose が S3 に着地させる -->
  3. <!-- 例: agent-glue-etl がクレンジングする -->
  4. <!-- 例: agent-glue-crawler がデータカタログを更新する -->
- **依存関係メモ**:
  - <!-- 例: Glue Job は Firehose 出力バケットが存在することを前提 -->

## 6. 開発・デプロイ手順テンプレート
- **ローカルテスト**:
  ```bash
  uv run python sensor.py  # or poetry run python sensor.py
  ```
- **インフラ適用方法**:
  1. <!-- 例: Terraform / CDK / CloudFormation 手順 -->
  2. <!-- 例: IAM ロールの作成 -->
- **デプロイチェックリスト**:
  - [ ] コードレビュー完了
  - [ ] ポリシー差分確認
  - [ ] スケジュール / EventBridge 設定確認
  - [ ] アラート設定確認

## 7. セキュリティ & コンプライアンス
- **機密データの扱い**:
  - <!-- 例: PII なし / 暗号化ストレージ -->
- **アクセス制御**:
  - <!-- 例: IAM ロール、最小権限 -->
- **監査ログ**:
  - <!-- 例: CloudTrail, Firehose Delivery Logs -->

## 8. 将来の改善アイデア（任意）
- <!-- 例: イベントドリブン化、Lake Formation 統合 -->

---

作業が完了したら、更新者は関連する Pull Request またはチケットへのリンクを記載し、関係者に共有してください。
