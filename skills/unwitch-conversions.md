# Haskell Numeric Conversions: Always Use unwitch

**Rule**: Never use `fromIntegral` for numeric conversions in Haskell. Use the `unwitch` library instead.
Hackage: https://hackage.haskell.org/package/unwitch (latest: 2.2.0+)

## Why
- `fromIntegral` silently truncates, wraps, or loses precision with no indication at the call site
- unwitch gives named functions that describe the conversion (e.g. `Int.toCInt`, `CInt.toDouble`)
- Partial conversions return `Maybe`/`Either` instead of silently corrupting values
- No type applications needed, ctags work, no orphan issues

## Import Pattern
```haskell
import qualified Unwitch.Convert.Int as Int
import qualified Unwitch.Convert.Int32 as Int32
import qualified Unwitch.Convert.CInt as CInt
import qualified Unwitch.Convert.Word8 as Word8
-- etc. One module per source type.
```

## Key Total Conversions (never fail)
| From → To | Function | Notes |
|---|---|---|
| `Int32 → CInt` | `Int32.toCInt` | CInt is newtype over Int32 |
| `Int32 → Double` | `Int32.toDouble` | All Int32 fit in Double exactly |
| `CInt → Int32` | `CInt.toInt32` | CInt is newtype over Int32 |
| `CInt → Int` | `CInt.toInt` | Widening, always safe |
| `CInt → Double` | `CInt.toDouble` | All Int32 fit in Double exactly |
| `Word8 → CInt` | `Word8.toCInt` | Widening |

## Key Partial Conversions (can fail)
| From → To | Function | Return | When it fails |
|---|---|---|---|
| `Int → CInt` | `Int.toCInt` | `Maybe CInt` | Int outside Int32 range |
| `Int → Int32` | `Int.toInt32` | `Maybe Int32` | Int outside Int32 range |
| `Int → Double` | `Int.toDouble` | `Either Overflows Double` | Int > 2^53 (precision loss) |
| `Int → Word8` | `Int.toWord8` | `Maybe Word8` | Int < 0 or > 255 |
| `CInt → Int16` | `CInt.toInt16` | `Maybe Int16` | CInt outside Int16 range |

## Handling Partial Conversions — NEVER use `error`

Instead of `fromMaybe (error "msg") . Int.toCInt`, use these patterns:

### 1. Use total conversions where possible
Prefer types that allow total conversion. E.g. if a value is always small, store it as `CInt` instead of `Int`:
```haskell
hexSize :: CInt    -- not Int, since consumers need CInt
hexSize = 80
-- Now CInt.toDouble hexSize is total, no Maybe needed
```

### 2. Use `floor`/`round` targeting the right type directly
Instead of `floor :: Double -> Int` then `Int.toCInt`, use:
```haskell
floor someDouble :: CInt    -- floor targets CInt directly via Integral instance
round someDouble :: CInt    -- same for round
```

### 3. Default value for known-safe conversions
When you know values are small (grid coords, UI indices, health points):
```haskell
toCInt' :: Int -> CInt
toCInt' = maybe 0 id . Int.toCInt  -- 0 default unreachable for small values
```

### 4. Clamp for genuinely narrowing conversions
For SDL/rendering where out-of-range should clamp not crash:
```haskell
cintToInt16Clamp :: CInt -> Int16
cintToInt16Clamp c = case CInt.toInt16 c of
  Just i  -> i
  Nothing -> if CInt.toInt c > 0 then maxBound else minBound
```

### 5. Restructure loops to avoid conversion
Instead of converting Int loop variable to Word8:
```haskell
-- Bad: forM_ [1..20 :: Int] $ \i -> fireAlpha (fromMaybe (error "...") (Int.toWord8 (i * 11)))
-- Good: forM_ [11, 22 .. 220 :: Word8] $ \alpha -> fireAlpha alpha
```

## Checking Available Conversions
```bash
w3m -dump "https://hackage.haskell.org/package/unwitch/docs/Unwitch-Convert-<Type>.html"
```
