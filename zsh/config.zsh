# ===== Basics
setopt NO_BEEP # don't beep on error
setopt INTERACTIVE_COMMENTS # Allow comments even in interactive shells (especially for Muness)

# ===== Changing Directories
setopt AUTO_CD # If you type foo, and it isn't a command, and it is a directory in your cdpath, go there
setopt CDABLEVARS # if argument to cd is the name of a parameter whose value is a valid directory, it will become the current directory
setopt PUSHD_IGNORE_DUPS # don't push multiple copies of the same directory onto the directory stack

# ===== Expansion and Globbing
setopt EXTENDED_GLOB # treat #, ~, and ^ as part of patterns for filename generation

# ===== History
HISTFILE=~/.zsh_history
HISTSIZE=1000000
SAVEHIST=1000000

setopt APPEND_HISTORY # Allow multiple terminal sessions to all append to one zsh command history
setopt EXTENDED_HISTORY # add timestamps to history
setopt INC_APPEND_HISTORY # Add commands as they are typed and share across sessions
setopt HIST_EXPIRE_DUPS_FIRST # when trimming history, lose oldest duplicates first
setopt HIST_IGNORE_ALL_DUPS # don't record dupes in history
setopt HIST_IGNORE_SPACE # remove command line from history list when first character on the line is a space
setopt HIST_FIND_NO_DUPS # When searching history don't display results already cycled through twice
setopt HIST_REDUCE_BLANKS # Remove extra blanks from each command line being added to history
setopt HIST_VERIFY # don't execute, just expand history
setopt SHARE_HISTORY # imports new commands and appends typed commands to history

# ===== Completion
setopt COMPLETE_IN_WORD # Allow completion from within a word/phrase
setopt NO_LIST_BEEP # do not beep on ambiguous completion
setopt ALWAYS_TO_END # When completing from the middle of a word, move the cursor to the end of the word
setopt AUTO_MENU # show completion menu on successive tab press. needs unsetop menu_complete to work
setopt AUTO_NAME_DIRS # any parameter that is set to the absolute name of a directory immediately becomes a name for that directory
# unsetopt MENU_COMPLETE # do not autoselect the first completion entry

# ===== Correction
setopt CORRECT # correct commands

# ===== Prompt
setopt PROMPT_SUBST # Enable parameter expansion, command substitution, and arithmetic expansion in the prompt

# ===== Scripts and Functions
setopt MULTIOS # perform implicit tees or cats when multiple redirections are attempted
setopt NO_BG_NICE # don't nice (run at lower priority) background tasks
setopt NO_HUP # don't end the HUP (hangup) signal to running jobs when the shell exits
setopt LOCAL_OPTIONS # allow functions to have local options
setopt LOCAL_TRAPS # allow functions to have local traps
setopt RM_STAR_SILENT # do not query user when 'rm *' is executed

# ===== Keybindings
bindkey "$terminfo[kcuu1]" history-substring-search-up # Up Arrow?
bindkey "$terminfo[kcud1]" history-substring-search-down # Down Arrow?
bindkey "$terminfo[cuu1]" history-substring-search-up
bindkey "$terminfo[cud1]" history-substring-search-down
bindkey '^[^[[D' backward-word # F4
bindkey '^[^[[C' forward-word # F3
bindkey '^[[5D' beginning-of-line
bindkey '^[[5C' end-of-line
bindkey '^[[3~' delete-char # Delete Key
bindkey '^?' backward-delete-char # Backspace
