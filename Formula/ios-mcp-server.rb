class IosMcpServer < Formula
  desc "MCP server for controlling iOS simulators and apps via XCUITest"
  homepage "https://github.com/lastlookdev/ios-mcp-server"
  url "https://github.com/lastlookdev/ios-mcp-server", tag: "0.3.0"
  license "MIT"

  depends_on xcode: ["15.0", :build]
  depends_on :macos

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/ios-mcp-server"
    # Install SPM resource bundle containing Runner.zip (must be next to binary for Bundle.module)
    bin.install ".build/release/ios-mcp-server_IOSMCPServer.bundle"
  end

  def post_install
    ohai "Run 'ios-mcp-server install' to start as a background service"
    ohai "Or run 'ios-mcp-server' to start in foreground"
  end

  def caveats
    <<~EOS
      To start the server as a background service and add to Claude Code:
        ios-mcp-server install

      To remove:
        ios-mcp-server uninstall

      To check status:
        ios-mcp-server status
    EOS
  end

  test do
    assert_match "Usage:", shell_output("#{bin}/ios-mcp-server help", 0)
  end
end
