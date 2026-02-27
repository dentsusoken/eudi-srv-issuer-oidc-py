# EUDIW Issuer Authorization Server (dentsusoken fork)

This is a fork of [eudi-srv-issuer-oidc-py](https://github.com/eu-digital-identity-wallet/eudi-srv-issuer-oidc-py).

For full documentation, see the [original README](https://github.com/eu-digital-identity-wallet/eudi-srv-issuer-oidc-py/blob/main/README.md).

## How this project was created

Run from the vecrea-id repository root. Create the dentsusoken fork on GitHub first.

```bash
cd vecrea-id
git submodule add https://github.com/eu-digital-identity-wallet/eudi-srv-issuer-oidc-py projects/eudi-srv-issuer-oidc-py
cd projects/eudi-srv-issuer-oidc-py
git remote rename origin upstream
git remote add origin https://github.com/dentsusoken/eudi-srv-issuer-oidc-py
git fetch upstream
git checkout main
git reset --hard upstream/main
git push -u origin main --force
```

Note: `.gitmodules` in vecrea-id points to the upstream (eu-digital-identity-wallet) repository. The fork is [public](https://github.com/dentsusoken/eudi-srv-issuer-oidc-py) for mirroring and branch workflow.

## Remote configuration

| Remote   | URL                                                       |
|----------|-----------------------------------------------------------|
| origin   | https://github.com/dentsusoken/eudi-srv-issuer-oidc-py |
| upstream | https://github.com/eu-digital-identity-wallet/eudi-srv-issuer-oidc-py |

### Initial setup (first-time clone)

Because `.gitmodules` points to the upstream (eu-digital-identity-wallet) repository, cloning gives you `origin` = upstream. Rename it to `upstream` and add your fork as `origin` before using the branch workflow:

```bash
cd projects/eudi-srv-issuer-oidc-py
git remote rename origin upstream
git remote add origin https://github.com/dentsusoken/eudi-srv-issuer-oidc-py
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
