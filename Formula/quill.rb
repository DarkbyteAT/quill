class Quill < Formula
  desc "Canonical pandoc tooling for typeset research docs"
  homepage "https://github.com/DarkbyteAT/quill"
  url "https://github.com/DarkbyteAT/quill/archive/refs/tags/v0.2.2.tar.gz"
  sha256 "c863b0d9a69bd5aa769c3ccd10d050cc8007209b085958870e7ea61a3049f115"
  version "0.2.2"
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
