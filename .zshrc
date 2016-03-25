# 色を使えるようにする
autoload -Uz colors
colors
export CLICOLOR=1
eval $(/usr/local/bin/gdircolors ~/Developer/dircolors-solarized/dircolors.ansi-light)
export LSCOLORS=ExFxBxDxCxegedabagacad
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# 文字コード
export LANG=ja_JP.UTF-8

# 自動補完を有効に
autoload -U compinit; compinit

# 補完候補が複数あるときに自動的に一覧表示
setopt auto_menu

# ディレクトリ名だけ入力すれば、そのディレクトリに cd してくれる
setopt auto_cd

# cd したら自動的に pushd，重複したディレクトリを追加しない
setopt auto_pushd
setopt pushd_ignore_dups

# 日本語ファイル名を表示可能にする
setopt print_eight_bit

# 同時に起動した zsh 間でヒストリを共有
setopt share_history

# 入力したコマンドが既に履歴にある場合、履歴から古い方のコマンドを削除
setopt hist_ignore_all_dups

# エイリアス
alias ...='cd ../..'
alias ....='cd ../../..'
alias ls='/usr/local/bin/gls --color=auto'
alias ll='ls -al'
alias mv='mv -i'
alias cp='cp -i'
alias brew="env PATH=${PATH/\/usr\/local\/\opt\/llvm\/bin:?/} brew"

# プロンプト
autoload -Uz vcs_info
zstyle ':vcs_info:*' enable git svn
zstyle ':vcs_info:git:*:-all-' command /usr/bin/git
zstyle ':vcs_info:*' max-exports 6 # formatに入る変数の最大数
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' formats '%b@%r' '%c' '%u'
zstyle ':vcs_info:git:*' actionformats '%b @ %r|%a' '%c' '%u'
setopt prompt_subst
function vcs_echo {
	local st branch color
	STY= LANG=en_US.UTF-8 vcs_info
	st=`git status 2> /dev/null`
	if [[ -z "$st" ]]; then return; fi
	branch="$vcs_info_msg_0_"
	if   [[ -n "$vcs_info_msg_1_" ]]; then color=${fg[green]} #staged
	elif [[ -n "$vcs_info_msg_2_" ]]; then color=${fg[red]} #unstaged
	elif [[ -n `echo "$st" | grep "^Untracked"` ]]; then color=${fg[blue]} # untracked
	else color=${fg[cyan]}
	fi
	echo "%{$color%}(%{$branch%})%{$reset_color%}" | sed -e s/@/"%F{yellow}@%f%{$color%}"/
}

DEFAULT='$'
ERROR='%F{red}$%f'

DEFAULT=$'\U1F34E \U1F414 ' # りんごとにわとり
ERROR=$'\U1F34E \U1F363 ' # りんごとsushi 

PROMPT=$'
%F{green}[%~]%f `vcs_echo`
%(?.${DEFAULT}.${ERROR}) '

# memo
function memo(){
  memotxt=''
  for str in $@
  do
  memotxt="${memotxt} ${str}"
  done
}
RPROMPT='${memotxt}'

# もしかして
setopt correct
SPROMPT="%{$fg[blue]%}もしかして: %B%r%b ${reset_color} (y, n, a, e)-> "


# ビープ音を鳴らさない
setopt nobeep
setopt no_list_beep

# Homebrew's sbin
export PATH="$PATH:/usr/local/sbin"

# Android SDK
export PATH="$PATH:$HOME/Developer/android-sdk/platform-tools:$HOME/Developer/android-sdk/tools"

# anyenv
if [ -d $HOME/.anyenv ] ; then
    export PATH="$HOME/.anyenv/bin:$PATH"
    eval "$(anyenv init -)"
    # tmux対応
    for D in `\ls $HOME/.anyenv/envs`
    do
        export PATH="$HOME/.anyenv/envs/$D/shims:$PATH"
    done
fi
# percol の設定
# {{{
# # cd 履歴を記録
typeset -U chpwd_functions
CD_HISTORY_FILE=${HOME}/.cd_history_file # cd 履歴の記録先ファイル
function chpwd_record_history() {
    echo $PWD >> ${CD_HISTORY_FILE}
}
chpwd_functions=($chpwd_functions chpwd_record_history)
# percol を使って cd 履歴の中からディレクトリを選択
# 過去の訪問回数が多いほど選択候補の上に来る
function percol_get_destination_from_history() {
    sort ${CD_HISTORY_FILE} | uniq -c | sort -r | \
        sed -e 's/^[ ]*[0-9]*[ ]*//' | \
        sed -e s"/^${HOME//\//\\/}/~/" | \
        percol | xargs echo
}

