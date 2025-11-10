# Setup

```
# helper for dev tools to bashrc
echo '
# Run helper tools for the cmd app
function cmd {
  "$(git rev-parse --show-toplevel)/cmd.sh" "$@"
}' >> ~/.zshrc
source ~/.zshrc

# install brew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew install nvm
# complete nvm installation as per instructions

(cd ./local-server && nvm use)
cmd install:swiftformat

brew install jc
brew install jq
brew install shfmt

# Enable Corepack for Yarn (uses version from package.json)
corepack enable

# Ruby version management
brew install chruby ruby-install
ruby-install ruby
echo '
# Ruby
source /opt/homebrew/opt/chruby/share/chruby/chruby.sh
source /opt/homebrew/opt/chruby/share/chruby/auto.sh' >>  ~/.zshrc
source ~/.zshrc
gem install bundler && bundle install
```

## Architecture overview
command has a macOS app and a local node server:
- the macOS app handles all the UI/UX and intergration with Xcode.
- the local node server handles some business logic that leverages open source code written in typescript. Some examples include interfacing with external providers, defining some agentic tools etc. It's not worth re-building the wheel in Swift for the sake of it. The installation of node and the local server is managed by the macOS app.

## App developement
See the [app's development guide](./app/contributing.md) for more details.

## Proxying network traffic
`cmd` sends requests from both the macOS app and the node process it launches. Requests from the macOS app can be proxied in a standard way by any proxy tool. Requests from the node process (which include all chat completion) require some specific setup:
- Set env variables for the provider you want to proxy. For instance:
```bash
# in ~/.zshrc
export ANTHROPIC_LOCAL_SERVER_PROXY="http://localhost:10001/v1"
export OPEN_ROUTER_LOCAL_SERVER_PROXY="http://localhost:10002/api/v1"
export OPENAI_LOCAL_SERVER_PROXY="http://localhost:10003/v1"
export GROQ_LOCAL_SERVER_PROXY="http://localhost:10004/openai/v1"
export GEMINI_LOCAL_SERVER_PROXY="http://localhost:10005/v1beta"
export GITHUB_COPILOT_PROXY="http://localhost:9090"

# Claude Code (with Proxyman):
cat > "$HOME/.claude/start_with_proxy.sh" << 'EOF'
#!/bin/zsh

set -a && \
source "$HOME/Library/Application Support/com.proxyman.NSProxy/app-data/proxyman_env_automatic_setup.sh" &>/dev/null && \
set +a;
claude "$@"
EOF
chmod +x "$HOME/.claude/start_with_proxy.sh"
export CLAUDE_CODE_PROXY="$HOME/.claude/start_with_proxy.sh"

# If you use Proxyman, this will allow Claude Code to be proxied (this works for any node.js program)


# Codex (with Proxyman)
export CODEX_PROXY="http://localhost:9090"
# In Proxyman, save the SSL certificate (Certificate > Export > Root Certificate as pem)
export NODE_EXTRA_CA_CERTS="/path/to/saved/ssl/certificate/proxyman.pem"
export NODE_TLS_REJECT_UNAUTHORIZED=0
```
- Set a reverse proxy in your proxy tool. For instance in Proxyman (Tools > Reverse Proxy...):
<img height="width: 100%" src="./docs/assets/proxy-setup.png"/>
