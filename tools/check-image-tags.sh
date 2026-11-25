#!/usr/bin/env bash
# 画面が使うノードのイメージのタグ（frontend/src/types/lab.ts）と、compose.yaml の init-images の既定のタグが、
# そろっているかを確かめる。ずれていると、画面が使うイメージを init-images が取得せず、ラボが起動できない。
# 使い方: bash tools/check-image-tags.sh   （ずれていれば終了コード 1。CI でも実行する）
set -euo pipefail
cd "$(dirname "$0")/.."
bad=0
check() { # $1=lab.ts内の名前 $2=composeの環境変数名
  want=$(grep -oE "fnl/$1:[0-9]+" frontend/src/types/lab.ts | head -1 | cut -d: -f2)
  have=$(grep -oE "$2:-[0-9]+" backend/compose/compose.yaml | head -1 | cut -d- -f2)
  if [ -z "$want" ] || [ -z "$have" ]; then echo "読み取れません: $1 / $2" >&2; bad=1
  elif [ "$want" != "$have" ]; then echo "ずれています: fnl/$1 は画面が :$want、compose の $2 は :$have" >&2; bad=1
  else echo "ok: fnl/$1:$want"; fi
}
check frr FNL_FRR_TAG
check l2switch FNL_L2_TAG
check l3switch FNL_L3_TAG
exit $bad