# percol を使って cd 履歴の中からディレクトリを選択し cd するウィジェット
function percol_cd_history() {
    local destination=$(percol_get_destination_from_history)
    [ -n $destination ] && cd ${destination/#\~/${HOME}}
    zle reset-prompt
}
zle -N percol_cd_history

# percol を使って cd 履歴の中からディレクトリを選択し，現在のカーソル位置に挿入するウィジェット
function percol_insert_history() {
    local destination=$(percol_get_destination_from_history)
    if [ $? -eq 0 ]; then
        local new_left="${LBUFFER} ${destination} "
        BUFFER=${new_left}${RBUFFER}
        CURSOR=${#new_left}
    fi
    zle reset-prompt
}
zle -N percol_insert_history
# }}}

# C-x ; でディレクトリに cd
# C-x i でディレクトリを挿入
bindkey '^x;' percol_cd_history
bindkey '^xi' percol_insert_history

# ls, cd, rm コマンドの履歴を保存しない
zshaddhistory(){
    local line=${1%%$'\n'}
    local cmd=${line%% *}

    [[ ${cmd} != (ls)
    && ${cmd} != (cd)
    && ${cmd} != (rm)
    ]]
}

# cd したら ls して1個前のディレクトリとカレントディレクトリをタブタイトルにする
function chpwd() { ls; echo -ne "\033]0;$(pwd | rev | awk -F \/ '{print "/"$1"/"$2}'| rev)\007"}
chpwd

# tmux と連携
function is_exists() { type "$1" >/dev/null 2>&1; return $?; }
function is_osx() { [[ $OSTYPE == darwin* ]]; }
function is_screen_running() { [ ! -z "$STY" ]; }
function is_tmux_runnning() { [ ! -z "$TMUX" ]; }
function is_screen_or_tmux_running() { is_screen_running || is_tmux_runnning; }
function shell_has_started_interactively() { [ ! -z "$PS1" ]; }
function is_ssh_running() { [ ! -z "$SSH_CONECTION" ]; }

function tmux_automatically_attach_session()
{
    if is_screen_or_tmux_running; then
        ! is_exists 'tmux' && return 1

        if is_tmux_runnning; then
            echo "${fg_bold[red]} tmux launched!! :)  ${reset_color}"
        elif is_screen_running; then
            echo "This is on screen."
        fi
    else
        if shell_has_started_interactively && ! is_ssh_running; then
            if ! is_exists 'tmux'; then
                echo 'Error: tmux command not found' 2>&1
                return 1
            fi

            if tmux has-session >/dev/null 2>&1 && tmux list-sessions | grep -qE '.*]$'; then
                # 存在するセッションを detach
                tmux list-sessions
                echo -n "Tmux: attach? (y/N/num) "
                read
                if [[ "$REPLY" =~ ^[Yy]$ ]] || [[ "$REPLY" == '' ]]; then
                    tmux attach-session
                    if [ $? -eq 0 ]; then
                        echo "$(tmux -V) attached session"
                        return 0
                    fi
                elif [[ "$REPLY" =~ ^[0-9]+$ ]]; then
                    tmux attach -t "$REPLY"
                    if [ $? -eq 0 ]; then
                        echo "$(tmux -V) attached session"
                        return 0
                    fi
                fi
            fi

            if is_osx && is_exists 'reattach-to-user-namespace'; then
                tmux_config=$(cat $HOME/.tmux.conf <(echo 'set-option -g default-command "reattach-to-user-namespace -l $SHELL"'))
                tmux -f <(echo "$tmux_config") new-session && echo "$(tmux -V) created new session supported OS X"
            else
                tmux new-session && echo "tmux created new session"
            fi
        fi
    fi
}
tmux_automatically_attach_session

# 何も入力していない状態で Enter を押すと ls と git status
function do_enter() {
    if [ -n "$BUFFER" ]; then
        zle accept-line
        return 0
    fi
    echo
    ls
    # ↓おすすめ
    # ls_abbrev
    if [ "$(git rev-parse --is-inside-work-tree 2> /dev/null)" = 'true' ]; then
        echo
        echo -e "\e[0;33m--- git status ---\e[0m"
        git status -sb
    fi
    zle reset-prompt
    return 0
}
zle -N do_enter
bindkey '^M' do_enter
