#!/bin/bash
set -euo pipefail

usage() {
    echo "Usage: $0 <source_docs_dir> <dest_docs_dir>" >&2
    exit 1
}

SRC_ROOT=${1:-}
DEST_ROOT=${2:-}

[[ -n "$SRC_ROOT" && -n "$DEST_ROOT" ]] || usage
[[ -d "$SRC_ROOT" ]] || { echo "Source directory '$SRC_ROOT' does not exist" >&2; exit 2; }

SRC_ROOT=${SRC_ROOT%/}
DEST_ROOT=${DEST_ROOT%/}
mkdir -p "$DEST_ROOT"

# 用 process substitution 避免 while 跑在 subshell
count=0
while IFS= read -r -d '' SRC_FILE; do
    REL_PATH=${SRC_FILE#"$SRC_ROOT"/}
    DEST_FILE="$DEST_ROOT/$REL_PATH"

    if [[ -f "$DEST_FILE" ]]; then
        continue
    fi

    DEST_DIR=$(dirname "$DEST_FILE")
    mkdir -p "$DEST_DIR"

    PROMPT=$(cat <<EOF
請翻譯 ${SRC_FILE} 成正體中文，並將翻譯結果儲存為：${DEST_FILE}。請依原始檔案結構建立必要的子資料夾並保留檔名。
【翻譯要求】
- 將所有內容翻譯為繁體中文
- 所有 \`：\` 前的名詞，通常代表專業名詞，但如果格式為markdown超連結，則可以翻譯
- 保留所有程式相關的專業術語為英文，包括但不限於：
    - 以下名詞: Graph、Edge、Node
EOF
    )

    echo "Translating: $SRC_FILE -> $DEST_FILE" >&2
    copilot --model "claude-haiku-4.5" -p "$PROMPT" --allow-all-tools &
    count=$((count + 1))

    if (( count % 10 == 0 )); then
        wait
    fi
done < <(find "$SRC_ROOT" -type f -name '*.md' -print0)

wait
echo "全部翻譯完成"
