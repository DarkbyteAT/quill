class Quill < Formula
  desc "Canonical pandoc tooling for typeset research docs"
  homepage "https://github.com/DarkbyteAT/quill"
  url "https://github.com/DarkbyteAT/quill/archive/refs/tags/v0.2.4.tar.gz"
  sha256 "6ec7c1150e96eef68204b9e692702fec49c3acf415fbc97e93c9f58fc9b7a0a4"
  version "0.2.4"
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
