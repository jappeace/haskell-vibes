{-# LANGUAGE OverloadedStrings #-}

module Face
  ( drawFace
  , instanceColor
  ) where

import GI.Cairo.Render (Render, setSourceRGB, arc, fill, moveTo,
                         lineTo, stroke, setLineWidth, closePath,
                         curveTo, newPath, rectangle)
import Viseme (Viseme(..))
import Data.Text (Text)
import qualified Data.Text as T

-- | Get face color based on instance name.
-- Returns (r, g, b) tuple for the face outline/features.
instanceColor :: Text -> (Double, Double, Double)
instanceColor name = case T.toLower name of
  "stan"  -> (0.2, 0.6, 0.9)   -- blue
  "cabal" -> (0.9, 0.3, 0.3)   -- red
  "morag" -> (0.3, 0.8, 0.4)   -- green
  _       -> (0.7, 0.5, 0.9)   -- purple default

-- | Draw the complete face with the given viseme mouth shape.
-- Coordinates are in a 400x400 space centered at (200, 200).
drawFace :: (Double, Double, Double) -> Double -> Double -> Viseme -> Render ()
drawFace color width height viseme = do
  let cx = width / 2.0
      cy = height / 2.0
      faceRadius = min width height * 0.38
      (r, g, b) = color

  -- Background
  setSourceRGB 0.12 0.12 0.15
  rectangle 0 0 width height
  fill

  -- Face circle
  setSourceRGB r g b
  setLineWidth 3.0
  arc cx cy faceRadius 0 (2 * pi)
  stroke

  -- Left eye
  let eyeY = cy - faceRadius * 0.22
      eyeSpacing = faceRadius * 0.3
      eyeRadius = faceRadius * 0.08
  setSourceRGB r g b
  arc (cx - eyeSpacing) eyeY eyeRadius 0 (2 * pi)
  fill

  -- Right eye
  arc (cx + eyeSpacing) eyeY eyeRadius 0 (2 * pi)
  fill

  -- Mouth
  let mouthY = cy + faceRadius * 0.25
      mouthW = faceRadius * 0.4
  drawMouth color cx mouthY mouthW viseme

-- | Draw the mouth shape for a specific viseme.
drawMouth :: (Double, Double, Double) -> Double -> Double -> Double -> Viseme -> Render ()
drawMouth (r, g, b) cx cy mouthW viseme = do
  setSourceRGB r g b
  setLineWidth 2.5
  case viseme of
    Rest -> drawClosedMouth cx cy mouthW
    AA   -> drawOpenMouth cx cy mouthW 1.0 0.9
    AH   -> drawOpenMouth cx cy mouthW 0.8 0.7
    EE   -> drawWideMouth cx cy mouthW 0.3
    EH   -> drawOpenMouth cx cy mouthW 0.7 0.5
    OH   -> drawRoundMouth cx cy (mouthW * 0.6) 0.7
    OO   -> drawRoundMouth cx cy (mouthW * 0.35) 0.5
    R    -> drawRoundMouth cx cy (mouthW * 0.4) 0.4
    L    -> drawOpenMouth cx cy mouthW 0.5 0.3
    S    -> drawWideMouth cx cy mouthW 0.15
    SH   -> drawRoundMouth cx cy (mouthW * 0.5) 0.5
    TH   -> drawOpenMouth cx cy mouthW 0.4 0.3
    F    -> drawBiteLip cx cy mouthW
    M    -> drawClosedMouth cx cy mouthW
    N    -> drawOpenMouth cx cy mouthW 0.3 0.2
    W    -> drawRoundMouth cx cy (mouthW * 0.3) 0.4

-- | Closed horizontal line mouth.
drawClosedMouth :: Double -> Double -> Double -> Render ()
drawClosedMouth cx cy halfW = do
  newPath
  moveTo (cx - halfW) cy
  lineTo (cx + halfW) cy
  stroke

-- | Open mouth: oval shape. widthScale and heightScale are 0.0-1.0.
drawOpenMouth :: Double -> Double -> Double -> Double -> Double -> Render ()
drawOpenMouth cx cy halfW widthScale heightScale = do
  let w = halfW * widthScale
      h = halfW * heightScale
      top = cy - h * 0.5
      bot = cy + h * 0.5
  newPath
  moveTo (cx - w) cy
  curveTo (cx - w) top (cx + w) top (cx + w) cy
  curveTo (cx + w) bot (cx - w) bot (cx - w) cy
  closePath
  stroke

-- | Wide smile mouth with small vertical opening.
drawWideMouth :: Double -> Double -> Double -> Double -> Render ()
drawWideMouth cx cy halfW openness = do
  let h = halfW * openness
  newPath
  moveTo (cx - halfW) cy
  curveTo (cx - halfW * 0.3) (cy - h) (cx + halfW * 0.3) (cy - h) (cx + halfW) cy
  curveTo (cx + halfW * 0.3) (cy + h) (cx - halfW * 0.3) (cy + h) (cx - halfW) cy
  closePath
  stroke

-- | Round mouth (O shape).
drawRoundMouth :: Double -> Double -> Double -> Double -> Render ()
drawRoundMouth cx cy radius heightScale = do
  let rx = radius
      ry = radius * heightScale
  newPath
  -- Approximate ellipse with curves
  moveTo (cx - rx) cy
  curveTo (cx - rx) (cy - ry) (cx + rx) (cy - ry) (cx + rx) cy
  curveTo (cx + rx) (cy + ry) (cx - rx) (cy + ry) (cx - rx) cy
  closePath
  stroke

-- | Bite lip: top teeth on lower lip.
drawBiteLip :: Double -> Double -> Double -> Render ()
drawBiteLip cx cy halfW = do
  -- Upper lip line
  newPath
  moveTo (cx - halfW * 0.7) cy
  lineTo (cx + halfW * 0.7) cy
  stroke
  -- Small teeth marks
  let teethY = cy + halfW * 0.1
  newPath
  moveTo (cx - halfW * 0.3) cy
  lineTo (cx - halfW * 0.3) teethY
  stroke
  newPath
  moveTo cx cy
  lineTo cx teethY
  stroke
  newPath
  moveTo (cx + halfW * 0.3) cy
  lineTo (cx + halfW * 0.3) teethY
  stroke
