{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE OverloadedLabels #-}

module Main (main) where

import qualified GI.Gtk as Gtk
import qualified GI.Gio as Gio
import qualified GI.GLib as GLib
import qualified GI.Cairo.Render.Connector as Cairo
import Data.IORef (IORef, newIORef, readIORef, writeIORef)
import Data.Int (Int32)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Vector as V
import System.Environment (getArgs, lookupEnv)
import System.Exit (exitFailure)

import Face (drawFace, instanceColor)
import Viseme (Viseme(..), TimedViseme(..), parseTimingFile)

-- | Animation state: current viseme index and elapsed time within it.
data AnimState = AnimState
  { asIndex     :: Int
  , asElapsedMs :: Double
  } deriving (Show)

main :: IO ()
main = do
  args <- getArgs
  case args of
    [jsonPath] -> runFace jsonPath
    _ -> do
      putStrLn "Usage: face-speak <phoneme-timing.json>"
      exitFailure

runFace :: FilePath -> IO ()
runFace jsonPath = do
  result <- parseTimingFile jsonPath
  timedVisemes <- case result of
    Left err -> do
      putStrLn $ "Error parsing timing file: " ++ err
      exitFailure
    Right vs -> pure vs

  instanceName <- maybe "unknown" T.pack <$> lookupEnv "INSTANCE_NAME"
  let color = instanceColor instanceName

  app <- Gtk.applicationNew (Just "com.haskellvibes.facespeak") []
  stateRef <- newIORef (AnimState 0 0.0)

  _ <- Gio.onApplicationActivate app $ do
    activateApp app stateRef timedVisemes color instanceName
  _ <- Gio.applicationRun app Nothing
  pure ()

activateApp :: Gtk.Application
            -> IORef AnimState
            -> V.Vector TimedViseme
            -> (Double, Double, Double)
            -> Text
            -> IO ()
activateApp app stateRef timedVisemes color instanceName = do
  win <- Gtk.applicationWindowNew app
  Gtk.windowSetTitle win (Just (T.append instanceName " speaking"))
  Gtk.windowSetDefaultSize win 300 300
  Gtk.windowSetDecorated win True

  drawArea <- Gtk.drawingAreaNew
  Gtk.drawingAreaSetContentWidth drawArea 300
  Gtk.drawingAreaSetContentHeight drawArea 300
  Gtk.windowSetChild win (Just drawArea)

  -- Set the draw function
  Gtk.drawingAreaSetDrawFunc drawArea $ Just $ \_area context w h -> do
    st <- readIORef stateRef
    let currentViseme = getCurrentViseme timedVisemes (asIndex st)
    Cairo.renderWithContext (drawFace color (fromIntegral w) (fromIntegral h) currentViseme) context

  -- Animation tick at ~60fps (16ms)
  let tickMs :: Int32
      tickMs = 16
  _ <- GLib.timeoutAdd GLib.PRIORITY_DEFAULT (fromIntegral tickMs) $ do
    st <- readIORef stateRef
    let idx = asIndex st
    if idx >= V.length timedVisemes
      then do
        Gtk.windowClose win
        pure False  -- Stop the timer
      else do
        let elapsed = asElapsedMs st + fromIntegral tickMs
            currentDuration = tvDurationMs (timedVisemes V.! idx)
        if elapsed >= currentDuration
          then do
            writeIORef stateRef (AnimState (idx + 1) (elapsed - currentDuration))
            Gtk.widgetQueueDraw drawArea
            pure True
          else do
            writeIORef stateRef (st { asElapsedMs = elapsed })
            pure True
  Gtk.windowPresent win

-- | Get the current viseme, or Rest if past the end.
getCurrentViseme :: V.Vector TimedViseme -> Int -> Viseme
getCurrentViseme vs idx
  | idx >= 0 && idx < V.length vs = tvViseme (vs V.! idx)
  | otherwise                      = Rest

