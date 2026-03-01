# basement → primitive/base Migration Learnings

## Goal
Remove all `basement` package dependencies from `crypton` (and next: `memory`).
Replace with `primitive`, `base`, and other well-maintained alternatives.
`memory` package is explicitly allowed as a dependency for now.

## Build command
```
nix-shell -p ghc cabal-install --run "cabal build"
```
GHC 9.10.3, cabal-install on NixOS.

---

## The core type change already in the repo (unstaged)
`Digest a` was already changed from wrapping `memory`'s `Bytes` to wrapping
`Data.Primitive.ByteArray.ByteArray` (from `primitive`):
```haskell
-- Hash/Types.hs
newtype Digest a = Digest ByteArray  -- ByteArray = Data.Primitive.ByteArray.ByteArray
```
This is the root of most cascading fixes needed in `crypton`.

---

## Key type confusion to watch for
- `Data.Primitive.ByteArray.ByteArray`  — a **data type** (from `primitive`)
- `Data.ByteArray.ByteArray`            — a **typeclass** (from `memory`)
Both named `ByteArray`. They do NOT have instances of each other.

---

## Basement → replacement mapping
| basement | replacement |
|---|---|
| `Block Word8` (immutable) | `Data.Primitive.ByteArray.ByteArray` |
| `MutableBlock Word8 (PrimState IO)` | `ForeignPtr Word8` (via `mallocForeignPtrBytes`) |
| `Block.newPinned (CountOf n)` | `mallocForeignPtrBytes n` |
| `Block.withMutablePtr mblock f` | `withForeignPtr fp f` |
| `Block.unsafeWrite mblock i b` | `pokeByteOff ptr i b` |
| `Block.unsafeFreeze mblock` | `BSI.fromForeignPtr fp 0 n` (→ ByteString with ByteArrayAccess) |
| `CountOf n` | `Int` |
| `Offset n` | `Int` |
| `PrimState IO` | just `IO` or remove entirely |

---

## ByteArrayAccess instance for Digest
Added to `Crypto/Hash/Types.hs`. ONLY safe because all `Digest` values
are created via `newPinnedByteArray` (pinned memory required for
`withByteArrayContents`):
```haskell
instance ByteArrayAccess (Digest a) where
    length (Digest ba) = sizeofByteArray ba
    withByteArray (Digest ba) f = withByteArrayContents ba (f . castPtr)
```
Import `ByteArrayAccess` with `(..)` so class methods are visible for
instance definition (GHC 9.10 requirement):
```haskell
import Crypto.Internal.ByteArray (ByteArrayAccess (..), Bytes)
```

---

## The allocAndFreezePrim pattern
Instead of scattering `unsafeDoIO`/`newPinnedByteArray`/`unsafeFreezeByteArray`
at every `Digest`-creation site, we added two helpers to
`Crypto/Internal/ByteArray.hs`:

```haskell
import qualified Data.Primitive.ByteArray as Prim

-- For IO contexts (hashMutableFinalize etc.)
allocAndFreezePrimIO :: Int -> (Ptr p -> IO ()) -> IO Prim.ByteArray
allocAndFreezePrimIO n f = do
    mba <- Prim.newPinnedByteArray n
    f (castPtr (Prim.mutableByteArrayContents mba))
    Prim.unsafeFreezeByteArray mba

-- For pure contexts (hashFinalize etc.) — unsafeDoIO in exactly ONE place
allocAndFreezePrim :: Int -> (Ptr p -> IO ()) -> Prim.ByteArray
allocAndFreezePrim n = unsafeDoIO . allocAndFreezePrimIO n
```

Usage pattern (pure):
```haskell
hashFinalize !c = Digest $ allocAndFreezePrim (hashDigestSize (undefined :: a)) $
    \(dig :: Ptr (Digest a)) -> do
        ((!_) :: B.Bytes) <- B.copy c $ \(ctx :: Ptr (Context a)) ->
            hashInternalFinalize ctx dig
        return ()
```

Usage pattern (IO):
```haskell
hashMutableFinalize mc = do
    ba <- allocAndFreezePrimIO (hashDigestSize (undefined :: a)) $
        \(dig :: Ptr (Digest a)) ->
            B.withByteArray mc $ \(ctx :: Ptr (Context a)) ->
                hashInternalFinalize ctx dig
    return (Digest ba)
```

**Why NOT `Digest <$> allocAndFreezePrimIO n $ \dig -> ...`:**
`<$>` (precedence 4) with `$` (precedence 0) causes `fmap` to apply to the
partially-applied function, not the IO value. Use do-notation instead.

---

## Why NOT an orphan ByteArray (typeclass) instance for Prim.ByteArray
Considered and rejected:
1. `withByteArray` (from memory's `ByteArrayAccess`) calls `withByteArrayContents`
   which is only safe for **pinned** arrays. A general instance would be a
   footgun for any unpinned `Prim.ByteArray`.
2. Orphan coherence risk: if `primitive` or `memory` ever adds the same
   instance, all downstream users get a compile error.
3. GHC `-Worphans` warning (part of `-Wall`).

---

## Files changed in crypton
- `Crypto/Hash/Types.hs` — `ByteArrayAccess (Digest a)` instance; `Read` uses
  `newPinnedByteArray`; `ByteArrayAccess (..)` import
- `Crypto/Hash.hs` — removed basement imports; uses `allocAndFreezePrim`
- `Crypto/Hash/IO.hs` — uses `allocAndFreezePrimIO`
- `Crypto/MAC/KMAC.hs` — `cshakeFinalize` uses `allocAndFreezePrim`
- `Crypto/KDF/BCryptPBKDF.hs` — full rewrite; `ForeignPtr` replaces
  `MutableBlock`; `BSI.fromForeignPtr` for `ByteString` views passed to
  `expandKey`/`expandKeyWithSalt` (which need `ByteArrayAccess`)
- `Crypto/PubKey/ECDSA.hs` — `tHashDigest`: removed `Digest` pattern match;
  uses `B.convert dig :: B.Bytes` to get memory-compatible bytes
- `Crypto/Internal/ByteArray.hs` — added `allocAndFreezePrim`,
  `allocAndFreezePrimIO`

---

## Next task: memory repository
Goal: remove `basement` from `memory` package itself.
Key things `memory` uses from basement:
- `Block`/`MutableBlock` — same mapping as above applies
- `basement`'s `PrimType` / `PrimMonad` — check if `primitive`'s equivalents
  (`Prim`, `PrimMonad`) are drop-in replacements
- `memory`'s own `Bytes` type is essentially a pinned `ByteArray` with a
  `ByteArrayAccess` instance — after migration it should wrap
  `Data.Primitive.ByteArray.ByteArray` similarly to what we did for `Digest`
- Watch for `NativeEndian`, `LE`, `BE` wrappers from basement — may need
  `Data.Primitive.ByteArray` reads with explicit endianness handling or
  `Data.Primitive.Endian` if available in the `primitive` version in use.
- Check `memory`'s test suite carefully — it has property tests that will
  catch semantic regressions.

## Useful primitives imports
```haskell
import Data.Primitive.ByteArray
  ( ByteArray, MutableByteArray
  , newByteArray, newPinnedByteArray
  , readByteArray, writeByteArray
  , copyByteArray, copyMutableByteArray
  , sizeofByteArray
  , mutableByteArrayContents   -- ONLY safe for pinned arrays!
  , withByteArrayContents      -- ONLY safe for pinned arrays!
  , unsafeFreezeByteArray
  )
import Control.Monad.Primitive (PrimMonad (..), PrimState)
```
