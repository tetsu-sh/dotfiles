export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

export RBENV_ROOT="$HOME/.rbenv"
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"
export PATH=$HOME/.nodebrew/current/bin:$PATH
export PATH=$HOME/Developer/flutter/bin:$PATH
export PATH="/usr/local/opt/openssl@1.1/bin:$PATH"

export PATH="$HOME/.poetry/bin:$PATH"
. "$HOME/.cargo/env"
