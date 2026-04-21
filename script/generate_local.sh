#!/bin/bash
# _local ファイルを patches/ から生成するスクリプト
# 使い方: git pull 後に ./generate_local.sh を実行
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OIDC_REPO="$SCRIPT_DIR/.."
EUDIW_REPO="$SCRIPT_DIR/../../eudi-srv-web-issuing-eudiw-py"
FRONTEND_REPO="$SCRIPT_DIR/../../eudi-srv-web-issuing-frontend-eudiw-py"

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

# config_countries.py and config_service.py were deleted/refactored in v0.9.4.
# These _local files are still needed by the container (pre-v0.9.4 image),
# so we generate them from the last known good commit.
apply_patch_from_git() {
    local git_ref="$1"
    local git_path="$2"
    local output="$3"
    local patchfile="$4"
    local tmpfile
    tmpfile=$(mktemp)
    if git show "${git_ref}:${git_path}" > "$tmpfile" 2>/dev/null; then
        if patch --output="$output" "$tmpfile" < "$patchfile" > /dev/null 2>&1; then
            echo "  OK: $(basename "$output") (from git ${git_ref})"
        else
            echo "  CONFLICT: $(basename "$patchfile") - manual resolution needed"
        fi
    else
        echo "  ERROR: $(basename "$git_path") not found at ${git_ref}"
    fi
    rm -f "$tmpfile"
}

# ---- eudi-srv-issuer-oidc-py ----
echo "=== eudi-srv-issuer-oidc-py ==="
cd "$OIDC_REPO"
apply_patch config.json               config_local.json               patches/config_local.patch
apply_patch openid-configuration.json openid-configuration_local.json patches/openid-configuration_local.patch
apply_patch server.py                 server_local.py                 patches/server_local.patch
apply_patch views.py                  views_local.py                  patches/views_local.patch

# ---- eudi-srv-web-issuing-eudiw-py ----
# NOTE: All _local files for eudiw-py are generated from the pre-v0.9.4 base (be1b9c2)
# because the Docker container image still uses the pre-v0.9.4 runtime.
# The patches contain only our local customizations on top of that base.
echo ""
echo "=== eudi-srv-web-issuing-eudiw-py ==="
cd "$EUDIW_REPO"
EUDIW_BASE="be1b9c2"
apply_patch_from_git $EUDIW_BASE app/metadata_config/metadata_config.json      app/metadata_config/metadata_config_local.json      patches/metadata_config_local.patch
apply_patch_from_git $EUDIW_BASE app/metadata_config/openid-configuration.json app/metadata_config/openid-configuration_local.json patches/openid-configuration_local.patch
apply_patch_from_git $EUDIW_BASE app/route_oidc.py                             app/route_oidc_local.py                             patches/route_oidc_local.patch
apply_patch_from_git $EUDIW_BASE app/dynamic_func.py                           app/dynamic_func_local.py                           patches/dynamic_func_local.patch
apply_patch_from_git $EUDIW_BASE app/route_dynamic.py                          app/route_dynamic_local.py                          patches/route_dynamic_local.patch
apply_patch_from_git $EUDIW_BASE app/formatter_func.py                         app/formatter_func_local.py                         patches/formatter_func_local.patch
apply_patch_from_git $EUDIW_BASE app/app_config/config_countries.py            app/app_config/config_countries_local.py            patches/config_countries_local.patch
apply_patch_from_git $EUDIW_BASE app/app_config/config_service.py              app/app_config/config_service_local.py              patches/config_service_local.patch
# config_issuer_backend_example.yaml was introduced in v0.9.4 (not in EUDIW_BASE), so use apply_patch directly
apply_patch          app/config_issuer_backend_example.yaml                    app/config_issuer_backend_local.yaml                patches/config_issuer_backend_local.patch

# ---- eudi-srv-web-issuing-frontend-eudiw-py ----
echo ""
echo "=== eudi-srv-web-issuing-frontend-eudiw-py ==="
cd "$FRONTEND_REPO"
apply_patch app/__init__.py      app/__init__local.py       patches/__init__.patch
apply_patch app/auth_redirect.py app/auth_redirect_local.py patches/auth_redirect.patch

echo ""
echo "Done!"
