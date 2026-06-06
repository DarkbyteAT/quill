class Quill < Formula
  desc "Canonical pandoc tooling for typeset research docs"
  homepage "https://github.com/DarkbyteAT/quill"
  url "https://github.com/DarkbyteAT/quill/archive/refs/tags/v0.3.1.tar.gz"
  sha256 "44dcb359584ad752ef1a02d036264a6c7586e51f47dfd638df3caa65bf9121eb"
  version "0.3.1"
  license "MIT"
  head "https://github.com/DarkbyteAT/quill.git", branch: "main"

  depends_on "bash"
  depends_on "docker"

  def install
    libexec.install "Dockerfile", "render.sh", "defaults", "templates", "filters"
    (bin/"quill").write <<~EOS
      #!/usr/bin/env bash
      exec "#{libexec}/render.sh" "$@"
    EOS
    chmod 0755, bin/"quill"
  end

  test do
    assert_match "pandoc", shell_output("#{bin}/quill --version")
  end
end
