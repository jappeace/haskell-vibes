-- | Per-turn state kept on tmpfs, shared by the hooks and the three Stop-gate
-- phases (dumbify, critique, rule review).
--
-- A "turn" is one user prompt and everything the agent does to satisfy it.
-- record-edit appends to the review stack during the turn; each Stop-gate phase
-- keeps its own done/round/editmark/approved flags here so it converges across
-- the turn's repeated Stops; reset wipes the whole directory when the next user
-- prompt arrives. All of it lives under @$TMPDIR/claude-turn-state/<session>@.
module Claude.Gate.TurnState
  ( TurnPaths(..)
  , turnPaths
  , sanitiseSession
  , ensureStateDir
  , resetState
  , claimReviewStack
  , flagExists
  , writeFlag
  , readCounter
  , writeCounter
  , readMark
  , stackLineCount
  , fileNonEmpty
  , removeIfExists
  ) where

import Control.Monad (when)

import Data.ByteString.Char8 qualified as ByteString
import Data.Char (isAsciiLower, isAsciiUpper, isDigit, isSpace)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Text qualified as Text
import System.Directory (createDirectoryIfMissing, doesFileExist, getFileSize, removeFile, removePathForcibly, renameFile)
import System.Environment (lookupEnv)
import System.FilePath ((</>))
import Text.Read (readMaybe)

-- | Every state file for one session. Grouping them keeps the on-disk layout in
-- one place rather than recomputed in each phase. The @*Done@ flags stop a phase
-- re-running once it has converged this turn; @*Round@ counts rounds against the
-- per-phase cap; @*Editmark@ records the edit-stack size a block was based on so
-- the next Stop can tell a fix (stack grew) from a shrug (unchanged); @*Approved@
-- records a clean pass for the end-of-gate notice; @*Broke@ is the once-per-turn
-- guard for surfacing an infrastructure failure.
data TurnPaths = TurnPaths
  { stateDir :: FilePath
  , reviewStack :: FilePath
  , claimedStack :: FilePath
  , dumbifyDone :: FilePath
  , dumbifyRound :: FilePath
  , dumbifyEditmark :: FilePath
  , dumbifyApproved :: FilePath
  , dumbifyBroke :: FilePath
  , critiqueDone :: FilePath
  , critiqueRound :: FilePath
  , critiquePrev :: FilePath
  , critiqueEditmark :: FilePath
  , critiqueApproved :: FilePath
  , critiqueBroke :: FilePath
  , reviewApproved :: FilePath
  , reviewBroke :: FilePath
  , hoursWarned :: FilePath
    -- ^ Once-per-turn guard for the working-hours warning
    -- ("Claude.Gate.WorkingHours"): present after the warning was
    -- injected this turn, wiped with the rest on the next prompt.
  }

-- | Resolve the state paths for a session id, reading TMPDIR the same way the
-- shell hooks did (defaulting to /tmp).
turnPaths :: Text -> IO TurnPaths
turnPaths session = do
  tmp <- fromMaybe "/tmp" <$> lookupEnv "TMPDIR"
  let dir = tmp </> "claude-turn-state" </> Text.unpack (sanitiseSession session)
  pure
    TurnPaths
      { stateDir = dir
      , reviewStack = dir </> "edits.jsonl"
      , claimedStack = dir </> "edits.processing"
      , dumbifyDone = dir </> "dumbify-done"
      , dumbifyRound = dir </> "dumbify-round"
      , dumbifyEditmark = dir </> "dumbify-editmark"
      , dumbifyApproved = dir </> "dumbify-approved"
      , dumbifyBroke = dir </> "dumbify-broke"
      , critiqueDone = dir </> "critique-done"
      , critiqueRound = dir </> "critique-round"
      , critiquePrev = dir </> "critique-prev"
      , critiqueEditmark = dir </> "critique-editmark"
      , critiqueApproved = dir </> "critique-approved"
      , critiqueBroke = dir </> "critique-broke"
      , reviewApproved = dir </> "review-approved"
      , reviewBroke = dir </> "review-broke"
      , hoursWarned = dir </> "hours-warned"
      }

