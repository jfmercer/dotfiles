# These load in reverse order, from bottom to top
typeset paths
paths=($PWD/node_modules/bin
       $HOME/.n/bin
       $HOME/.yarn/bin)

for p in ${paths}
do
  export PATH=$p:$PATH
done

unset paths