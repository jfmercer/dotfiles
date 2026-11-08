-- Rex config migrated from tmux (~/.tmux.conf), Herdr (~/.config/herdr/config.toml)
-- and Ghostty (~/.config/ghostty/config). Prefix: ctrl+a.

-- Pass the prefix through to programs that use ctrl+a themselves
rex.bind("ctrl+a>ctrl+a", "pane.send_key", { key = "ctrl+a" })

-- tmux ~/.tmux.conf:13 bind r source-file ...
rex.bind("ctrl+a>r", "client.config.reload")
-- tmux ~/.tmux.conf:17 bind a send-prefix
rex.bind("ctrl+a>a", "pane.send_key", { key = "ctrl+a" })

-- Herdr ~/.config/herdr/config.toml:43,45 (won over tmux :21,:22)
rex.bind("ctrl+a>shift+\\", "pane.split", { direction = "right" })
rex.bind("ctrl+a>-", "pane.split", { direction = "down" })

-- Herdr ~/.config/herdr/config.toml:47-50 (won over tmux :25-:28)
rex.bind("ctrl+a>h", "pane.focus", { direction = "left" })
rex.bind("ctrl+a>j", "pane.focus", { direction = "down" })
rex.bind("ctrl+a>k", "pane.focus", { direction = "up" })
rex.bind("ctrl+a>l", "pane.focus", { direction = "right" })

-- tmux ~/.tmux.conf:31-34 bind -r H/J/K/L resize-pane 5
rex.bind("ctrl+a>shift+h", "pane.resize", { amount = 5, direction = "left" })
rex.bind("ctrl+a>shift+j", "pane.resize", { amount = 5, direction = "down" })
rex.bind("ctrl+a>shift+k", "pane.resize", { amount = 5, direction = "up" })
rex.bind("ctrl+a>shift+l", "pane.resize", { amount = 5, direction = "right" })

-- Repeat mode for tmux's bind -r bindings: ctrl+a ctrl+r enters, enter/escape leaves
rex.mode("repeat", { exclusive = true })
rex.bind("ctrl+a>ctrl+r", "client.mode.enter", { name = "repeat" })
rex.bind("repeat/enter", "client.mode.exit")
rex.bind("repeat/escape", "client.mode.exit")
rex.bind("repeat/shift+h", "pane.resize", { amount = 5, direction = "left" })
rex.bind("repeat/shift+j", "pane.resize", { amount = 5, direction = "down" })
rex.bind("repeat/shift+k", "pane.resize", { amount = 5, direction = "up" })
rex.bind("repeat/shift+l", "pane.resize", { amount = 5, direction = "right" })

-- tmux ~/.tmux.conf:103-104 bind Up/Down resize-pane -Z
rex.bind("ctrl+a>up", "pane.zoom")
rex.bind("ctrl+a>down", "pane.zoom")

-- tmux ~/.tmux.conf:128 bind C-l send-keys 'C-l'
rex.bind("ctrl+a>ctrl+l", "pane.send_key", { key = "ctrl+l" })

-- Added by request: cmd+l clears the terminal
rex.bind("cmd+l", "com.superlogical.terminal.clear")
