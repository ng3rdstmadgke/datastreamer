#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <stage>" >&2
  exit 1
fi

stage="$1"

case "$stage" in
  prod|production)
    env_dir="production"
    ;;
  stg|staging)
    env_dir="staging"
    ;;
  *)
    env_dir="$stage"
    ;;
esac

tf_dir="${PROJECT_DIR}/terraform/envs/${env_dir}"

if [[ ! -d "$tf_dir" ]]; then
  echo "Environment directory not found: ${tf_dir}" >&2
  exit 1
fi

stream_name="$(terraform -chdir="$tf_dir" output -raw kinesis_stream_name)"

if [[ -z "$stream_name" ]]; then
  echo "Failed to resolve kinesis stream name from terraform outputs." >&2
  exit 1
fi

export UV_PROJECT_ENVIRONMENT="${PROJECT_DIR}/.venv"

uv run --project "$PROJECT_DIR" --directory "$PROJECT_DIR" sensor.py --stream-name "$stream_name"
