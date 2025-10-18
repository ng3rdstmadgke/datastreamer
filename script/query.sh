#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE >&2
Usage: $0 <stage> <yyyy-mm-dd> [table_name]

Examples:
  $0 prod 2025-10-16
  ATHENA_WORKGROUP=analytics $0 staging 2025-10-15 curated_device_telemetry

Environment variables:
  ATHENA_WORKGROUP   Athena workgroup to use (default: primary).
USAGE
exit 1
}

SCRIPT_DIR="$(cd $(dirname $0);  pwd)"
source "${SCRIPT_DIR}/utils.sh"

args=()
while [ "$#" != 0 ]; do
  case $1 in
    -h | --help ) usage ;;
    -* | --*    ) error "$1 : 不正なオプションです" ;;
    *           ) args+=("$1") ;;
  esac
  shift
done

[ "${#args[@]}" -lt 2 ] && usage && exit 1


#
# stage パラメータのバリデーション
#
case "${args[0]}" in
  prod | production ) stage="production"; env_dir="$stage" ;;
  *                 ) stage="${args[0]}"; env_dir="$stage" ;;
esac
tf_dir="${PROJECT_DIR}/terraform/envs/${env_dir}"
if [[ ! -d "$tf_dir" ]]; then
  error "Environment directory not found: ${tf_dir}"
fi

#
# date パラメータのバリデーション
#
query_date="${args[1]}"
if ! [[ "$query_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  error "Invalid date format: ${query_date} (expected YYYY-MM-DD)"
fi
IFS="-" read -r year month day <<< "$query_date"



#
# テーブル名
#
table_name="${3:-device_telemetry}"


#
# Athena クエリの構築
#
query_string=$(cat <<EOF
SELECT
  device_id,
  AVG(temperature) AS avg_temp
FROM ${table_name}
WHERE year='${year}' AND month='${month}' AND day='${day}'
GROUP BY device_id
ORDER BY device_id ASC
EOF
)
info "Athena Query:"
info "$query_string"


#
# Athena クエリの実行
#

workgroup="${ATHENA_WORKGROUP:-primary}"   # Glue Data Catalog 上のデータベース名
database_name="$(terraform -chdir="$tf_dir" output -raw glue_database_name)"
analytics_bucket="$(terraform -chdir="$tf_dir" output -raw analytics_bucket_name)"
output_location="s3://${analytics_bucket}/athena-results/${stage}/"
info "Athena: workgroup=${workgroup}, database=${database_name}, table_name=${table_name}"
info "Executing Athena query..."
query_execution_id="$(
  aws athena start-query-execution \
    --work-group "$workgroup" \
    --query-string "$query_string" \
    --query-execution-context Database="$database_name" \
    --result-configuration OutputLocation="$output_location" \
    --query 'QueryExecutionId' \
    --output text
)"
info "QueryExecutionId: ${query_execution_id}"

#
# クエリの完了を待機
#
while true; do
  state="$(
    aws athena get-query-execution \
      --query-execution-id "$query_execution_id" \
      --query 'QueryExecution.Status.State' \
      --output text
  )"

  case "$state" in
    SUCCEEDED       ) break ;;
    FAILED|CANCELLED)
      reason="$(
        aws athena get-query-execution \
          --query-execution-id "$query_execution_id" \
          --query 'QueryExecution.Status.StateChangeReason' \
          --output text
      )"
      error "Query ${state}: ${reason}"
      ;;
    QUEUED|RUNNING ) sleep 2 ;;
    *              ) info "Unknown query state: ${state}"; sleep 2 ;;
  esac
done

info "Query succeeded. Fetching results..."
aws athena get-query-results \
  --query-execution-id "$query_execution_id" \
  --output table

result_csv_path="${output_location}${query_execution_id}.csv"
info "Result stored at: ${result_csv_path}"
info "CSV output:"
aws s3 cp "${result_csv_path}" - | column -t -s ','
