# Package

version       = "0.8.4"
author        = "Araq"
description   = "Focim -- the Focussed Nim Editor: a code editor with an integrated terminal, laid out and colored by a config file that is one of its own tabs"
license       = "MIT"
srcDir        = "src"
bin           = @["focim"]

# Dependencies

requires "nim >= 2.0.0"
# The UI library focim grew up in: windows, fonts, drawing and input, with a
# native driver per platform.
requires "https://github.com/nim-lang/uirelays >= 0.11.0"
# One PNG in, every icon artifact a desktop application ships out. `icons`
# below makes the build inputs with it and `bundle` hands the built editor to
# the desktop; the release workflow uses it for both.
requires "https://github.com/Araq/iconbundler >= 0.1.0"
# Decoding a PNG is not a driver's job -- see `src/focim/images.nim`, which
# fills in the image relays over the one thing the driver does offer for it.
# PNG, JPEG, GIF, BMP, QOI and SVG all arrive with this, and the scaling that
# makes a photo fit a column arrives with it too.
requires "pixie >= 6.1.0"
# The first two are not on the Nimble package list yet, hence the URLs.

const
  IconArt = "src/focim-icon.png"
    ## The source art. Everything below is derived from this one file.
  IconInputs = ["src/focim-icon.netwm", "src/focim.ico", "src/focim.rc",
                "src/focim.res"]
    ## What `iconbundler --prepare` writes next to it: the `_NET_WM_ICON` blob
    ## `focim.nim` `staticRead`s for X11, and the Windows icon, resource script
    ## and linkable object behind `{.link: "focim.res".}`.
    ##
    ## They are checked in, and `icons` is what remakes them -- deliberately
    ## not every build. They are inputs to the compiler, so a machine without
    ## ImageMagick still has to be able to compile; and two image tools do not
    ## resample a PNG to the same bytes, so remaking them on every build would
    ## rewrite files that nobody changed.

proc iconbundler(args: string) =
  let exe = findExe("iconbundler")
  if exe.len == 0:
    quit "iconbundler not found. It is a dependency, so `nimble install` has " &
         "it; what is missing then is ~/.nimble/bin on PATH."
  exec "\"" & exe & "\" " & args


task icons, "Remake the icon files in src/ after changing the source art":
  iconbundler "--prepare focim " & IconArt

task bundle, "Build focim and hand it to the desktop: menu entry, icon, .app":
  exec "nimble build -d:release"
  const exe = when defined(windows): "focim.exe" else: "./focim"
  iconbundler "focim " & exe & " " & IconArt &
    " --name focim --generic-name \"Text Editor\"" &
    " --comment \"Focussed Nim Editor\"" &
    " --categories \"Development;TextEditor;\"" &
    " --bundle-id org.nim-lang.focim"

task test, "Run the test suite":
  exec "nim c -r tests/tester.nim"


before build:
  # A build does need the derived files -- the compiler reads three of them --
  # so a checkout that is missing one gets it made rather than a compiler
  # error about a file that was never in anyone's editor.
  var missing = false
  for f in IconInputs:
    if not fileExists(f): missing = true
  if missing:
    iconbundler "--prepare focim " & IconArt
