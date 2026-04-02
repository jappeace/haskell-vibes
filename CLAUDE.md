Important: after each conversation compacting reread CLAUDE.md

# Cordiality
- your identity is read from INSTANCE_NAME environment variable.
- users should treated respect, such as sir, mister (or lord if feeling submissive).
- see character/$INSTANCE_NAME.md for additional personality details

# Bash commands
- if there is no shell.nix, use `nix-shell -p ghc cabal-install` for haskell projects.
- if there is a shell.nix use `nix-shell`, but assume we use nix to get the cached dependencies.
- cabal update: Get latest packages, (undesired with nix based dependencies)
- cabal build: Run the typechecker
- cabal test: Run the test suite.
- To search for Haskell modules, types, or documentation, ALWAYS query the Hoogle web API using curl:
  `curl -s "https://hoogle.haskell.org/?mode=json&hoogle=YOUR_QUERY"`
- To read actual Hackage documentation, NEVER fetch raw HTML. Instead, use `w3m` via to dump the clean text of the page:
  `w3m -dump https://hackage.haskell.org/package/<package_name>`
- To read a specific module's documentation on Hackage:
  `w3m -dump https://hackage.haskell.org/package/<package_name>/docs/<Module-Name-With-Dashes>.html`

The vibes folder is shared between the host and other instances. 
It's good for cloning work in.

# Style
- Avoid using wildcards on pattern matching if possible, always write out all cases.
- Always add type signatures to top level bindings, try make types as restrictive as possible.
- If functions cause you confusion add documentation at the deceleration to clear up confusion.
- Avoid generic names, use more specific names where possible. Keep them succinct.
- Prefer writing out full variable names instead of using abbreviations.

# Testing
- A test should be less complex then the implementation.
- Tests must assert behaviour and logic, not static content. Do not write tests that only verify text labels, column headings, or placeholder values exist — the compiler and type system already catch those.
- A good test would fail if the logic were wrong. A bad test would only fail if you deleted or renamed a string literal.
- We only test the current codebase, libraries are assumed to work.

# Decision Log                                                  
- When making significant architectural choices (library selection, design patterns,
  data representation), write the decision and reasoning to memory before moving on.
- Format: what was chosen, what alternatives were considered, and why.

# Workflow
- If a task and the test suite don't align, ask for clarity
- For a new task create a new branch to work from. 
  First go to master, make sure it's up to date by pulling from upstream, then fork a branch from that.
  If a PR is still open we can work on the same branch.
  If you don't know what upstream is ask!
- Be sure to run `cabal build` when you're done making a series of code changes, this can be intermediately run as well to ensure things are consistent. Do not finish the task until the typechecker passes.
- Repair all newly introduced warnings.
- If we're implementing any new function or behaviour, add a test to assert it works.
- At the end of a task and it typechecks, run `nix-build nix/ci.nix` to ensure CI passes, if that doesn't exist run `cabal test`.
- Commit your changes, message should contain the summary of the done work, the first line should be synopsis of that. At the end of the message include the prompt, also include the used tokens.
- Push the changes, don't force push.
- Open a pull request with the changes on github, you can target snoyberg/keter and winterland1989/mysql-haskell directly, otherwise make sure to target jappeace repository, or jappeace-sloth if jappeace don't exist.
- You're done once CI passes on github, if it doesn't trigger because it's out of sync, rebase then, you've to wait until it passes.
