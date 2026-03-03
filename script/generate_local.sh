#!/bin/bash
# _local ファイルを patches/ から生成するスクリプト
# 使い方: git pull 後に ./generate_local.sh を実行
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OIDC_REPO="$SCRIPT_DIR/.."
EUDIW_REPO="$SCRIPT_DIR/../../eudi-srv-web-issuing-eudiw-py"

apply_patch() {
    local original="$1"
    local output="$2"
    local patchfile="$3"
    if patch --output="$output" "$original" < "$patchfile" > /dev/null 2>&1; then
        echo "  OK: $(basename "$output")"
    else
        echo "  CONFLICT: $(basename "$patchfile") - manual resolution needed"
    fi
}

# ---- eudi-srv-issuer-oidc-py ----
echo "=== eudi-srv-issuer-oidc-py ==="
cd "$OIDC_REPO"
apply_patch config.json               config_local.json               patches/config_local.patch
apply_patch openid-configuration.json openid-configuration_local.json patches/openid-configuration_local.patch
apply_patch server.py                 server_local.py                 patches/server_local.patch
apply_patch views.py                  views_local.py                  patches/views_local.patch

# ---- eudi-srv-web-issuing-eudiw-py ----
echo ""
echo "=== eudi-srv-web-issuing-eudiw-py ==="
cd "$EUDIW_REPO"
apply_patch app/metadata_config/metadata_config.json      app/metadata_config/metadata_config_local.json      patches/metadata_config_local.patch
apply_patch app/metadata_config/openid-configuration.json app/metadata_config/openid-configuration_local.json patches/openid-configuration_local.patch
apply_patch app/route_oidc.py                             app/route_oidc_local.py                             patches/route_oidc_local.patch
apply_patch app/dynamic_func.py                           app/dynamic_func_local.py                           patches/dynamic_func_local.patch

echo ""
echo "Done!"
