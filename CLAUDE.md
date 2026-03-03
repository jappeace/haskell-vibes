# Bash commands
- if there is no shell.nix, use `nix-shell -p ghc cabal-install` for haskell projects.
- if there is a shell.nix use `nix-shell`, but assume we use nix to get the cached dependencies.
- cabal update: Get latest packages, (undesired with nix based dependencies)
- cabal build: Run the typechecker
- cabal test: Run the test suite.
- To search for Haskell modules, types, or documentation, ALWAYS query the Hoogle web API using curl:
  `curl -s "https://hoogle.haskell.org/?mode=json&hoogle=YOUR_QUERY"`
- To read actual Hackage documentation, NEVER fetch raw HTML. Instead, use `w3m` via nix-shell to dump the clean text of the page:
  `nix-shell -p w3m --run "w3m -dump https://hackage.haskell.org/package/<package_name>"`
- To read a specific module's documentation on Hackage:
  `nix-shell -p w3m --run "w3m -dump https://hackage.haskell.org/package/<package_name>/docs/<Module-Name-With-Dashes>.html"`

# Workflow
- For a task create a new branch to work from.
- Be sure to run `cabal build` when you're done making a series of code changes, this can be intermediately run as well to ensure things are consistent. Do not finish the task until the typechecker passes.
- Repair all newly introduced warnings.
- At the end of a task and it typechecks, run `cabal test` to make sure no 
  known regressions occurred.
- For new features think of a happy path test and implement that as well, make sure it passes.
- Commit your changes, message should contain the summary of the done work, the first line should be synopsis of that.
- Push the changes, don't force push.
- Once completed write a summery of the work with date and time to tasks.md. Every task should have it's own section.
