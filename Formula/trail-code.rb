class TrailCode < Formula
  desc "Context layer for coding agents — installed with a private, vendored Node.js runtime"
  homepage "https://github.com/trailhq/Trail-Code"
  url "https://registry.npmjs.org/@trailhq/trail-code/-/trail-code-0.30.5.tgz"
  sha256 "59494d4273c5829dd3f20e0be7a4de4083f3181ffef2c7c8d82856fe0b944841"
  license "MIT"

  livecheck do
    url "https://registry.npmjs.org/@trailhq%2ftrail-code"
    strategy :npm
  end

  # Vendored Node.js runtime. This formula intentionally does NOT `depends_on "node"` —
  # trail is installed and run only against this private copy, never against any
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

    # Install scripts of dependencies run a bare `node`, so the vendored runtime must be first on PATH.
    ENV.prepend_path "PATH", node_dir/"bin"
    # `brew install` must not send the install event that `npm i -g` sends.
    ENV["DO_NOT_TRACK"] = "1"

    # Install the packed tarball, not the directory: a directory install is a symlink into buildpath.
    system node, npm_cli, "pack", "--ignore-scripts"
    system node, npm_cli, "install", "--global", "--prefix=#{libexec}", "--no-audit", "--no-fund",
           buildpath.glob("*.tgz").first

    package = libexec/"lib/node_modules/@trailhq/trail-code"
    inreplace package/"dist/bin/trail.js", "#!/usr/bin/env node", "#!#{node}"

    # A symlink, not a wrapper: the agent hook shims find the package by following `trail` on PATH.
    bin.install_symlink libexec/"bin/trail"
  end

  test do
    ENV["DO_NOT_TRACK"] = "1"

    assert_equal version.to_s, shell_output("#{bin}/trail --version").strip

    (testpath/"src").mkpath
    (testpath/"src/Greeter.php").write "<?php\nclass Greeter { public function hi() { return 'hi'; } }\n"
    (testpath/"src/Main.kt").write "fun main() { println(\"hi\") }\n"
    system "git", "init", "--quiet", testpath
    system "git", "-C", testpath, "add", "."
    assert_match "parsed: 2 of 2 files", shell_output("#{bin}/trail build #{testpath}")
  end
end
