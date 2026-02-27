#!/bin/bash
# Exclude certs/ and private/ from git rebase upstream/main.
# Run once after clone. See UPDATE.md for details.

cd "$(dirname "$0")/.."
git update-index --skip-worktree certs/cert.pem certs/key.pem certs/client.crt certs/client.key
git update-index --skip-worktree private/cookie_jwks.json private/jwks.json private/token_jwks.json
echo "Sensitive files (certs/, private/) excluded from rebase."
