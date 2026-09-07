## A markdown image line on a backend that cannot draw images. The three image
## relays are optional and the X11 driver fills in none of them, so what the
## editor found when it went to show `![focim](screenshots/focim.png)` was a
## nil proc -- and calling one is a segfault, not an empty answer. focim's own
## README opens with that line, so every Linux build crashed on the file it
## tells people to read first.
##
## Both halves are watched here: with no relays the line is drawn as the
## placeholder and the editor lives, and with relays it asks for the picture
## and draws the one it is given.
import uirelays/[screen, coords, input]
import focim/[synedit, theme]

var asked: seq[string]     ## paths loadImage was called with
var painted = 0            ## how often drawImage was called
var lastSrc, lastDst: Rect ## the rectangles of the last drawImage

fontRelays = FontRelays(
  openFont: proc (path: string; size: int; style: FontStyles;
                  metrics: var FontMetrics): Font =
    metrics = FontMetrics(ascent: 12, descent: 4, lineHeight: 16)
    Font(1),
  closeFont: proc (f: Font) = discard,
  getFontMetrics: proc (f: Font): FontMetrics =
    FontMetrics(ascent: 12, descent: 4, lineHeight: 16),
  measureText: proc (f: Font; text: string): TextExtent =
    TextExtent(w: text.len * 8, h: 16),
  drawText: proc (f: Font; x, y: int; text: string;
                  fg, bg: Color): TextExtent =
    TextExtent(w: text.len * 8, h: 16))

# Exactly what `x11_driver.nim` installs: the three that draw shapes, and none
# of the three that carry a picture. Written the same way it writes it, so a
# driver that grows the others does not quietly stop being tested.
drawRelays = DrawRelays(
  fillRect: proc (r: Rect; c: Color) = discard,
  drawLine: proc (x1, y1, x2, y2: int; color: Color) = discard,
  drawPoint: proc (x, y: int; color: Color) = discard)

clipboardRelays = ClipboardRelays(
  getText: proc (): string = "",
  putText: proc (text: string) = discard)

var m: FontMetrics
let font = openFont("", 16, m)

var failures = 0

proc check(name: string; cond: bool; detail = "") =
  if cond:
    echo "  PASS  ", name
  else:
    inc failures
    echo "  FAIL  ", name, (if detail.len > 0: "  -- " & detail else: "")

const
  Area = rect(0, 0, 400, 300)
  Doc = "# focim\n\n![focim](screenshots/focim.png)\n\nprose after it\n"

proc drawDoc(): SynEdit =
  result = createSynEdit(font, defaultTheme())
  result.lang = langMarkdown
  # The flag `newBuffer` sets for a markdown file; without it the line is text
  # like any other and there is no picture to go looking for.
  result.flags.incl rfMarkdownImages
  result.setText(Doc)
  # Twice: the first pass fills the image cache, the second reads it back.
  discard result.draw(default(Event), Area, focused = false)
  discard result.draw(default(Event), Area, focused = false)

echo "no image relays -- what X11 gives it:"
var ed = drawDoc()
check "the image line is drawn without asking for the picture", asked.len == 0
check "and nothing is painted with a picture it never got", painted == 0
check "the text around it is still there", ed.getLineCount() == 6,
  "lines: " & $ed.getLineCount()

echo "with image relays:"
drawRelays.loadImage = proc (path: string): Image =
  asked.add path
  Image(1)
drawRelays.freeImage = proc (img: Image) = discard
drawRelays.drawImage = proc (img: Image; src, dst: Rect) =
  inc painted
  lastSrc = src
  lastDst = dst
ed = drawDoc()
check "the picture is asked for", asked.len > 0,
  "loadImage was not called"
check "by the path the line names", asked.len > 0 and
  asked[0] == "screenshots/focim.png", "asked for: " & $asked
check "asked once and then cached", asked.len == 1, "asked " & $asked.len & " times"
check "and drawn", painted > 0
# A driver that cannot say how big a picture is gets asked the only way that
# is left: the source rectangle is the hole the picture is going into, and
# the driver crops. It is the wrong picture, and it is the best that can be
# asked for without `imageSize` -- which is why the next block exists.
check "a driver that cannot be asked its size is asked the old way",
  lastSrc.w == lastDst.w and lastSrc.h == lastDst.h,
  "src " & $lastSrc & " dst " & $lastDst

echo "with a driver that can say how big the picture is:"
# Smaller than the column it goes in, so there is one right answer and no
# rounding anywhere near it: a 40x20 picture is drawn 40x20. Stretching it to
# the width of the panel would be the old bug, and so would 40x120 -- the
# fixed six-line height that every picture used to get.
drawRelays.imageSize = proc (img: Image): tuple[w, h: int] = (40, 20)
painted = 0
ed = drawDoc()
check "the whole of it is asked for, in its own pixels",
  lastSrc == rect(0, 0, 40, 20), $lastSrc
check "a picture smaller than the column is drawn at its own size",
  lastDst.w == 40 and lastDst.h == 20, $lastDst

echo "and a picture too big for the column:"
drawRelays.imageSize = proc (img: Image): tuple[w, h: int] = (4000, 1000)
painted = 0
ed = drawDoc()
check "is brought down to fit it", lastDst.w < Area.w, $lastDst
check "keeping its shape", abs(lastDst.h - lastDst.w div 4) <= 1, $lastDst
check "and is still asked for whole", lastSrc == rect(0, 0, 4000, 1000),
  $lastSrc

if failures > 0: quit "FAILURE " & $failures & " check(s)"
echo "ALL PASS"
