# https://yarnpkg.com

if (( $+commands[yarn] ))
then
  # warning `yarn global bin` is slow (0.3 sec)
  # so this path is set "manually"
  #
  # This will break if `n` is replaced with `nvm`
  export PATH="$PATH:$HOME/.n/bin"
fi
