# Bash commands
- `nix-shell -p ghc cabal-install --run "cabal build"`: Run the typechecker
- `nix-shell -p ghc cabal-install --run "cabal test"`: Run the test suite.
- To search for Haskell modules, types, or documentation, ALWAYS query the Hoogle web API using curl:
  `curl -s "https://hoogle.haskell.org/?mode=json&hoogle=YOUR_QUERY"`
- To read actual Hackage documentation, NEVER fetch raw HTML. Instead, use `w3m` via nix-shell to dump the clean text of the page:
  `nix-shell -p w3m --run "w3m -dump https://hackage.haskell.org/package/<package_name>"`
- To read a specific module's documentation on Hackage:
  `nix-shell -p w3m --run "w3m -dump https://hackage.haskell.org/package/<package_name>/docs/<Module-Name-With-Dashes>.html"`

# Workflow
- Be sure to run `nix-shell -p ghc cabal-install --run "cabal build"` when you're done making a series of code changes. Do not finish the task until the typechecker passes.
- Everytime you try to solve a compile error keep a counter, if the counter exceeds 5, stop, write out all attempts as a patch into a file called "compile-errors-halp.md" with the associated compile errors. Also explain why you tried it like that.
- At the end of a task and it typechecks, run `nix-shell -p ghc cabal-install --run "cabal test"` to make sure no 
  known regressions occurred.
- Once completed write a summery of the work with date and time to tasks.md. Every task should have it's own section.