-- | Make the session id safe to use as a single path component by replacing any
-- character outside @[A-Za-z0-9_.-]@ with an underscore, matching the shell
-- @tr -c@ the hooks used.
sanitiseSession :: Text -> Text
sanitiseSession = Text.map keepOrUnderscore

keepOrUnderscore :: Char -> Char
keepOrUnderscore character
  | isSafe character = character
  | otherwise = '_'

isSafe :: Char -> Bool
isSafe character =
  isAsciiUpper character
    || isAsciiLower character
    || isDigit character
    || character == '_'
    || character == '.'
    || character == '-'

ensureStateDir :: TurnPaths -> IO ()
ensureStateDir paths = createDirectoryIfMissing True (stateDir paths)

-- | Wipe a session's state directory. Used by the UserPromptSubmit reset so the
-- previous turn's review stack and per-phase flags do not leak into the next.
resetState :: TurnPaths -> IO ()
resetState paths = removePathForcibly (stateDir paths)

-- | Atomically claim the review stack: rename edits.jsonl to edits.processing
-- so any edit recorded after this point lands on a fresh stack and is reviewed
-- on the next Stop rather than lost. Returns whether there was a stack to claim.
claimReviewStack :: TurnPaths -> IO Bool
claimReviewStack paths = do
  hasStack <- doesFileExist (reviewStack paths)
  if hasStack
    then renameFile (reviewStack paths) (claimedStack paths) >> pure True
    else pure False

-- | Whether a marker/flag file is present.
flagExists :: FilePath -> IO Bool
flagExists = doesFileExist

-- | Create an empty marker file (the shell @: > flag@).
writeFlag :: FilePath -> IO ()
writeFlag path = writeFile path ""

-- | Read an integer counter file, defaulting to 0 when absent or unparseable.
readCounter :: FilePath -> IO Int
readCounter path = do
  present <- doesFileExist path
  if not present
    then pure 0
    else do
      -- Strict read. A lazy 'Prelude.readFile' leaves the handle open until the
      -- contents thunk is forced, and the very next 'writeCounter' (which is
      -- 'withFile' in WriteMode) on the same path then dies with "resource busy
      -- (file is locked)" under GHC's single-writer file locking. Reading
      -- strictly closes the handle before we return. See handleChallenge, which
      -- reads then immediately rewrites critique-round.
      contents <- ByteString.readFile path
      pure (fromMaybe 0 (readMaybe (filter (not . isSpace) (ByteString.unpack contents))))

writeCounter :: FilePath -> Int -> IO ()
writeCounter path n = writeFile path (show n)

-- | Read an editmark, distinguishing "no mark written yet" (Nothing) from a
-- recorded count: a phase only treats an unchanged stack as a shrug when it
-- actually wrote a mark on a previous Stop this turn.
readMark :: FilePath -> IO (Maybe Int)
readMark path = do
  present <- doesFileExist path
  if present then Just <$> readCounter path else pure Nothing

-- | The number of recorded edits, i.e. non-empty lines on a stack file. Used as
-- the convergence signal: it grows when the worker makes new edits.
stackLineCount :: FilePath -> IO Int
stackLineCount path = do
  present <- doesFileExist path
  if not present
    then pure 0
    else do
      contents <- ByteString.readFile path
      pure (length (filter (not . ByteString.null) (ByteString.lines contents)))

-- | Whether a file exists and has non-zero size.
fileNonEmpty :: FilePath -> IO Bool
fileNonEmpty path = do
  present <- doesFileExist path
  if present then (> 0) <$> getFileSize path else pure False

-- | Remove a file if it is there; absence is fine.
removeIfExists :: FilePath -> IO ()
removeIfExists path = do
  present <- doesFileExist path
  when present (removeFile path)
