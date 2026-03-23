# GitHub Actions & Git Workflow Guide

A complete, beginner-to-advanced guide on how to use GitHub Actions and a proper branching workflow for Flutter projects.

---

## 1. The Problem with Committing Directly to `main`

If you commit and push directly to `main`, there is no safety net. A typo, a broken test, or a compile error goes straight into production.

**Old (risky) workflow:**
```
code → git commit → git push origin main
```

**Better workflow:**
```
create branch → code → commit → push branch → open PR → CI runs → review → merge
```

---

## 2. What GitHub Actions Is

GitHub Actions is a **robot built into GitHub** that watches your repository and automatically runs tasks (analyze, test, build) whenever you push code or open a pull request.

Your instruction sheet for the robot lives in `.github/workflows/*.yml`.

---

## 3. Your Workflows Explained

> [!IMPORTANT]
> **Both workflows are currently PAUSED.** The `on:` trigger in each file is set to `workflow_dispatch` (manual run from the GitHub Actions tab only). Auto-triggers on push/PR and version tags are commented out at the top of each `.yml` file. To re-enable them, follow the instructions in the comment block at the top of `flutter_ci.yml` or `release.yml`.

### `flutter_ci.yml` — Runs on Every Push & PR

```yaml
on:
  push:
    branches: [ "main" ]   # Any direct push to main
  pull_request:
    branches: [ "main" ]   # Any PR targeting main
```

**Job 1: Analyze & Test**
| Step | What it does |
|------|-------------|
| `actions/checkout@v4` | Downloads your code onto GitHub's server |
| `subosito/flutter-action@v2` | Installs Flutter (cached for speed) |
| `flutter pub get` | Installs all packages |
| `flutter analyze --fatal-infos` | Checks for lints, warnings, errors — fails if any found |
| `flutter test --coverage` | Runs all unit tests and generates a coverage report |
| `codecov/codecov-action@v4` | Uploads `coverage/lcov.info` to Codecov for % visualization |

**Job 2: Build Windows** *(only runs if Job 1 passes)*
| Step | What it does |
|------|-------------|
| `flutter build windows --release` | Verifies the app actually compiles in release mode |

---

### `release.yml` — Full Option B: Build Everything & Ship Installer

Triggers on version tags like `v1.2.5`:

```yaml
on:
  push:
    tags:
      - 'v*.*.*'
```

**Steps in order:**

| Step | What it does |
|------|--------------|
| `flutter build windows --release` | Builds the Flutter app |
| `pip install pyinstaller + deps` | Installs Python server dependencies |
| `pyinstaller omni_bridge_server.spec` | Compiles `omni_bridge_server.exe` |
| `choco install innosetup` | Installs Inno Setup on the GitHub runner |
| `iscc installer_setup.iss` | Compiles the `.iss` script → produces `OmniBridge_Setup_vX.X.X.exe` |
| `softprops/action-gh-release@v2` | Creates GitHub Release and attaches the `.exe` installer |

> [!WARNING]
> `pyaudiowpatch` (Windows WASAPI audio) and `nvidia-riva-client` are hardware-specific packages.
> The CI runner will attempt to install them with `|| echo "...failed"` so the build doesn't break if they're unavailable.
> If your server requires these at *runtime*, the resulting binary may not work without the hardware.
> The Whisper and Riva ASR models are loaded at runtime — they are **not** bundled into the installer.

---

## 4. Day-to-Day Git Workflow

### Step 1 — Create a Branch for Every Task

Never code directly on `main`. Always start a branch:

```powershell
# Format: type/short-description
git checkout -b feat/add-settings-screen
git checkout -b fix/startup-bloc-navigation
git checkout -b test/subscription-bloc-tests
git checkout -b docs/update-architecture-guide
```

### Step 2 — Commit Often with Good Messages

