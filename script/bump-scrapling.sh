#!/bin/bash
# Rewrites Formula/scrapling.rb and Formula/scrapling-requirements.lock in place:
#   - pins the scrapling sdist on PyPI to the latest published version
#   - pins the vendored uv (darwin arm64 + x64) to the latest release
#   - pins the vendored python-build-standalone 3.13 (darwin arm64 + x64) to the latest release
#   - regenerates the hashed lock (universal, wheels only) for scrapling[shell]
#
# Usage: script/bump-scrapling.sh   (needs curl, jq, python3 and uv on PATH)
# Exits 0 with no changes if everything is already current; prints what changed to stdout.
set -euo pipefail

formula="Formula/scrapling.rb"
lock="Formula/scrapling-requirements.lock"
cd "$(dirname "$0")/.."

auth=()
[ -n "${GH_TOKEN:-}" ] && auth=(-H "Authorization: Bearer ${GH_TOKEN}")
gh_api() { curl -fsSL ${auth[@]+"${auth[@]}"} "https://api.github.com/repos/$1"; }

pypi=$(curl -fsSL https://pypi.org/pypi/scrapling/json)
version=$(jq -r '.info.version' <<<"$pypi")
sdist_url=$(jq -r '.urls[] | select(.packagetype == "sdist") | .url' <<<"$pypi")
sdist_sha=$(jq -r '.urls[] | select(.packagetype == "sdist") | .digests.sha256' <<<"$pypi")

uv_tag=$(gh_api astral-sh/uv/releases/latest | jq -r '.tag_name')
uv_sha_arm=$(curl -fsSL "https://github.com/astral-sh/uv/releases/download/${uv_tag}/uv-aarch64-apple-darwin.tar.gz.sha256" | awk '{print $1}')
uv_sha_x64=$(curl -fsSL "https://github.com/astral-sh/uv/releases/download/${uv_tag}/uv-x86_64-apple-darwin.tar.gz.sha256" | awk '{print $1}')

pbs_tag=$(gh_api astral-sh/python-build-standalone/releases/latest | jq -r '.tag_name')
pbs_sums=$(curl -fsSL "https://github.com/astral-sh/python-build-standalone/releases/download/${pbs_tag}/SHA256SUMS")
pbs_file() { grep -m1 -oE "cpython-3\.13\.[0-9]+\+${pbs_tag}-$1-apple-darwin-install_only_stripped\.tar\.gz" <<<"$pbs_sums"; }
pbs_arm=$(pbs_file aarch64)
pbs_x64=$(pbs_file x86_64)
pbs_sha_arm=$(grep -F "  ${pbs_arm}" <<<"$pbs_sums" | awk '{print $1}')
pbs_sha_x64=$(grep -F "  ${pbs_x64}" <<<"$pbs_sums" | awk '{print $1}')

for v in version sdist_url sdist_sha uv_tag uv_sha_arm uv_sha_x64 pbs_tag pbs_arm pbs_x64 pbs_sha_arm pbs_sha_x64; do
  [ -n "${!v}" ] || { echo "bump-scrapling: could not resolve ${v}" >&2; exit 1; }
done

FORMULA="$formula" VERSION="$version" SDIST_URL="$sdist_url" SDIST_SHA="$sdist_sha" \
UV_TAG="$uv_tag" UV_SHA_ARM="$uv_sha_arm" UV_SHA_X64="$uv_sha_x64" \
PBS_TAG="$pbs_tag" PBS_ARM="$pbs_arm" PBS_X64="$pbs_x64" PBS_SHA_ARM="$pbs_sha_arm" PBS_SHA_X64="$pbs_sha_x64" \
python3 - <<'PY'
import os, re
from urllib.parse import quote

e = os.environ
path = e["FORMULA"]
text = open(path).read()

def sub(pattern, replacement):
    global text
    new, n = re.subn(pattern, lambda m: replacement(m), text, count=1, flags=re.S)
    if n != 1:
        raise SystemExit(f"bump-scrapling: pattern not found: {pattern}")
    text = new

sub(r'(  url ")[^"]+(scrapling-[^"]+\.tar\.gz"\n  sha256 ")[0-9a-f]+(")',
    lambda m: f'{m[1]}{e["SDIST_URL"]}"\n  sha256 "{e["SDIST_SHA"]}"')

def resource_block(name, arm_url, arm_sha, x64_url, x64_sha):
    pat = (r'(  resource "' + name + r'" do\n    on_macos do\n      on_arm do\n        url ")[^"]+(\"\n        sha256 ")[0-9a-f]+'
           r'(\"\n      end\n      on_intel do\n        url ")[^"]+(\"\n        sha256 ")[0-9a-f]+(")')
    sub(pat, lambda m: f'{m[1]}{arm_url}{m[2]}{arm_sha}{m[3]}{x64_url}{m[4]}{x64_sha}{m[5]}')

pbs_base = f'https://github.com/astral-sh/python-build-standalone/releases/download/{e["PBS_TAG"]}/'
resource_block("python", pbs_base + quote(e["PBS_ARM"]), e["PBS_SHA_ARM"], pbs_base + quote(e["PBS_X64"]), e["PBS_SHA_X64"])
uv_base = f'https://github.com/astral-sh/uv/releases/download/{e["UV_TAG"]}/'
resource_block("uv", uv_base + "uv-aarch64-apple-darwin.tar.gz", e["UV_SHA_ARM"], uv_base + "uv-x86_64-apple-darwin.tar.gz", e["UV_SHA_X64"])

open(path, "w").write(text)
PY

echo "scrapling[shell]==${version}" > "${TMPDIR:-/tmp}/scrapling.in"
uv pip compile "${TMPDIR:-/tmp}/scrapling.in" --universal --generate-hashes --only-binary :all: --upgrade \
  --python-version 3.13 --no-header --no-annotate -o "$lock" >/dev/null

if git diff --quiet -- "$formula" "$lock"; then
  changed=0
  echo "Already up to date."
else
  changed=1
  git diff --stat -- "$formula" "$lock"
fi

echo "changed=${changed}" >> "${GITHUB_OUTPUT:-/dev/null}"
