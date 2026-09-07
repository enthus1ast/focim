## The pixie-backed image relays, watched through a stub surface.
##
## `focim/images.nim` fills in the three image relays for a driver that has
## none, over `blitRGBA` -- the driver's offer of somewhere to put finished
## pixels. What arrives there is what is checked: not that a picture was
## drawn, which the caller could believe of a relay that drew nothing, but
## the pixels themselves, one at a time, against arithmetic done by hand.
##
## The stub is the X11 driver's shape: shapes and a surface, no decoder. So
## this is the case `installPixieImages` exists for, and the one every Linux
## build is in.
import std/[os, strutils]
import pixie
from uirelays/screen import nil
# Everything of `screen` is written out in full here, because `pixie` has an
# `Image` and a `Color` of its own and this file is where the two meet. An
# operator cannot be spelled that way and be an operator, so `==` comes in
# on its own.
from uirelays/screen import `==`
from uirelays/coords import nil
import focim/images

var
  blitted: seq[uint32]
  blitW, blitH: int
  blitDst: coords.Rect
  blits = 0

proc stubBlit(pixels: ptr UncheckedArray[uint32]; w, h: int;
              dst: coords.Rect): bool {.nimcall.} =
  inc blits
  blitW = w
  blitH = h
  blitDst = dst
  blitted.setLen w * h
  for i in 0 ..< w * h: blitted[i] = pixels[i]
  result = true

proc installStubSurface() =
  screen.drawRelays = screen.DrawRelays(
    fillRect: proc (r: coords.Rect; c: screen.Color) = discard,
    drawLine: proc (x1, y1, x2, y2: int; color: screen.Color) = discard,
    drawPoint: proc (x, y: int; color: screen.Color) = discard,
    blitRGBA: stubBlit)

var failures = 0

proc check(name: string; cond: bool; detail = "") =
  if cond:
    echo "  PASS  ", name
  else:
    inc failures
    echo "  FAIL  ", name, (if detail.len > 0: "  -- " & detail else: "")

# `toHex` here is chroma's, which is about colors. This one is about bytes.
proc hex(v: uint32): string = "0x" & strutils.toHex(v.int64, 6)

# ---------------------------------------------------------------------------
# A picture with one pixel of every case in it.

let dir = getTempDir() / "focim-pixieimagetest"
createDir dir
let fourWays = dir / "fourways.png"

block:
  var src = newImage(2, 2)
  # Pixie keeps color premultiplied by alpha, and PNG does not, so these go
  # out divided and come back multiplied. The values are chosen to survive
  # that: 128 over 128 is 255 straight, and 255 back down is 128 again.
  src.data[0] = rgbx(255, 0, 0, 255)      # opaque red
  src.data[1] = rgbx(0, 0, 0, 0)          # nothing at all
  src.data[2] = rgbx(128, 128, 128, 128)  # white, half there
  src.data[3] = rgbx(0, 255, 0, 255)      # opaque green
  src.writeFile(fourWays)

installStubSurface()
installPixieImages()

echo "a driver with a surface and no decoder:"
check "gets the relays filled in", screen.drawRelays.loadImage != nil
check "including the one that says how big a picture is",
  screen.drawRelays.imageSize != nil

let img = screen.loadImage(fourWays)
check "a picture that is there loads", img != screen.Image(0)
check "and knows its own size", screen.imageSize(img) == (2, 2),
  $screen.imageSize(img)

echo "drawn at its own size, on a backdrop of 0x203040:"
setImageBackdrop(screen.color(0x20, 0x30, 0x40))
screen.drawImage(img, coords.rect(0, 0, 2, 2), coords.rect(10, 20, 2, 2))
check "lands at the rectangle it was given",
  blitDst == coords.rect(10, 20, 2, 2), $blitDst
check "and is the size of it", blitW == 2 and blitH == 2,
  $blitW & "x" & $blitH
check "opaque red comes through untouched", blitted[0] == 0x00FF0000'u32,
  hex(blitted[0])
