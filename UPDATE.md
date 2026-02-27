# EUDIW Issuer Authorization Server (dentsusoken fork)

This is a fork of [eudi-srv-issuer-oidc-py](https://github.com/eu-digital-identity-wallet/eudi-srv-issuer-oidc-py).

For full documentation, see the [original README](https://github.com/eu-digital-identity-wallet/eudi-srv-issuer-oidc-py/blob/main/README.md).

## How this project was created

Run from the vecrea-id repository root. Create the dentsusoken fork on GitHub first.

```bash
cd vecrea-id
git submodule add https://github.com/dentsusoken/eudi-srv-issuer-oidc-py projects/eudi-srv-issuer-oidc-py
cd projects/eudi-srv-issuer-oidc-py
git remote add upstream https://github.com/eu-digital-identity-wallet/eudi-srv-issuer-oidc-py
git fetch upstream
git checkout main
git reset --hard upstream/main
git push -u origin main --force
```

Note: Add the submodule from the dentsusoken fork URL so `.gitmodules` points to the fork from the start. The submodule references commits (e.g. this UPDATE.md) that exist only in our fork, not in the original. GitHub uses the `.gitmodules` URL to build the submodule link, so it must point to the fork. The fork is now [public](https://github.com/dentsusoken/eudi-srv-issuer-oidc-py), so the link works for everyone.

## Remote configuration

| Remote   | URL                                                       |
|----------|-----------------------------------------------------------|
| origin   | https://github.com/dentsusoken/eudi-srv-issuer-oidc-py |
| upstream | https://github.com/eu-digital-identity-wallet/eudi-srv-issuer-oidc-py |

### Excluding sensitive files from rebase

The `certs/` directory contains private keys, and `private/` contains JWKS and other secrets. **Run the setup script once after clone** so `git rebase upstream/main` does not overwrite your local files:

```bash
cd projects/eudi-srv-issuer-oidc-py
./scripts/setup-sensitive-files.sh
```

Run again after a fresh clone.

To undo: `git update-index --no-skip-worktree certs/cert.pem certs/key.pem certs/client.crt certs/client.key private/cookie_jwks.json private/jwks.json private/token_jwks.json`

### Initial setup (first-time clone)

Because `.gitmodules` points to the dentsusoken fork, cloning gives you `origin` = fork. Add `upstream` and run the sensitive-files setup:

```bash
cd projects/eudi-srv-issuer-oidc-py
git remote add upstream https://github.com/eu-digital-identity-wallet/eudi-srv-issuer-oidc-py
./scripts/setup-sensitive-files.sh
```

## Working with branches

### Creating a new branch

```bash
cd projects/eudi-srv-issuer-oidc-py
git fetch upstream
git checkout -b <branch-name> upstream/main
```

### Updating main from upstream

To sync `main` with the original repository:

```bash
cd projects/eudi-srv-issuer-oidc-py
git checkout main
git fetch upstream
git rebase upstream/main
```

### Updating a branch (other than main) from upstream

To sync a branch with the latest upstream:

```bash
cd projects/eudi-srv-issuer-oidc-py
git checkout <branch-name>
git fetch upstream
git rebase upstream/main
```