Use [Conventional Commits](https://www.conventionalcommits.org/) format:

```powershell
# Features
git commit -m "feat(settings): add language selection screen"

# Bug fixes
git commit -m "fix(startup): include StartupLoading in expected states"

# Tests
git commit -m "test(subscription): add SubscriptionBloc unit tests"

# Documentation
git commit -m "docs(architecture): add unit testing section"

# Refactors
git commit -m "refactor(startup): inject IAuthRepository via constructor"

# Chores (CI, dependencies, etc.)
git commit -m "chore(ci): add Windows build job to flutter_ci.yml"
```

### Step 3 — Push Your Branch

```powershell
# First push
git push -u origin feat/add-settings-screen

# Subsequent pushes on the same branch
git push
```

### Step 4 — Open a Pull Request on GitHub

1. Go to your repository on **github.com**
2. You'll see a yellow banner: *"feat/add-settings-screen had recent pushes"* → click **"Compare & pull request"**
3. Write a short description of what changed
4. Click **"Create pull request"**

GitHub immediately triggers `flutter_ci.yml`. You'll see:

```
✅ Analyze & Test — All checks passed
✅ Build Windows — All checks passed
```

or

```
❌ Analyze & Test — flutter analyze found 2 issues
```

### Step 5 — Fix CI Failures

If CI fails, look at the **details** link to see which step failed:

```powershell
# Fix the issue locally, then:
git add .
git commit -m "fix: resolve analyzer warnings"
git push
# CI runs again automatically on the new push
```

### Step 6 — Merge

Once CI is green, click **"Merge pull request"** on GitHub.

Optionally, clean up the branch:
```powershell
git checkout main
git pull
git branch -d feat/add-settings-screen
```

---

## 5. How to Do a Release

When you're ready to ship a new version:

```powershell
# 1. Make sure main is up to date and all tests pass
git checkout main
git pull

# 2. Tag the version
git tag v1.0.0

# 3. Push the tag to GitHub
git push origin v1.0.0
```

That's it. `release.yml` fires automatically:
- Builds the Flutter Windows release binary
- Compiles the Python server into `omni_bridge_server.exe` via PyInstaller
- Packages everything into a Windows installer: `OmniBridge_Setup_v1.0.0.exe` (via Inno Setup)
- Creates a new **GitHub Release** with auto-generated release notes and the `.exe` installer attached

Users can then download the installer from the **Releases** page of your repository.

---

## 6. Setting Up Codecov (Code Coverage)

Codecov shows you what % of your code is covered by tests, and which lines are untested.

### Setup Steps

1. Go to [codecov.io](https://codecov.io) and sign in with GitHub
2. Add your repository
3. Copy your `CODECOV_TOKEN`
4. In your GitHub repo → **Settings → Secrets and variables → Actions**
5. Click **"New repository secret"**, name it `CODECOV_TOKEN`, paste the token

After your next CI run, you'll get a badge and a detailed report showing exactly which lines have no tests.

Add the badge to your `README.md`:
```markdown
[![codecov](https://codecov.io/gh/YOUR_USERNAME/omni_bridge/branch/main/graph/badge.svg)](https://codecov.io/gh/YOUR_USERNAME/omni_bridge)
```

---

## 7. Branch Protection Rules (Recommended)

Prevent anyone (including yourself) from pushing directly to `main`:

1. GitHub repo → **Settings → Branches**
2. Click **"Add branch protection rule"**
3. Branch name pattern: `main`
4. Enable:
   - ✅ **Require a pull request before merging**
   - ✅ **Require status checks to pass before merging**
     - Add: `Analyze & Test`
     - Add: `Build Windows`
   - ✅ **Require branches to be up to date before merging**
5. Click **Save**

Now `git push origin main` will be **rejected by GitHub**. Everything must go through a PR.

---

## 8. Cheat Sheet

```powershell
# Start new work
git checkout main && git pull
git checkout -b feat/my-feature

# During work
git add .
git commit -m "feat: add something"

# Done — push and open PR
git push -u origin feat/my-feature
# → Open PR on github.com
# → Wait for CI green check
# → Merge

# Ship a release
git tag v1.2.0
git push origin v1.2.0
# → GitHub Release created automatically
```

---

## 9. Workflow Files in This Project

| File | Default Trigger | Purpose |
|------|---------|---------|
| `.github/workflows/flutter_ci.yml` | `workflow_dispatch` (Manual) | Analyze + Test + Coverage + Build |
| `.github/workflows/release.yml` | `workflow_dispatch` (Manual) | Build Windows + GitHub Release |

> [!NOTE]
> To switch from **Manual** to **Auto-trigger** (on push/PR or tags), edit the `.yml` files in `.github/workflows/` and uncomment the `push:` and `pull_request:` blocks as described in their headers.
