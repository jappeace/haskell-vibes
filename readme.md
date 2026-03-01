# Haskell vibes
Experimenting with claude to do various refactor
style jobs in Haskell.

For example we're depending on a package
we no longer want to depend on (say basement), 
rewrite the functions from basement
to functions within base and ghc-prim.

Seems to work alright.

## Container
I do not actually trust these llm's,
but I"m not going to babysit their every
action, so I run them in a container.
