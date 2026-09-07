## The test suite. Every test here is a program that needs no window: the
## drawing path is watched through stub relays, so what is checked is what the
## editor decided, not what a driver painted. `nim c -r tests/tester.nim`, or
## `nimble test`.

import std/[os, strutils]

proc fatal(msg: string) = quit "FAILURE " & msg

proc exec(cmd: string) =
  if execShellCmd(cmd) != 0: fatal cmd

# The config parser and the markdown one need no font, so they go first.
exec "nim c -r tests/configtest.nim"
# And the directory that config is kept in, which needs no font either -- it
# points the config dir at a temporary one, so it touches nothing of yours.
exec "nim c -r tests/configstoretest.nim"
exec "nim c -r tests/markdowntest.nim"
# And a markdown image line on a backend with no image relays -- which is what
# X11 is, so this is the ordinary Linux case and not a corner of one.
exec "nim c -r tests/mdimagetest.nim"
# And the same line on a backend that has a surface but no decoder, which is
# also what X11 is: the picture is decoded and scaled here and handed over as
# pixels. The arithmetic that flattens transparency is checked a pixel at a
# time, because a relay that drew nothing looks the same from outside as one
# that drew the picture.
exec "nim c -r tests/pixieimagetest.nim"
# Bold and italics reach the drawing path through stub relays.
exec "nim c -r tests/styletest.nim"
# The word index needs no font until something draws with it.
exec "nim c -r tests/wordindextest.nim"
# The clipboard is a relay, so the test can hold the text itself.
exec "nim c -r tests/cliphistorytest.nim"
# Search and replace is a walk over a buffer; nothing there draws either.
exec "nim c -r tests/searchtest.nim"
# A highlighter's output is token classes, which are colorless until a theme
# gets them -- so the console one is tested without a window as well.
exec "nim c -r tests/consoletest.nim"
# Line wrapping is what the drawing path does with a line that is too long,
# so it is watched through the same stub relays as the font styles.
exec "nim c -r tests/wraptest.nim"
# Where the caret may go in a terminal, and what a key means where it stands.
exec "nim c -r tests/terminaltest.nim"
# And that the row the caret is on is the row that gets the band.
exec "nim c -r tests/activelinetest.nim"
# Everything around asking a compiler where a name is -- but not the compiler,
# which is not something a test may assume is installed.
exec "nim c -r tests/tracktest.nim"
# And what `open <name>` does with a name that is missing most of its path.
exec "nim c -r tests/filesearchtest.nim"
# That a rune of more than one byte is one character to every key that steps
# over it, and that a byte belonging to no rune stands for itself.
exec "nim c -r tests/utf8test.nim"
# The colors a program asks for with escape sequences, and the disappearance
# of everything else it asks for.
exec "nim c -r tests/ansitest.nim"
# And that the tab list goes and shows the tab the editor made current, which
# is a scroll nothing in the list itself ever asked for.
exec "nim c -r tests/tablisttest.nim"
# Two panels on one buffer: that neither shows anything of the other, and that
# a caret is carried along by an edit made through the other one.
exec "nim c -r tests/viewtest.nim"
# The names panels go by, and the list of them the layout dictates.
exec "nim c -r tests/panelstest.nim"

# The editor itself, once, with the platform's default backend -- the one
# thing here that pulls in a driver, and so the one thing that would notice a
# uirelays that moved on without focim.
exec "nim c --outdir:testArtifacts --hints:off src/focim.nim"
