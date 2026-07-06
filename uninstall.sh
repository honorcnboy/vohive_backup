#!/bin/sh
set -eu

DRY_RUN=0
PURGE=0
KEEP_CONFIG=0

ROOT_DIR="${VOHIVE_INSTALL_ROOT:-/opt/vohive}"
BIN_PATH="${ROOT_DIR}/bin/vohive"
BACKUP_PATH="${ROOT_DIR}/bin/vohive.bak"
SYSTEMD_SERVICE_PATH="${VOHIVE_SYSTEMD_SERVICE_PATH:-/etc/systemd/system/vohive.service}"
OPENWRT_INIT_PATH="${VOHIVE_OPENWRT_INIT_PATH:-/etc/init.d/vohive}"
OPENWRT_RELEASE_FILE="${VOHIVE_OPENWRT_RELEASE_FILE:-/etc/openwrt_release}"
PROCD_PATH="${VOHIVE_PROCD_PATH:-/sbin/procd}"
SYSTEMD_RUN_DIR="${VOHIVE_SYSTEMD_RUN_DIR:-/run/systemd/system}"
CONFIG_DIR="${ROOT_DIR}/config"
DATA_DIR="${ROOT_DIR}/data"
LOG_DIR="${ROOT_DIR}/logs"

log() { printf '[vohive-uninstall] %s\n' "$*"; }
err() { printf '[vohive-uninstall] 错误: %s\n' "$*" >&2; }

usage() {
  cat <<USAGE
Usage: uninstall.sh [options]
  --purge
  --keep-config
  --dry-run
USAGE
}

run_root() {
  if [ "${DRY_RUN}" = "1" ]; then
    printf '[dry-run] %s' "$1"
    shift
    for arg in "$@"; do
      printf ' %s' "$arg"
    done
    printf '\n'
    return 0
  fi

  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    err "需要 root 权限（请使用 root 用户或安装 sudo）。"
    exit 1
  fi
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --purge)
        PURGE=1
        shift
        ;;
      --keep-config)
        KEEP_CONFIG=1
        shift
        ;;
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        err "未知参数: $1"
        usage
        exit 1
        ;;
    esac
  done
}

detect_platform() {
  if [ -n "${VOHIVE_PLATFORM_OVERRIDE:-}" ]; then
    printf '%s\n' "${VOHIVE_PLATFORM_OVERRIDE}"
    return 0
  fi
  if [ -f "${OPENWRT_RELEASE_FILE}" ] || [ -x "${PROCD_PATH}" ]; then
    printf 'openwrt\n'
    return 0
  fi
  if command -v systemctl >/dev/null 2>&1 && { [ -d "${SYSTEMD_RUN_DIR}" ] || [ -f "${SYSTEMD_RUN_DIR}" ]; }; then
    printf 'systemd\n'
    return 0
  fi
  printf 'none\n'
}

remove_service_systemd() {
  run_root systemctl stop vohive || true
  run_root systemctl disable vohive || true
  run_root rm -f "${SYSTEMD_SERVICE_PATH}"
  run_root systemctl daemon-reload || true
}

remove_service_openwrt() {
  if [ -f "${OPENWRT_INIT_PATH}" ]; then
    run_root "${OPENWRT_INIT_PATH}" stop || true
    run_root "${OPENWRT_INIT_PATH}" disable || true
    run_root rm -f "${OPENWRT_INIT_PATH}"
  fi
}

main() {
  parse_args "$@"

  platform="$(detect_platform)"
  case "${platform}" in
    openwrt)
      remove_service_openwrt
      ;;
    systemd)
      remove_service_systemd
      ;;
    none)
      log "未检测到 systemd 或 OpenWrt procd，跳过服务卸载"
      ;;
    *)
      err "未知平台: ${platform}"
      exit 1
      ;;
  esac

  run_root rm -f "${BIN_PATH}" "${BACKUP_PATH}"

  if [ "${PURGE}" = "1" ]; then
    if [ "${KEEP_CONFIG}" = "0" ]; then
      run_root rm -rf "${CONFIG_DIR}"
    fi
    run_root rm -rf "${DATA_DIR}"
    run_root rm -rf "${LOG_DIR}"
    run_root rmdir "${ROOT_DIR}/bin" 2>/dev/null || true
    run_root rmdir "${ROOT_DIR}" 2>/dev/null || true
  fi

  log "卸载完成"
}

main "$@"
