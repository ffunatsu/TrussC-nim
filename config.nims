import std/strutils
import std/strformat
import std/strtabs
import std/macros
import std/os
# import std/private/ospaths2
from std/sequtils import toSeq

const projectRoot = parentDir(system.currentSourcePath)

var detectedMainNim = ""
var i = paramCount()
while i >= 1:
  let p = paramStr(i)
  if p.len > 0 and p[0] != '-' and p.toLowerAscii().endsWith(".nim"):
    detectedMainNim = p
    break
  i = i - 1

let mainNimRelPath = detectedMainNim

# Ensure required library folders exist; if missing, instruct user to run installer scripts.
proc requireDirs(dirs: seq[string], hintCmd: string) =
  for d in dirs:
    let p = joinPath(projectRoot, d)
    if not dirExists(p):
      let newline = "\n"
      quit(fmt"[Error] {p} not found.{newline}Please run: {hintCmd} to install the libraries and retry.{newline}")

proc where(cmd: string): bool =
  when defined(windows):
    var result = gorgeEx(fmt"where.exe {cmd}")
    return result[1] == 0
  else:
    var result = gorgeEx(fmt"which {cmd}")
    return result[1] == 0

when defined(windows):
  # check clang-cl exists
  if not where("clang-cl"):
    quit("[Error] clang-cl not found. Please install LLVM/Clang via Visual Studio Installer and ensure clang-cl is in your PATH (and ensure you're using Native Tools Command Prompt for VS).")

when defined(windows):
  requireDirs(@["lib\\vs"], ".\\scripts\\init_win.ps1")
elif defined(macosx):
  requireDirs(@["lib/osx"], "./scripts/init_mac.sh")

switch("backend", "cpp")

when defined(windows):
  const use_vcc = false
  if use_vcc:
    switch("cc", "vcc")
  else:
    switch("cc", "clang_cl")
  switch("passC", "/INCREMENTAL")
  switch("passC", "/std:c++20")
  switch("passC", "/utf-8")
  switch("passC", "/MD")
  if use_vcc:
    switch("passC", "/MP")
  switch("passC", "/DWIN32_LEAN_AND_MEAN")
  switch("passC", "/DFAR=")
  switch("passC", "/DNOMINMAX")
else:
  switch("passC", "-std=c++20")
  switch("cpp.options.always", "-std=c++20")

switch("path", "src")
switch("passC", "-Iinclude")
switch("passC", "-Ihap")

# https://stackoverflow.com/a/67173508/2696422
macro includeNims(
  arg: static[string]): untyped =
  # ^ To pass value to macro use `static[<your-type>]`

  newTree(nnkIncludeStmt, newLit(arg))
  # Generates `include "your string"`

const addons_nims_path = joinPath(projectRoot, "addons.nims")
includeNims(addons_nims_path)
# include "addons.nims"

# load xxx.nim.addons
let preferredAddons = selectAddonsFile(projectRoot, mainNimRelPath)
if preferredAddons.len > 0:
  let localAddonsDir = joinPath(projectRoot, "addons")
  if dirExists(localAddonsDir):
    processAddons(preferredAddons, localAddonsDir, projectRoot)
  else:
    let nl = "\n"
    quit(fmt"[Error] addons file found: {preferredAddons}{nl}but addons directory not present: {localAddonsDir}{nl}Create the directory or remove the addons file and retry.{nl}")

when defined(windows):
  switch("passL", "lib\\vs\\x64\\TrussC.lib")
elif defined(macosx):
  switch("passL", "lib/osx/libTrussC.a")
  switch("passL","-framework Metal")
  switch("passL","-framework MetalKit")
  switch("passL","-framework Cocoa")
  switch("passL","-framework ImageIO")
  switch("passL","-framework QuartzCore")
  switch("passL","-framework AudioToolbox")
  switch("passL","-framework AVFoundation")
  switch("passL","-framework CoreMedia")
  switch("passL","-framework CoreVideo")
  switch("passL","-framework CoreAudio")
  switch("passL","-framework IOKit")
  switch("passL","-framework CoreDisplay")
  switch("passL","-framework CoreLocation")
  switch("passL", "-lobjc")
  switch("passL", fmt"-rpath {projectRoot}/lib/osx")
