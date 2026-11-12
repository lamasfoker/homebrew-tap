class Scrapling < Formula
  desc "Adaptive web scraping framework and CLI — installed with a private, vendored Python runtime"
  homepage "https://github.com/D4Vinci/Scrapling"
  url "https://files.pythonhosted.org/packages/eb/db/d961321c017e6a185a08816830c27941602b0da43ef797cfd2906d0ef17b/scrapling-0.5.1.tar.gz"
  sha256 "210e2b96cf2a67b0bb77e3671b2767bbad4ba41444b9a12adea7fd735b8cabaa"
  license "BSD-3-Clause"

  livecheck do
    url :stable
    strategy :pypi
  end

  # Vendored Python and uv. This formula intentionally does NOT `depends_on "python"` —
  # scrapling is installed and run only against this private copy, never against any
  # Python the user has on PATH (system, pyenv, brew, etc).
  resource "python" do
    on_macos do
      on_arm do
        url "https://github.com/astral-sh/python-build-standalone/releases/download/20261110/cpython-3.13.18%2B20261110-aarch64-apple-darwin-install_only_stripped.tar.gz"
        sha256 "7a2384641584ab9984221fcb0fc9265df465922af71be71410529e2a9c3f0540"
      end
      on_intel do
        url "https://github.com/astral-sh/python-build-standalone/releases/download/20261110/cpython-3.13.18%2B20261110-x86_64-apple-darwin-install_only_stripped.tar.gz"
        sha256 "d27d59a722db9f69926eb6d9564071247221f45a04da920ea7f3001c97e32f9b"
      end
    end
  end

  resource "uv" do
    on_macos do
      on_arm do
        url "https://github.com/astral-sh/uv/releases/download/0.13.7/uv-aarch64-apple-darwin.tar.gz"
        sha256 "81b811b57e4624df7ed3aac148e0359100d9962f3d9dce00aec533dc2e086731"
      end
      on_intel do
        url "https://github.com/astral-sh/uv/releases/download/0.13.7/uv-x86_64-apple-darwin.tar.gz"
        sha256 "20c47e4c1f630b8abaff8c291fa9b9aa300fef92c4fbff95adf198b55287cda7"
      end
    end
  end

  def install
    resource("python").stage libexec/"python"
    resource("uv").stage libexec/"uv"
    pkgshare.mkpath
    cp Pathname(__dir__)/"scrapling-requirements.lock", pkgshare

    (bin/"scrapling").write <<~SH
      #!/bin/bash
      export PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSERS_PATH:-#{var}/scrapling/browsers}"
      exec "#{libexec}/venv/bin/scrapling" "$@"
    SH
  end

  # The venv is built here, not in `install`: Homebrew relinks every Mach-O file that `install`
  # leaves behind, and it cannot rewrite the dylib ID of orjson's wheel binary (header too small).
  def post_install
    ENV["DO_NOT_TRACK"] = "1"
    ENV["UV_NO_CONFIG"] = "1"
    ENV["UV_PYTHON_DOWNLOADS"] = "never"

    (var/"scrapling/browsers").mkpath

    uv = (libexec/"uv").glob("**/uv").first
    venv = libexec/"venv"
    system uv, "venv", "--allow-existing", "--python", libexec/"python/bin/python3", venv
    system uv, "pip", "sync", "--no-cache", "--python", venv/"bin/python",
           "--require-hashes", "--only-binary", ":all:",
           pkgshare/"scrapling-requirements.lock"
  end

  def caveats
    <<~EOS
      Browser fetchers need their browsers once:
        scrapling install
      The browsers are stored in #{var}/scrapling/browsers.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/scrapling --version")
    assert_match "extract", shell_output("#{bin}/scrapling --help")

    (testpath/"page.html").write "<html><body><h1>Hello Scrapling</h1></body></html>"
    system bin/"scrapling", "extract", "get", "file://#{testpath}/page.html", testpath/"out.md"
    assert_match "Hello Scrapling", (testpath/"out.md").read
  end
end
