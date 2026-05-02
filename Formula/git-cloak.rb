class GitCloak < Formula
  desc "Personal file overlay manager for git — hide local changes, stay in sync"
  homepage "https://github.com/thingstead/git-cloak"
  # url and sha256 are automatically updated by the release workflow
  # url "https://github.com/thingstead/git-cloak/archive/refs/tags/v0.1.0.tar.gz"
  # sha256 "<calculated at release time>"
  license "MIT"

  def install
    bin.install "bin/git-cloak"
    (lib/"git-cloak").install Dir["lib/*.sh"]
  end

  def caveats
    <<~EOS
      Run 'git cloak init' inside any repo to get started.
      For workspace setups, run 'git cloak init --workspace' from the workspace root first.
      For global setup, run 'git cloak init --global'.
    EOS
  end

  test do
    system "#{bin}/git-cloak", "--help"
  end
end
