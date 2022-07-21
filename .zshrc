# zplugが無ければgitからclone
if [[ ! -d ~/.zplug ]];then
  git clone https://github.com/zplug/zplug ~/.zplug
fi
# autocompleteの設定　さほど便利にもならなかったのでオフ 
source ~/.zplug/repos/zsh-autocomplete/zsh-autocomplete.plugin.zsh
zstyle ':autocomplete:*' insert-unambiguous yes
zstyle ':autocomplete:*' fzf-completion yes


# zplugを使う
source ~/.zplug/init.zsh

# ここに使いたいプラグインを書いておく
# zplug "ユーザー名/リポジトリ名", タグ
# 自分自身をプラグインとして管理
# zplug "zplug/zplug", hook-build:'zplug --self-manage'
# zplug "zsh-users/zsh-completions"
# zplug "yous/lime"
# zplug "mafredri/zsh-async"
# zplug "sindresorhus/pure"
# zplug mafredri/zsh-async, from:github
# zplug sindresorhus/pure, use:pure.zsh, from:github, as:theme


# zplug "chrissicool/zsh-256color"
# 入力途中に候補をうっすら表示
# zplug "zsh-users/zsh-autosuggestions"
# コマンドを種類ごとに色付け
# zplug "zsh-users/zsh-syntax-highlighting", defer:2
# ヒストリの補完を強化する
# zplug "zsh-users/zsh-history-substring-search", defer:3

# コマンドをリンクして、PATH に追加し、プラグインは読み込む
zplug load –-verbose

# インストールしてないプラグインはインストール
if ! zplug check --verbose; then
    printf "Install? [y/N]: "
    if read -q; then
        echo; zplug install
    fi
fi

export LANG=ja_JP.UTF-8
HISTFILE=$HOME/.zsh_history
HISTSIZE=1000000
SAVEHIST=1000000
setopt hist_ignore_dups
setopt share_history
setopt hist_expand


export PS1="%~ "
# PROMPT="%~ $(__git_ps1 "%s")"
# setopt auto_list
# setopt auto_menu
# setopt auto_pushd
# zstyle ':completion:*:default' menu select=1
# export LS_COLORS='di=34:ln=35:so=32:pi=33:ex=31:bd=46;34:cd=43;34:su=41;30:sg=46;30:tw=42;30:ow=43;30'
# zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
fpath=(~/.zsh/completion $fpath)
zstyle ':completion:*:*:docker:*' option-stacking yes
zstyle ':completion:*:*:docker-*:*' option-stacking yes
# autoload -U compinit && compinit
# autoload -U promptinit; promptinit
# prompt pure
alias ...='cd ../..'

export PATH="$HOME/.poetry/bin:$PATH"

# pyenv init --path

# eval "$(pyenv init -)"

