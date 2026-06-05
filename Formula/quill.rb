class Quill < Formula
  desc "Canonical pandoc tooling for typeset research docs"
  homepage "https://github.com/DarkbyteAT/quill"
  url "https://github.com/DarkbyteAT/quill/archive/refs/tags/v0.2.5.tar.gz"
  sha256 "f199fc8261c822dd5cef4d3858af914901bf365db6e30c1171589efb8edffc01"
  version "0.2.5"
  license "MIT"
  head "https://github.com/DarkbyteAT/quill.git", branch: "main"

  depends_on "bash"
  depends_on "docker"

  def install
    libexec.install "Dockerfile", "render.sh", "defaults", "templates"
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
