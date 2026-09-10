-- | The working-hours warning: the first thing the Stop gate does.
--
-- CLAUDE.md's rest rules (no work 22:45-07:00 NL, none on Sunday) are
-- enforced by the worker itself, and under heavy load that context gets
-- deprioritised: on 9 sep 2026 the worker sailed past bedtime without
-- ever checking a clock (Jappie: "to many diverging threads cause the
-- claude.md context to be deprioritized"). This phase is the dedicated
-- watcher he asked for on 10 sep, as a plain program rather than another
-- model: when the Stop fires outside working hours, the gate injects one
-- warning and the worker decides what to do with it (wrap up, refuse,
-- or apply the override rule from CLAUDE.md).
--
-- Decision: the Amsterdam clock is computed from the EU DST rule in
-- code instead of via @TZ=Europe/Amsterdam@. The containers ship no
-- zoneinfo database, and a named zone without zoneinfo silently falls
-- back to UTC: exactly that lie made the worker report 20:53 while it
-- was 22:55 (9 sep 2026). The EU rule (CEST between 01:00 UTC on the
-- last Sunday of March and 01:00 UTC on the last Sunday of October) is
-- three lines and cannot fail soft. Alternative considered: shipping
-- tzdata in the image; rejected as a heavier fix for the same three
-- lines, and the gate would still lie if the package went missing.
module Claude.Gate.WorkingHours
  ( runWorkingHours
  , workingHoursWarning
  , amsterdamTimeZone
  , OutsideWorkingHours (..)
  ) where

import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time
  ( Day
  , DayOfWeek (Sunday)
  , LocalTime (localDay, localTimeOfDay)
  , TimeOfDay (TimeOfDay)
  , TimeZone (TimeZone)
  , UTCTime (UTCTime)
  , dayOfWeek
  , defaultTimeLocale
  , formatTime
  , fromGregorian
  , getCurrentTime
  , gregorianMonthLength
  , timeOfDayToTime
  , toGregorian
  , utcToLocalTime
  , utctDay
  )
import Claude.Gate.GateConfig (phaseDisabled)
import Claude.Gate.HookProtocol (BlockReason (BlockReason), blockAndExit)
import Claude.Gate.TurnState (TurnPaths (hoursWarned), flagExists, writeFlag)

-- | Why the current moment is outside working hours.
data OutsideWorkingHours = NightRest | SundayRest
  deriving (Show, Eq)

-- | Warn (as a blocking Stop reason) at most once per turn when the Stop
-- fires outside working hours. The flag makes the warning one-shot: after
-- the worker has seen it and decided, later Stops of the same turn pass
-- through, and the next user prompt resets the flag with the rest of the
-- turn state. @CLAUDE_SKIP_HOURS_CHECK=1@ disables the phase.
runWorkingHours :: TurnPaths -> IO ()
runWorkingHours paths = do
  disabled <- phaseDisabled "CLAUDE_SKIP_HOURS_CHECK"
  alreadyWarned <- flagExists (hoursWarned paths)
  if disabled || alreadyWarned
    then pure ()
    else do
      now <- getCurrentTime
      case workingHoursWarning now of
        Nothing -> pure ()
        Just warning -> do
          writeFlag (hoursWarned paths)
          blockAndExit (BlockReason warning)

-- | The warning for a moment outside working hours, or 'Nothing' during
-- working hours. Pure so the DST arithmetic and the rule edges are
-- testable without a clock.
workingHoursWarning :: UTCTime -> Maybe Text
workingHoursWarning now =
  let zone :: TimeZone
      zone = amsterdamTimeZone now
      localNow :: LocalTime
      localNow = utcToLocalTime zone now
  in fmap (renderWarning zone localNow) (outsideWorkingHours localNow)

-- | The rest rules from CLAUDE.md over the local Amsterdam clock: Sunday
-- is rest all day; other days rest runs from 22:45 up to 07:00.
outsideWorkingHours :: LocalTime -> Maybe OutsideWorkingHours
outsideWorkingHours localNow =
  if | dayOfWeek (localDay localNow) == Sunday -> Just SundayRest
     | localTimeOfDay localNow >= TimeOfDay 22 45 0 -> Just NightRest
     | localTimeOfDay localNow < TimeOfDay 7 0 0 -> Just NightRest
     | otherwise -> Nothing

renderWarning :: TimeZone -> LocalTime -> OutsideWorkingHours -> Text
renderWarning zone localNow reason =
  let clock :: Text
      clock = Text.pack (formatTime defaultTimeLocale "%H:%M" localNow)
      zoneName :: Text
      zoneName = Text.pack (formatTime defaultTimeLocale "%Z" zone)
      weekday :: Text
      weekday = Text.pack (show (dayOfWeek (localDay localNow)))
      ruleLine :: Text
      ruleLine = case reason of
        NightRest -> "the night rule (no work 22:45-07:00 NL) applies"
        SundayRest -> "the Sunday rule (no work on Sunday) applies"
  in "warning outside working hours, see claude.md. It is "
       <> clock <> " " <> zoneName <> " on " <> weekday
       <> " in NL and " <> ruleLine
       <> "; decide per those rules whether to wrap up and refuse."

-- | The Amsterdam clock for a UTC moment: CEST (UTC+2) inside EU summer
-- time, CET (UTC+1) outside it.
amsterdamTimeZone :: UTCTime -> TimeZone
amsterdamTimeZone at =
  if inEuSummerTime at
    then TimeZone 120 True "CEST"
    else TimeZone 60 False "CET"

-- | EU summer time runs from 01:00 UTC on the last Sunday of March up to
-- 01:00 UTC on the last Sunday of October.
inEuSummerTime :: UTCTime -> Bool
inEuSummerTime at =
  let (year, _month, _day) = toGregorian (utctDay at)
      oneHourUtc = timeOfDayToTime (TimeOfDay 1 0 0)
      summerStart = UTCTime (lastSundayOf year 3) oneHourUtc
      summerEnd = UTCTime (lastSundayOf year 10) oneHourUtc
  in at >= summerStart && at < summerEnd

lastSundayOf :: Integer -> Int -> Day
lastSundayOf year month =
  lastSundayBefore (fromGregorian year month (gregorianMonthLength year month))

lastSundayBefore :: Day -> Day
lastSundayBefore day =
  if dayOfWeek day == Sunday
    then day
    else lastSundayBefore (pred day)
