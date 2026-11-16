class Lighthouse < Formula
  desc "Google Lighthouse web page auditor — installed with a private, vendored Node.js runtime"
  homepage "https://github.com/GoogleChrome/lighthouse"
  url "https://registry.npmjs.org/lighthouse/-/lighthouse-13.6.0.tgz"
  sha256 "214d7c83d25de829b0f0b6dad48c9fe8d994e1e76a51788a9a1d6911bc45ddaa"
  license "Apache-2.0"

  livecheck do
    url "https://registry.npmjs.org/lighthouse"
    strategy :npm
  end

  # homebrew-core's `lighthouse` (the Ethereum client) also installs `bin/lighthouse`.
  conflicts_with "lighthouse", because: "both install a `lighthouse` binary"

  # Vendored Node.js runtime. This formula intentionally does NOT `depends_on "node"` —
  # lighthouse is installed and run only against this private copy, never against any
  # Node.js the user has on PATH (system, nvm, volta, etc).
  resource "node" do
    on_macos do
      on_arm do
        url "https://nodejs.org/dist/v26.13.1/node-v26.13.1-darwin-arm64.tar.gz"
        sha256 "aec2514ea1ceb2ba52455e9ec65986f6749a06dd759e5db2a72e6889668c9735"
      end
      on_intel do
        url "https://nodejs.org/dist/v26.13.1/node-v26.13.1-darwin-x64.tar.gz"
        sha256 "82bb96078a24ca50b9c9a38f2379e6be6d87171fcd400fc14c8934b3bce96e2f"
      end
    end
  end

  def install
    node_dir = libexec/"node"
    resource("node").stage node_dir

    node = node_dir/"bin/node"
    npm_cli = node_dir/"lib/node_modules/npm/bin/npm-cli.js"

    ENV.prepend_path "PATH", node_dir/"bin"
    system node, npm_cli, "install", "--omit=dev", "--ignore-scripts", "--no-audit", "--no-fund"

    libexec.install buildpath.children

    (bin/"lighthouse").write <<~SH
      #!/bin/bash
      exec "#{node}" "#{libexec}/cli/index.js" "$@"
    SH
  end

  test do
    assert_equal version.to_s, shell_output("#{bin}/lighthouse --version").strip
    assert_match "lighthouse <url>", shell_output("#{bin}/lighthouse --help")
  end
end
