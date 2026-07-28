# The adversarial values that bin/secret's shell_quote must survive.
#
# This list is the point of the whole suite. `eval "$(secret env)"` runs in every
# interactive shell, so a value that escapes its quoting is not a formatting bug,
# it is code execution at shell startup. Each entry below breaks a different naive
# implementation:
#
#   it's        the case `sed "s/'/\\'/g"` gets wrong
#   "quoted"    double quotes must pass through untouched
#   $HOME       must NOT expand
#   `id`        backtick substitution must NOT run
#   $(id)       modern substitution must NOT run
#   a\b         a backslash is literal inside single quotes; must stay one char
#   *           must NOT glob
#   ;rm -rf /   a command separator must stay inert
#   '           a lone quote -- the degenerate case
#   ''          an empty pair of quotes read as literal text
#   \'          backslash immediately before the quote
#   embedded \n survives base64 + eval as one logical assignment
#
# Bash arrays cannot be exported, so this is a function that populates a named
# global rather than a plain assignment.
load_adversarial_values() {
    ADVERSARIAL=(
        "it's"
        '"quoted"'
        '$HOME'
        '`id`'
        '$(id)'
        'a\b'
        '*'
        ';rm -rf /'
        "'"
        "''"
        "\\'"
        'plain-token-1234'
        "$(printf 'line one\nline two')"
    )
}
