class Intelephense < Formula
  desc "PHP language server (LSP) — installed with a private, vendored Node.js runtime"
  homepage "https://intelephense.com"
  url "https://registry.npmjs.org/intelephense/-/intelephense-1.18.5.tgz"
  sha256 "9c945dfeec2f030108da34c9c1d9e6c692cfd5d0cf5933f13b8651f7b9f943f1"
  # Intelephense is proprietary freemium software (docs: https://github.com/bmewburn/intelephense-docs).
  license :cannot_represent

  livecheck do
    url "https://registry.npmjs.org/intelephense"
    strategy :npm
  end

  # Vendored Node.js runtime. This formula intentionally does NOT `depends_on "node"` —
  # intelephense is installed and run only against this private copy, never against any
  # Node.js the user has on PATH (system, nvm, volta, etc).
  resource "node" do
    on_macos do
      on_arm do
        url "https://nodejs.org/dist/v26.13.0/node-v26.13.0-darwin-arm64.tar.gz"
        sha256 "d38bd5e5a2ddce6bbb5ce45e46e208337da4d51fffe611e567fd32073d6439f6"
      end
      on_intel do
        url "https://nodejs.org/dist/v26.13.0/node-v26.13.0-darwin-x64.tar.gz"
        sha256 "525c9b29bb0263d687de60a4cec0e2a6db876a8eb032369e5795eca71e7c358e"
      end
    end
  end

  def install
    node_dir = libexec/"node"
    resource("node").stage node_dir

    node = node_dir/"bin/node"
    npm_cli = node_dir/"lib/node_modules/npm/bin/npm-cli.js"

    # Some transitive npm dependencies (e.g. protobufjs) run their own `node scripts/...`
    # postinstall steps, which need a bare `node` resolvable on PATH. Prepend the vendored
    # runtime so that's still ONLY our private copy — never any `node` the caller might have.
    ENV.prepend_path "PATH", node_dir/"bin"
    system node, npm_cli, "install", "--production", "--no-audit", "--no-fund"

    libexec.install buildpath.children

    (bin/"intelephense").write <<~SH
      #!/bin/bash
      exec "#{node}" "#{libexec}/lib/intelephense.js" "$@"
    SH
  end

  test do
    require "open3"
    require "timeout"

    request = <<~JSON
      {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"processId":null,"rootUri":null,"capabilities":{}}}
    JSON
    body = request.strip
    message = "Content-Length: #{body.bytesize}\r\n\r\n#{body}"

    output = +""
    Open3.popen3(bin/"intelephense", "--stdio") do |stdin, stdout, _stderr, wait_thr|
      stdin.write(message)
      stdin.flush

      # Don't close stdin: intelephense's LSP transport treats EOF on stdin as a shutdown
      # signal and exits before finishing the response. Instead, poll stdout until the
      # `initialize` result comes back (it includes "result", not just the startup
      # log notifications) or we time out.
      Timeout.timeout(30) do
        output << stdout.readpartial(4096) until output.include?("\"result\"")
      end
    ensure
      Process.kill("KILL", wait_thr.pid) rescue nil
    end

    assert_match "jsonrpc", output
    assert_match "\"result\"", output
  end
end
