class Quill < Formula
  desc "Canonical pandoc tooling for typeset research docs"
  homepage "https://github.com/DarkbyteAT/quill"
  url "https://github.com/DarkbyteAT/quill/archive/refs/tags/v0.2.1.tar.gz"
  sha256 "99ee412d1435b5c696cddb9eb31c4b7f5cbf7efb0961168d90e68eae05c2252c"
  version "0.2.1"
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
