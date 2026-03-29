{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Test.Tasty (TestTree, defaultMain, testGroup)
import Test.Tasty.HUnit (testCase, (@?=), assertBool)
import Data.Aeson (eitherDecodeStrict)
import Data.Text.Encoding (encodeUtf8)
import qualified Data.ByteString as BS
import qualified Data.Vector as V

import Viseme

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests = testGroup "face-speak"
  [ visemeMappingTests
  , jsonParsingTests
  , timingConversionTests
  ]

visemeMappingTests :: TestTree
visemeMappingTests = testGroup "phonemeToViseme"
  [ testCase "silence maps to Rest" $ do
      phonemeToViseme "_" @?= Rest
      phonemeToViseme " " @?= Rest
      phonemeToViseme "" @?= Rest

  , testCase "vowels map to correct visemes" $ do
      phonemeToViseme "\x0251" @?= AA   -- ɑ
      phonemeToViseme "\x00e6" @?= AA   -- æ
      phonemeToViseme "\x028c" @?= AH   -- ʌ
      phonemeToViseme "\x0259" @?= AH   -- ə
      phonemeToViseme "i" @?= EE
      phonemeToViseme "\x026a" @?= EE   -- ɪ
      phonemeToViseme "\x025b" @?= EH   -- ɛ
      phonemeToViseme "o\x028a" @?= OH  -- oʊ
      phonemeToViseme "u" @?= OO

  , testCase "consonants map to correct visemes" $ do
      phonemeToViseme "s" @?= S
      phonemeToViseme "z" @?= S
      phonemeToViseme "\x0283" @?= SH   -- ʃ
      phonemeToViseme "t\x0283" @?= SH  -- tʃ
      phonemeToViseme "\x03b8" @?= TH   -- θ
      phonemeToViseme "f" @?= F
      phonemeToViseme "v" @?= F
      phonemeToViseme "m" @?= M
      phonemeToViseme "p" @?= M
      phonemeToViseme "n" @?= N
      phonemeToViseme "t" @?= N
      phonemeToViseme "l" @?= L
      phonemeToViseme "\x0279" @?= R    -- ɹ
      phonemeToViseme "w" @?= W

  , testCase "unknown phoneme falls back to N" $
      phonemeToViseme "\x00e7" @?= N    -- ç

  , testCase "all viseme constructors are reachable" $ do
      -- Ensure every viseme has at least one phoneme mapping
      let reachable = map phonemeToViseme
            [ "_", "\x0251", "\x028c", "i", "\x025b"
            , "o\x028a", "u", "\x0279", "l", "s"
            , "\x0283", "\x03b8", "f", "m", "n", "w"
            ]
      assertBool "all visemes reachable" (all (`elem` reachable) allVisemes)
  ]

jsonParsingTests :: TestTree
jsonParsingTests = testGroup "JSON parsing"
  [ testCase "valid timing file parses" $ do
      let json = encodeUtf8 "{\"sample_rate\":22050,\"phonemes\":[{\"phoneme\":\"h\",\"samples\":1024},{\"phoneme\":\"\x025b\",\"samples\":2048}]}"
          result = eitherDecodeStrict json :: Either String TimingFile
      case result of
        Left err -> fail err
        Right tf -> do
          tfSampleRate tf @?= 22050
          V.length (tfPhonemes tf) @?= 2
          pePhoneme (tfPhonemes tf V.! 0) @?= "h"
          peSamples (tfPhonemes tf V.! 0) @?= 1024

  , testCase "empty phoneme list parses" $ do
      let json = encodeUtf8 "{\"sample_rate\":22050,\"phonemes\":[]}"
          result = eitherDecodeStrict json :: Either String TimingFile
      case result of
        Left err -> fail err
        Right tf -> V.length (tfPhonemes tf) @?= 0
  ]

timingConversionTests :: TestTree
timingConversionTests = testGroup "timing conversion"
  [ testCase "samples to duration conversion is correct" $ do
      -- 22050 samples at 22050 Hz = 1000ms
      let json = encodeUtf8 "{\"sample_rate\":22050,\"phonemes\":[{\"phoneme\":\"\x0251\",\"samples\":22050}]}"
      BS.writeFile "/tmp/face-speak-test.json" json
      result <- parseTimingFile "/tmp/face-speak-test.json"
      case result of
        Left err -> fail err
        Right vs -> do
          V.length vs @?= 1
          let tv = vs V.! 0
          tvViseme tv @?= AA
          -- 22050 samples / 22050 rate * 1000 = 1000ms
          assertBool "duration ~1000ms" (abs (tvDurationMs tv - 1000.0) < 0.01)

  , testCase "silence phoneme maps to Rest viseme" $ do
      let json = encodeUtf8 "{\"sample_rate\":22050,\"phonemes\":[{\"phoneme\":\"_\",\"samples\":512}]}"
      BS.writeFile "/tmp/face-speak-test2.json" json
      result <- parseTimingFile "/tmp/face-speak-test2.json"
      case result of
        Left err -> fail err
        Right vs -> do
          V.length vs @?= 1
          tvViseme (vs V.! 0) @?= Rest

  , testCase "multiple phonemes produce correct sequence" $ do
      let json = encodeUtf8 "{\"sample_rate\":22050,\"phonemes\":[{\"phoneme\":\"h\",\"samples\":1024},{\"phoneme\":\"\x025b\",\"samples\":2048},{\"phoneme\":\"l\",\"samples\":1536}]}"
      BS.writeFile "/tmp/face-speak-test3.json" json
      result <- parseTimingFile "/tmp/face-speak-test3.json"
      case result of
        Left err -> fail err
        Right vs -> do
          V.length vs @?= 3
          tvViseme (vs V.! 0) @?= AH  -- h maps to AH
          tvViseme (vs V.! 1) @?= EH  -- ɛ maps to EH
          tvViseme (vs V.! 2) @?= L   -- l maps to L
  ]