check "opaque green comes through untouched", blitted[3] == 0x0000FF00'u32,
  hex(blitted[3])
# Nothing of the picture, so all of the backdrop.
check "a fully transparent pixel is the backdrop",
  blitted[1] == 0x00203040'u32, hex(blitted[1])
# 128 of the picture and 127/255 of the backdrop, per channel:
#   r: 128 + (0x20 * 127 + 127) div 255 = 128 + 16 = 144 = 0x90
#   g: 128 + (0x30 * 127 + 127) div 255 = 128 + 24 = 152 = 0x98
#   b: 128 + (0x40 * 127 + 127) div 255 = 128 + 32 = 160 = 0xA0
check "a half-transparent white is half the backdrop",
  blitted[2] == 0x009098A0'u32, hex(blitted[2])
check "and nothing has an alpha byte left in it",
  (blitted[0] or blitted[1] or blitted[2] or blitted[3]) < 0x01000000'u32

echo "the backdrop is not baked in:"
let before = blits
setImageBackdrop(screen.color(0, 0, 0))
screen.drawImage(img, coords.rect(0, 0, 2, 2), coords.rect(10, 20, 2, 2))
check "a new backdrop is composited again", blits == before + 1
check "and the transparent pixel follows it", blitted[1] == 0x00000000'u32,
  hex(blitted[1])

echo "the same picture the same way twice:"
let sameAgain = blits
screen.drawImage(img, coords.rect(0, 0, 2, 2), coords.rect(10, 20, 2, 2))
check "still reaches the surface -- every frame draws", blits == sameAgain + 1
check "and is the same pixels", blitted[0] == 0x00FF0000'u32

echo "scaled up:"
screen.drawImage(img, coords.rect(0, 0, 2, 2), coords.rect(0, 0, 8, 8))
check "the surface gets the destination's size, not the picture's",
  blitW == 8 and blitH == 8, $blitW & "x" & $blitH
check "and a buffer to match", blitted.len == 64, $blitted.len
# The corners of a scaled picture are the corners of the picture: whatever
# the filter does in between, it does not move them.
check "the top-left corner is still red", blitted[0] == 0x00FF0000'u32,
  hex(blitted[0])
check "the bottom-right corner is still green", blitted[63] == 0x0000FF00'u32,
  hex(blitted[63])

echo "a picture that is not there:"
check "does not load", screen.loadImage(dir / "nope.png") == screen.Image(0)
check "nor does a file that is not a picture",
  (block:
    let bad = dir / "bad.png"
    writeFile(bad, "this is not a PNG")
    screen.loadImage(bad) == screen.Image(0))

echo "freeing:"
let reused = screen.loadImage(fourWays)
screen.freeImage(reused)
check "a freed picture has no size any more",
  screen.imageSize(reused) == (0, 0), $screen.imageSize(reused)
check "and drawing it does nothing rather than something wrong",
  (block:
    let n = blits
    screen.drawImage(reused, coords.rect(0, 0, 2, 2), coords.rect(0, 0, 2, 2))
    blits == n)

echo "a driver that brings its own decoder:"
installStubSurface()
screen.drawRelays.loadImage = proc (path: string): screen.Image =
  screen.Image(42)
installPixieImages()
check "keeps it", screen.loadImage("anything at all") == screen.Image(42)
check "and is not given the pixie one behind its back",
  screen.drawRelays.imageSize == nil

echo "a driver with no surface to put pixels on:"
screen.drawRelays = screen.DrawRelays(
  fillRect: proc (r: coords.Rect; c: screen.Color) = discard,
  drawLine: proc (x1, y1, x2, y2: int; color: screen.Color) = discard,
  drawPoint: proc (x, y: int; color: screen.Color) = discard)
installPixieImages()
check "gets nothing, and draws its placeholder as it always did",
  screen.drawRelays.loadImage == nil

removeDir dir
if failures > 0: quit "FAILURE " & $failures & " check(s)"
echo "ALL PASS"
