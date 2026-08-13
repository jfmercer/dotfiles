# Deliberately no flags. bat injects its own (-R, plus -F/--quit-if-one-screen
# when paging is auto) only when the pager is `less` with NO arguments -- so
# the "-R" this used to carry was silently costing us -F. -R now comes from
# $LESS in dot_zshenv instead. Verified: `BAT_PAGER=less` and a bare
# `PAGER=less` produce identical argv, so this line is belt-and-braces.
export BAT_PAGER="less"
