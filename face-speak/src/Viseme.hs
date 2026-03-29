{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

module Viseme
  ( Viseme(..)
  , TimedViseme(..)
  , PhonemeEntry(..)
  , TimingFile(..)
  , phonemeToViseme
  , parseTimingFile
  , allVisemes
  ) where

import Data.Aeson (FromJSON(..), (.:), withObject, eitherDecodeStrict)
import Data.Text (Text)
import Data.Vector (Vector)
import GHC.Generics (Generic)
import qualified Data.ByteString as BS
import qualified Data.Text as T
import qualified Data.Vector as V

-- | Visual mouth shapes for lip-sync animation.
-- Each viseme represents a distinct mouth position.
data Viseme
  = Rest  -- ^ Closed mouth (silence, pause)
  | AA    -- ^ Wide open (ɑ, æ, a)
  | AH    -- ^ Open (ʌ, ə)
  | EE    -- ^ Wide smile (i, ɪ)
  | EH    -- ^ Half open (ɛ, e)
  | OH    -- ^ Round open (oʊ, ɔ, ɒ)
  | OO    -- ^ Small round (u, ʊ)
  | R     -- ^ Pursed (ɹ, r)
  | L     -- ^ Tongue up (l)
  | S     -- ^ Teeth close (s, z)
  | SH    -- ^ Push forward (ʃ, ʒ, tʃ, dʒ)
  | TH    -- ^ Tongue out (θ, ð)
  | F     -- ^ Bite lip (f, v)
  | M     -- ^ Closed lips (m, p, b)
  | N     -- ^ Slightly open (n, t, d, k, ɡ, ŋ)
  | W     -- ^ Round narrow (w, hw)
  deriving (Show, Eq, Ord, Enum, Bounded, Generic)

-- | All viseme values, for testing/iteration.
allVisemes :: [Viseme]
allVisemes = [minBound .. maxBound]

-- | A viseme with its duration in milliseconds.
data TimedViseme = TimedViseme
  { tvViseme     :: Viseme
  , tvDurationMs :: Double
  } deriving (Show, Eq)

-- | A phoneme entry from the JSON timing file.
data PhonemeEntry = PhonemeEntry
  { pePhoneme :: Text
  , peSamples :: Int
  } deriving (Show, Eq, Generic)

instance FromJSON PhonemeEntry where
  parseJSON = withObject "PhonemeEntry" $ \v ->
    PhonemeEntry <$> v .: "phoneme" <*> v .: "samples"

-- | The top-level JSON timing file structure.
data TimingFile = TimingFile
  { tfSampleRate :: Int
  , tfPhonemes   :: Vector PhonemeEntry
  } deriving (Show, Eq, Generic)

instance FromJSON TimingFile where
  parseJSON = withObject "TimingFile" $ \v ->
    TimingFile <$> v .: "sample_rate" <*> v .: "phonemes"

-- | Map an IPA phoneme string to its viseme group.
phonemeToViseme :: Text -> Viseme
phonemeToViseme phoneme = case phoneme of
  -- Silence / pause
  "_"  -> Rest
  " "  -> Rest
  ""   -> Rest
  -- Wide open (AA)
  "ɑ"  -> AA
  "æ"  -> AA
  "a"  -> AA
  "ɑː" -> AA
  "aː" -> AA
  -- Open (AH)
  "ʌ"  -> AH
  "ə"  -> AH
  "ɐ"  -> AH
  -- Wide smile (EE)
  "i"  -> EE
  "ɪ"  -> EE
  "iː" -> EE
  -- Half open (EH)
  "ɛ"  -> EH
  "e"  -> EH
  "eɪ" -> EH
  "ɛː" -> EH
  -- Round open (OH)
  "oʊ" -> OH
  "ɔ"  -> OH
  "ɒ"  -> OH
  "ɔː" -> OH
  "ɔɪ" -> OH
  -- Small round (OO)
  "u"  -> OO
  "ʊ"  -> OO
  "uː" -> OO
  -- Pursed (R)
  "ɹ"  -> R
  "r"  -> R
  "ɝ"  -> R
  "ɚ"  -> R
  -- Tongue up (L)
  "l"  -> L
  "ɫ"  -> L
  -- Teeth close (S)
  "s"  -> S
  "z"  -> S
  -- Push forward (SH)
  "ʃ"  -> SH
  "ʒ"  -> SH
  "tʃ" -> SH
  "dʒ" -> SH
  -- Tongue out (TH)
  "θ"  -> TH
  "ð"  -> TH
  -- Bite lip (F)
  "f"  -> F
  "v"  -> F
  -- Closed lips (M)
  "m"  -> M
  "p"  -> M
  "b"  -> M
  -- Slightly open (N)
  "n"  -> N
  "t"  -> N
  "d"  -> N
  "k"  -> N
  "ɡ"  -> N
  "g"  -> N
  "ŋ"  -> N
  "ɲ"  -> N
  -- Round narrow (W)
  "w"  -> W
  "hw" -> W
  "ʍ"  -> W
  -- Diphthongs that map to their starting position
  "aɪ" -> AA
  "aʊ" -> AA
  -- Glottal / other consonants default to N (slightly open)
  "h"  -> AH
  "ɦ"  -> AH
  "j"  -> EE
  "ʔ"  -> Rest
  -- Fallback: any unknown phoneme maps to slightly open
  _    -> N

-- | Parse a phoneme timing JSON file into a vector of timed visemes.
parseTimingFile :: FilePath -> IO (Either String (Vector TimedViseme))
parseTimingFile path = do
  bs <- BS.readFile path
  pure $ case eitherDecodeStrict bs of
    Left err -> Left err
    Right tf ->
      let sampleRate :: Double
          sampleRate = fromIntegral (tfSampleRate tf)
          toTimed :: PhonemeEntry -> TimedViseme
          toTimed pe =
            let durationMs :: Double
                durationMs = (fromIntegral (peSamples pe) / sampleRate) * 1000.0
                vis :: Viseme
                vis = phonemeToViseme (T.strip (pePhoneme pe))
            in TimedViseme vis durationMs
      in Right (V.map toTimed (tfPhonemes tf))
