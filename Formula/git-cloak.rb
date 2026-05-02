class GitCloak < Formula
  desc "Personal file overlay manager for git — hide local changes, stay in sync"
  homepage "https://github.com/jumpmind/git-cloak"
  # url and sha256 filled in at release time:
  # url "https://github.com/jumpmind/git-cloak/archive/refs/tags/v0.1.0.tar.gz"
  # sha256 "<sha256>"
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
