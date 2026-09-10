-- | The Stop hook: the end-of-turn gate.
--
-- Before any phase, the working-hours check ("Claude.Gate.WorkingHours")
-- injects one warning per turn when the Stop fires outside CLAUDE.md's
-- rest windows; a plain clock check, no model involved.
--
-- Three phases run in order over the per-turn state, mirroring the shell gate:
--
--   Phase 0 (dumbify). A cheap canary checks the changed code is understandable,
--   and the larger model simplifies it if not. See "Claude.Gate.Dumbify".
--   Phase 1 (critique). An adversarial critic tries to prove the work wrong with
--   tests and sources. See "Claude.Gate.Critique". (This replaced the old verification
--   nudge.)
--   Phase A (rule review). The diffs are checked against the rules corpus. See
--   "Claude.Gate.RuleReview".
--
-- Each phase may block the Stop (emit a reason and exit); later phases only run
-- on a Stop that no earlier phase blocked. The phases converge across the turn's
-- repeated Stops via per-phase flags on tmpfs. When every phase that ran cleared
-- without blocking, a non-blocking "gate clear" notice names them.
module Claude.Gate.StopGate
  ( runStopGate
  ) where

import Control.Monad (unless)
import Data.Maybe (catMaybes)
import Data.Text (Text)
import Data.Text qualified as Text
import Claude.Gate.Critique (runCritique)
import Claude.Gate.Dumbify (runDumbify)
import Claude.Gate.HookProtocol (HookEvent (sessionId, transcriptPath), emitSystemMessage, readHookEvent)
import Claude.Gate.RuleReview (runRuleReview)
import Claude.Gate.WorkingHours (runWorkingHours)
import Claude.Gate.TurnState
  ( TurnPaths (critiqueApproved, dumbifyApproved, reviewApproved)
  , ensureStateDir
  , flagExists
  , turnPaths
  )

-- | Entry point for the @stop-gate@ subcommand.
runStopGate :: IO ()
runStopGate = do
  event <- readHookEvent
  paths <- turnPaths (sessionId event)
  ensureStateDir paths
  runWorkingHours paths
  runDumbify (sessionId event) paths
  runCritique (sessionId event) (transcriptPath event) paths
  runRuleReview (sessionId event) paths
  emitGateClear paths

-- | Every phase that ran this turn concluded without blocking (a block would
-- have exited above). Emit one user-visible, non-blocking confirmation naming
-- the phases that ran and cleared, from their per-turn approved markers.
emitGateClear :: TurnPaths -> IO ()
emitGateClear paths = do
  cleared <- clearedPhases paths
  unless (null cleared) (emitSystemMessage ("gate clear:" <> Text.concat (map (" " <>) cleared)))

clearedPhases :: TurnPaths -> IO [Text]
clearedPhases paths =
  catMaybes
    <$> sequence
      [ namedIfPresent (dumbifyApproved paths) "dumbify"
      , namedIfPresent (critiqueApproved paths) "critique"
      , namedIfPresent (reviewApproved paths) "rules"
      ]

namedIfPresent :: FilePath -> Text -> IO (Maybe Text)
namedIfPresent path name = do
  present <- flagExists path
  pure (if present then Just name else Nothing)
