#!/bin/sh
# install-51job.sh - 一键安装 51job CLI（macOS / Linux 通用，Git Bash 亦可）
# 用法: sh install-51job.sh [--check-only]
set -eu

SJOB_CLI_SOURCE=${SJOB_CLI_SOURCE:-51job-cli}
PROFILE_BLOCK_START='# >>> recruiting-copilot npm global bin >>>'
PROFILE_BLOCK_END='# <<< recruiting-copilot npm global bin <<<'
CHECK_ONLY=0

usage() {
  cat <<'EOF'
Usage: install-51job.sh [--check-only]

一键安装 51job（前程无忧）招聘 CLI：
  1. 检查 Node.js / npm
  2. 从 npm 官方源全局安装 51job-cli（≥ 0.1.1）
  3. macOS/Linux 修复 npm 全局 bin 的 PATH
  4. 验证 51job --version

环境变量:
  SJOB_CLI_SOURCE  51job CLI 安装源（默认 51job-cli；钉版本 51job-cli@0.1.1；
                   git 开发分支用 git+https://github.com/se7enfive/51job-cli.git#main）
EOF
}

die() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check-only) CHECK_ONLY=1 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

# --- 1. 前置检查 ---
command -v node >/dev/null 2>&1 || die 'Node.js 20 or newer is required (node not found).'
command -v npm >/dev/null 2>&1 || die 'npm is required (npm not found).'

node_major=$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || printf '')
case "$node_major" in
  ''|*[!0-9]*) die "could not parse Node.js version: $node_major" ;;
esac
[ "$node_major" -ge 20 ] || die "Node.js 20 or newer is required (found v$node_major)."

npm_prefix=$(npm config get prefix)
[ -n "$npm_prefix" ] || die 'npm global prefix is empty.'

platform=$(uname -s 2>/dev/null || printf 'unknown')
case "$platform" in
  MINGW*|MSYS*|CYGWIN*) npm_bin=$npm_prefix ;;
  *) npm_bin=$npm_prefix/bin ;;
esac

printf 'Node.js: v%s\n' "$node_major"
printf 'npm global bin: %s\n' "$npm_bin"
printf '51job CLI source: %s\n' "$SJOB_CLI_SOURCE"

path_contains() {
  case ":${PATH:-}:" in
    *:"$1":*) return 0 ;;
    *) return 1 ;;
  esac
}

profile_path() {
  case "${SHELL:-}" in
    */zsh) printf '%s/.zprofile\n' "$HOME" ;;
    */bash) printf '%s/.bash_profile\n' "$HOME" ;;
    *) printf '%s/.profile\n' "$HOME" ;;
  esac
}

write_managed_path_block() {
  profile=$1
  bin_dir=$2
  mkdir -p "$(dirname "$profile")"
  touch "$profile"
  escaped_bin=$(printf '%s' "$bin_dir" | sed 's/[\\"`$]/\\&/g')
  temp_file=$(mktemp "${TMPDIR:-/tmp}/51job-profile.XXXXXX")
  awk -v start="$PROFILE_BLOCK_START" -v end="$PROFILE_BLOCK_END" '
    $0 == start { skipping = 1; next }
    $0 == end { skipping = 0; next }
    !skipping { print }
  ' "$profile" >"$temp_file"
  if [ -s "$temp_file" ] && [ "$(tail -c 1 "$temp_file" 2>/dev/null || true)" != '' ]; then
    printf '\n' >>"$temp_file"
  fi
  {
    printf '%s\n' "$PROFILE_BLOCK_START"
    printf 'export PATH="%s:$PATH"\n' "$escaped_bin"
    printf '%s\n' "$PROFILE_BLOCK_END"
  } >>"$temp_file"
  mv "$temp_file" "$profile"
}

# --- 2. PATH 修复（macOS/Linux）---
if ! path_contains "$npm_bin"; then
  if [ "$CHECK_ONLY" -eq 1 ]; then
    printf 'PATH needs update: add %s\n' "$npm_bin"
  else
    profile=$(profile_path)
    write_managed_path_block "$profile" "$npm_bin"
    PATH="$npm_bin:$PATH"
    export PATH
    printf 'Updated shell PATH in %s\n' "$profile"
  fi
fi

if [ "$CHECK_ONLY" -eq 1 ]; then
  printf 'Check only: no packages were installed.\n'
  exit 0
fi

# --- 3. 已装直接跳过 ---
if command -v 51job >/dev/null 2>&1; then
  printf '51job CLI already available at %s\n' "$(command -v 51job)"
  printf 'Version: %s\n' "$(51job --version 2>/dev/null || printf 'unknown')"
  exit 0
fi

# --- 4. 安装（默认 npm 包；git+ 源才走 clone/build/pack）---
sjob_install_source=$SJOB_CLI_SOURCE
sjob_build_dir=''
case "$SJOB_CLI_SOURCE" in
  git+*'#'*)
    command -v git >/dev/null 2>&1 || die 'git is required to build the 51job CLI from a git source.'
    sjob_repository=${SJOB_CLI_SOURCE#git+}
    sjob_repository=${sjob_repository%#*}
    sjob_ref=${SJOB_CLI_SOURCE##*#}
    [ -n "$sjob_repository" ] || die '51job CLI repository is empty.'
    [ -n "$sjob_ref" ] || die '51job CLI git ref is empty.'

    sjob_build_dir=$(mktemp -d "${TMPDIR:-/tmp}/51job-cli.XXXXXX")
    cleanup_sjob_build() {
      rm -rf "$sjob_build_dir"
    }
    trap cleanup_sjob_build 0 HUP INT TERM

    printf 'Cloning 51job CLI (%s)...\n' "$sjob_ref"
    git clone --depth 1 --branch "$sjob_ref" "$sjob_repository" "$sjob_build_dir/source"
    printf 'Building 51job CLI...\n'
    (
      cd "$sjob_build_dir/source"
      npm ci
      npm run build
      npm pack --pack-destination "$sjob_build_dir"
    )
    set -- "$sjob_build_dir"/*.tgz
    [ "$#" -eq 1 ] && [ -f "$1" ] || die '51job CLI build did not produce exactly one package archive.'
    sjob_install_source=$1
    ;;
esac

printf 'Installing 51job CLI globally...\n'
npm install -g "$sjob_install_source"

# --- 5. 验证 ---
sjob_executable=$npm_bin/51job
if [ ! -x "$sjob_executable" ]; then
  # 某些系统 bin 目录可能不在 npm_prefix，尝试 PATH 里找
  if command -v 51job >/dev/null 2>&1; then
    sjob_executable=$(command -v 51job)
  else
    die "51job CLI executable not found at $sjob_executable"
  fi
fi
"$sjob_executable" --version >/dev/null 2>&1 || die '51job CLI installed but failed to run --version.'
printf '51job CLI ready: %s\n' "$sjob_executable"
printf 'Next: run "51job login" once in a new terminal.\n'