#!/bin/bash

# errorレベルのエラーメッセージを出力しつつスクリプトを異常終了させる関数
function error {
  echo "[error] $1" >&2
  exit 1
}

# infoレベルのエラーメッセージを出力する関数
function info {
  echo "[info] $1"
}