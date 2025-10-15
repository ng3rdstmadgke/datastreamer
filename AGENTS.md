# Terraform ディレクトリ構成案

```
terraform/
├── backend/           # backend.hcl など共通の状態管理設定
├── envs/              # 環境ごとのエントリーポイント
│   ├── production/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── backend.hcl
│   └── staging/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── backend.hcl
├── modules/           # ライフサイクル単位のモジュール
│   ├── firehose_delivery_stream/
│   ├── glue_crawler/
│   ├── glue_job/
│   ├── kinesis_stream/
│   └── s3_bucket/
├── scripts/           # 必要なら terraform 実行補助用スクリプト（移行完了後は空でも可）
└── templates/         # Glue スクリプトなど静的アセット置き場
    └── glue-job/
        └── temperature_etl.py
```

- `envs/<stage>` 配下で `module` を呼び出し、単一コマンド (`terraform apply -var-file=...` など) で一括デプロイする。
- `modules/` はライフサイクルが近いリソース（Firehose+IAM、Glue Job+IAM など）をひとまとめに管理し、`name_prefix` やバケット名を入力に命名規則に沿ったリソース名・description を生成する。
- `scripts/` は Terraform import などの補助が不要になった段階で削除して問題なし。
- `templates/` には Glue ジョブのスクリプトのみ配置し、default arguments は Terraform のローカル値で組み立てる。

## 環境・命名ルール
- AWS アカウント: devcontainer が稼働する EC2 インスタンスプロファイル経由で `aws sts get-caller-identity` が返すアカウントを使用。
- リージョン: `ap-northeast-1` 固定。
- 認証: インスタンスプロファイル権限に AdministratorAccess が付与されているため追加設定は不要。
- 命名規則: `datastreamer-<stage>-<resource>`。
- タグ: `PROJECT=datastreamer`, `STAGE=prod` を共通付与。
- Terraform ステート: `s3://tfstate-store-a5gnpkub/datastreamer/<stage>/terraform.tfstate`、`use_lockfile = true` を指定。
- シークレット管理: AWS Secrets Manager に格納。Terraform から参照する場合は必要なキー名を明記する。
- デプロイ元: 当面は現行の devcontainer からの実行のみを想定。

## 運用メモ
- 既存リソースは `script/` 配下の AWS CLI スクリプトで作成されているものがすべて。Terraform 化では新規作成し直すため import 作業は不要。
- CI/CD は将来的に GitHub Actions から `terraform fmt → init → validate → plan → apply (手動承認)` の流れを実装する想定。
- `terraform/` 配下の構成に合わせて現在の `script/` と `resources/` を棚卸しし、必要なテンプレートや設定値だけを `modules/` や `templates/` に移す。
- S3 バケット名は `terraform/envs/<stage>/terraform.tfvars` で指定し、環境ごとに調整できるようにする。

## Terraform 実行手順メモ
- `terraform/envs/production/main.tf` で S3 バケット、Kinesis Stream/Firehose、Glue Job/Crawler、IAM ロールを IaC 化済み。
- 初回は `terraform/envs/production` に移動し `terraform init -backend-config=../../backend/backend.hcl` を実行 (`aws` プロバイダはインスタンスプロファイルで認証)。
- S3 バケット名は `terraform/envs/production/terraform.tfvars` に記述し、`terraform plan -var="stage=prod"`・`terraform apply -var="stage=prod"` から自動読込される。
- Glue ジョブのスクリプトは `terraform/templates/glue-job/temperature_etl.py` を編集して更新し、default arguments は `terraform/modules/glue_job/main.tf` 内のローカル定義を調整する。
- S3 バケットは `terraform/modules/s3_bucket` を `for_each` で呼び出し、環境ごとのバケット名は tfvars で指定する。
- 各モジュール内部で IAM ロール/ポリシーを定義しているため、外部 JSON テンプレートや汎用 IAM モジュールは不要。
- Firehose / Glue Job / Glue Crawler / Kinesis Stream の各モジュールは `name_prefix` を受け取り、`datastreamer-<stage>-*` 形式のリソース名と関連 description を自動生成する。
- `script/` ディレクトリの AWS CLI スクリプトは移行確認後に削除して問題なし。

## 次のアクション候補
- `terraform plan` を実行して差分を確認し、問題なければ `terraform apply` で本番リソースを再構築する。
- Secrets Manager に必要なシークレット一覧を整理し、Terraform から参照・出力する設計を決める。
- GitHub Actions での自動化（実行ロール、環境変数、バックエンドアクセス権限）の設計を詰める。
- 旧 `script/` ディレクトリを削除するタイミングを決め、ドキュメントを更新する。
