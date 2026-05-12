class GitShelf < Formula
  desc "Personal file overlay manager for git — shelf local changes across branch switches"
  homepage "https://github.com/jwill824/git-shelf"
  license "MIT"

  depends_on "go" => :build

  def install
    system "go", "build", *std_go_args(ldflags: "-s -w"), "./cmd/git-shelf"
  end

  def caveats
    <<~EOS
      Run 'git shelf init' inside any repo to get started.
    EOS
  end

  test do
    system "#{bin}/git-shelf", "--help"
  end
end
