#!/bin/bash
#
# This script installs the latest version into /usr/local/bin or TARGET if specified
#
set -eo pipefail

required_tools=("curl" "grep" "awk" "unzip")
for tool in "${required_tools[@]}"; do
  if ! command -v "$tool" &>/dev/null; then
    echo "Error: '$tool' is required but not installed. Please install it first."
    exit 1
  fi
done

main() {
  TARGET="${TARGET:-${1:-}}"

  if [[ -z "$TARGET" ]]; then
    if [[ -w "/usr/local/bin" ]]; then
      TARGET="/usr/local/bin"
    else
      TARGET="./bin"
    fi
  fi

  local username="tractordev"
  local repo="wanix"
  local binpath="${TARGET}"

  local repoURL="https://github.com/${username}/${repo}"

  local releaseURL
  releaseURL="$(curl -sI ${repoURL}/releases/latest | grep 'location:' | awk '{print $2}')"

  local version
  version="$(basename "$releaseURL" | cut -c 2- | tr -d '\r')"

  local os=""
  local arch=""

  # Detect operating system
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    os="linux"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    os="darwin"
  elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    # WSL uses msys or cygwin as OSTYPE
    os="windows"
  else
    echo "Error: Unsupported operating system: $OSTYPE"
    exit 1
  fi

  # Detect architecture
  if [[ "$(uname -m)" == "x86_64" ]]; then
    arch="amd64"
  elif [[ "$(uname -m)" == "arm64" ]]; then
    arch="arm64"
  elif [[ "$(uname -m)" == "aarch64" ]]; then
    arch="arm64"
  else
    echo "Error: Unsupported architecture: $(uname -m)"
    exit 1
  fi

  local filename="${repo}_${version}_${os}_${arch}.zip"
  curl -sSLO "${repoURL}/releases/download/v${version}/${filename}"

  local errorCode=0

  # Check if write permission is available
  if ! mkdir -p "$binpath" || [[ ! -w "$binpath" ]]; then
    echo "Error: No write permission for $binpath. Try running with sudo or choose a different TARGET."
    errorCode=1
  else
    unzip -fo "$filename" wanix -d "$binpath"
    echo "Executable wanix ${version} installed to ${binpath}"
  fi

  rm "./$filename"

  return $errorCode
}

main "$@"
