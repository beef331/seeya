when not defined(gcOrc) or defined(gcArc):
  {.error: "This module only works for Arc and Orc".}

## This module implements a primitive API to expose Nim code as a C header.
## It makes many assumptions based off my understanding of Nim's ABI.
## To use it simply annotate a procedure or global variable with `{.exportc, dynlib, expose.}`
## Most Nim builtin types are supported with the default hooks.
## If a type you want to use does not work create a `proc toTypeDefs(T: typedesc[YourType]): string`.
## This type populates the typedefs and adds any required headers
## In the case you need headers you should include them by doing `headers.incl theHeader`.
## For all children fields call `addType(ChildType)`.
## That will append that type and add it to a type cache to prevent it from adding the typedef again.
## Next you likely also will need to write your own `proc toCtype(T: typedesc[YourType], name: string, procArg: bool): string`.
## That callback should return the C type for your type.
## `name` is the name of the parameter or variable that it was told to generate.
## `procArg` indicates whether it is a proc argument, this is important for things like Nim's implicit pass by reference.
## Finally when done you can do `makeHeader("/path/to/header.h")` this will concatenate and make the final header.

runnableExamples:
  when defined(genHeader):
    {.warning[UnsafeDefault]: off.}

  const nameStr = "your_lib_prefix_$1"

  static:
    setFormatter(nameStr)

  {.pragma: exporter, cdecl, dynlib, exportc: nameStr.}
  {.pragma: exporterVar, dynlib, exportc: nameStr.}

  proc print_int_arr(oa: openArray[int]) {.exporter, expose.} =
    echo oa

  proc add_int(a, b: int): int {.exporter, expose.} =
    a + b

  var my_int {.exporterVar, expose.} = 100

  type
    MyEnum = enum
      a
      b
      c

  proc toTypeDefs(_: typedesc[MyEnum]): string =
    headers.incl "<stdio.h>" # Pretend it requires a specific header
    seeya.toTypeDefs(MyEnum) # call the original enum generator

  proc toCType(_: typedesc[MyEnum], name: string, isProcArg: bool): string =
    # We're also pretending we need to make our own C type proc
    result = "enum "
    result.add ($MyEnum).formatName()
    result.add " "
    result.add name

  makeHeader("mylib.h")
  when defined(genHeader):
    static:
      discard staticExec("clang-format -i mylib.h")

import
  std/[
    macros, sets, strutils, hashes, genasts, strformat, os, math, typetraits, enumerate
  ]
import pkg/micros/introspection
export sets

static: # Use module block
  discard GenAstOpt.kDirtyTemplate
  discard hash(0)

const nimcallStr = when defined(windows): "fastcall" else: ""

type
  OpaqueSeq*[T] = distinct seq[T]
    ## Opaque seqs do not emit their entire struct, just the top level one.
  OpaqueString* = distinct string
    ## Opaque seqs do not emit their entire struct, just the top level one.
  OpaqueRef*[T: ref or ptr] {.borrow: `.`.} = distinct T
    ## Opaque refs do not emit any fields just a `typedef` `void*`.

  Passes* = enum
    Inferred
    PassesByRef
    PassesByCopy

  CallConv {.used.} = enum
    Nimcall = nimCallStr
    Closure
    Cdecl = ""
    StdCall = "stdcall"
    SafeCall = "safecall"
    SysCall = "syscall"
    FastCall = "fastcall"
    NoConv = ""

proc passType(typImpl: NimNode): Passes =
  for node in typImpl:
    if node.kind == nnkPragma:
      for child in node:
        if child.kind in {nnkSym, nnkIdent}:
          if child.eqIdent"byRef":
            return PassesByRef
          elif child.eqIdent"byCopy":
            return PassesByCopy
    else:
      result = passType(node)
      if result != Inferred:
        return

macro passConvention(obj: object): untyped =
  let
    typ =
      if obj.getTypeInst().kind == nnkBracketExpr:
        obj[0]
      else:
        obj.getTypeInst()
  newLit passType typ.getImpl()

proc passesByRef*(T: typedesc[object]): bool =
  const conv = passConvention(default(T))
  conv == PassesByRef or (conv == Inferred and sizeof(default(T)) >= sizeof(float) * 3)

var
  headers* {.compileTime, used.}: HashSet[string]
  typeDefs {.compileTime, used.} = ""
  procDefs {.compileTime, used.} = ""
  variables {.compileTime, used.} = ""
  generatedTypes {.compileTime, used.}: HashSet[string]

macro makeHeader*(location: static string) =
  when defined(genHeader):
    var file = ""
    for header in headers:
      file.add fmt "#include {header}\n"
    file.add "\n"

    file.add typeDefs
    file.add variables
    file.add "\n"
    file.add procDefs

    writeFile(location, file)
  else:
    discard

proc myGetType(T: typedesc): NimNode =
  let typ = T.getTypeInst()
  if typ.len > 1 and typ[1].typeKind == ntyVar:
    typ[1]
  else:
    typ

proc addType*(T: typedesc) =
  mixin toTypeDefs

  if T.myGetType().repr notin generatedTypes:
    generatedTypes.incl T.myGetType().repr
    typedefs.add toTypeDefs(T)

var exposeFormatter {.compileTime.} = "$1"
proc formatName*(s: string): string =
  exposeFormatter.replace("$1", s)

proc setFormatter*(formatter: static string) {.compileTime.} =
  when "$1" notin formatter:
    {.error: "Formatter does not contain '$1' so cannot be used.".}
  exposeFormatter = formatter

when defined(genHeader):
  proc genTypeDefCall(typ: NimNode): NimNode =
    if typ.repr notin generatedTypes:
      genAst(typ):
        static:
          addType(typeof typ)
    else:
      newEmptyNode()

  proc genProcCall(typ, name: Nimnode, isLast: bool, isRetVal: bool = false): NimNode =
    let
      name =
        if name.kind == nnkEmpty:
          ""
        else:
          $name
      typ =
        if typ.typeKind == ntyVar:
          nnkPtrTy.newTree typ[0]
        else:
          typ
    genAst(typ, isLast, name, isRetVal):
      static:
        procDefs.add typ.toCType(name, true and not(isRetVal))
        procDefs.add " "
        if not isLast:
          procDefs.add ", "

  proc getComments(node: NimNode, result: var string) =
    for child in node:
      if child.kind == nnkCommentStmt:
        if result.len == 0:
          result.add "\n"
        result.add "// "
        result.add child.strVal.replace("\n", "\n// ")
        result.add "\n"
      else:
        getComments(child, result)

  proc getComments(name: NimNode): string =
    getComments(name.getImpl, result)

  proc getCallingConvention(name: NimNode): CallConv =
    let impl = name.getImpl()
    result = Nimcall
    for conv in impl[4]:
      if conv.kind == nnkIdent:
        if conv.eqIdent"nimcall":
          warning(
            "Exposing a `nimcall`'d procedure, this uses a different convention on windows than *nix.",
            name
          )
          return Nimcall
        elif conv.eqIdent"cdecl":
          return Cdecl
        elif conv.eqIdent"noConv":
          return NoConv
        elif conv.eqIdent"stdcall":
          return StdCall
        elif conv.eqIdent"fastcall":
          return FastCall
        else:
          for convStr in ["inline", "closure"]:
            if conv.eqIdent(convStr):
              error(
                "Cannot expose procedure with " & $conv & " calling convention", name
              )

  proc ensureExported(name: NimNode) =
    var
      isExportcd: bool
      isDynlib: bool
    for prag in name.getImpl()[4]:
      let
        prag =
          if prag.kind != nnkIdent:
            prag[0]
          else:
            prag
      isExportcd = isExportcd or prag.eqIdent"exportc"
      isDynLib = isDynLib or prag.eqIdent"dynlib"
    if not (isDynLib) or not (isExportcd):
      error("Procedure should be marked '{.exportc, dynlib.}'", name)

  proc exposeProc(name, impl: NimNode): NimNode =
    let comments = name.getComments()
    ensureExported(name)
    result = newStmtList()
    result.add:
      genast(comments):
        static:
          procDefs.add comments
    for i, x in impl[0]:
      if i == 0:
        if x.kind != nnkEmpty:
          result.add genTypeDefCall(x)
          result.add genProcCall(x, newEmptyNode(), true, true)
        else:
          result.add:
            genast:
              static:
                procDefs.add "void"
        result.add:
          genast(name = formatName($name), conv = $name.getCallingConvention()):
            static:
              procDefs.add " "
              when conv.len > 0:
                procDefs.add "__attribute(("
                procdefs.add conv
                procdefs.add")) "
              procDefs.add name
              procDefs.add "("
      else:
        result.add genTypeDefCall(x[^2])
        result.add genProcCall(x[^2], x[0], i == impl[0].len - 1)

    result.add:
      genast:
        static:
          procDefs.add ");\n"

  proc exposeVar(name, impl: NimNode): NimNode =
    result = newStmtList()
    result.add:
      genast(obj = name, impl, name = formatName($name)):
        static:
          addType(typeof obj)
          variables.add "extern "
          variables.add toCType(typeof(obj), name, false)
          variables.add ";\n"

  macro expose*(prc: typed): untyped =
    let
      name =
        case prc.kind
        of nnkProcDef:
          prc[0]
        of nnkSym:
          if prc.symKind notin {nskProc, nskVar}:
            prc
          else:
            error("Expected proc or var symbol", prc)
            return
        of nnkVarSection, nnkLetSection:
          let name = prc[0][0]
          if name.kind == nnkPragmaExpr:
            name[0]
          else:
            name
        else:
          error("Expected proc definition or variable", prc)
          return

      impl = name.getTypeInst()

    if prc.kind == nnkProcDef:
      result = exposeProc(name, impl)
    else:
      result = exposeVar(name, impl)
    result.add prc.copyNimTree()

else:
  macro expose*(t: untyped): untyped =
    t

proc toCName*(s: string): string =
  ## Converts a Nim type to a "valid" C identifier
  ## Uses simple replace dumb as hell
  result = s.multiReplace({
      "[": "_",
      ", ": "_",
      "]": "_",
      ".": "_"}
    ).split(":")[0]
  result = result.strip(false, true, {'_'})


proc toTypeDefs*(T: typedesc[object]): string =
  mixin toCType, toTypeDefs
  for field in default(T).fields:
    typeof(field).addType()

  generatedTypes.incl T.getTypeInst().repr

  result.add "struct "
  result.add formatName(($T).toCName)
  result.add " {\n"
  for name, field in default(T).fieldPairs:
    result.add "    "
    result.add typeof(field).toCType(name.toCName(), false) # ugly
    result.add ";\n"
  result.add "};\n\n"

proc toCType*(T: typedesc[object], name: string, procArg: bool): string =
  mixin toCtype
  result.add "struct "
  result.add formatName(($T).toCName())
  result.add " "
  if T.passesByRef() and procArg:
    result.add "*"
  result.add name

proc tupleName(T: typedesc[tuple]): string =
  result = "tuple"
  for field in default(T).fields:
    result.add "_"
    result.add ($typeof(field)).toCName()

proc toTypeDefs*(T: typedesc[tuple]): string =
  mixin toCType
  for field in default(T).fields:
    typeof(field).addType()

  generatedTypes.incl T.getTypeInst().repr

  result.add "struct "
  result.add formatName(tupleName(T))
  result.add " {\n"

  for name, field in default(T).fieldPairs:
    result.add "    "
    let
      newName =
        if name[0] in UppercaseLetters:
          var tmp = name
          tmp[0] = tmp[0].toLowerAscii()
          tmp
        else:
          name
    result.add typeof(field).toCType(newName, false)
    result.add ";\n"
  result.add "};\n\n"

proc toCType*[T: tuple](t: typedesc[T], name: string, procArg: bool): string =
  result.add "struct "
  result.add formatName(tupleName(T))
  result.add " "
  result.add name

proc toTypeDefs*[T: not (object or distinct or tuple or enum)](_: typedesc[T]): string =
  ""

proc toTypeDefs*[T: distinct](_: typedesc[T]): string =
  addType(T.distinctBase)
  toTypeDefs(T.distinctBase)

proc toCType*[T: distinct](_: typedesc[T], name: string, procArg: bool): string =
  addType(T.distinctBase)
  toCType(T.distinctBase, name, procArg)

type PtrOrRef[T] = ptr [T] or ref [T]

proc toCType[T](_: typedesc[UncheckedArray[T]], name: string, procArg: bool): string =
  addType(T)
  result.add toCtype(T, " ", false)

proc toCType*[T](_: typedesc[PtrOrRef[T]], name: string, procArg: bool): string =
  addType(T)
  result.add toCType(T, "", false)
  result.add "*"
  result.add name

proc toCType*(_: typedesc[cstring], name: string, procArg: bool): string =
  "char* " & name

proc toCType*[Idx, T](_: typedesc[array[Idx, T]], name: string, procArg: bool): string =
  addType(T)
  result.add toCType(T, name, false)
  result.add "["
  result.add $(Idx.high.ord - Idx.low.ord)
  result.add "]"

proc toCType*[T](_: typedesc[set[T]], name: string, procArg: bool): string =
  const size = ceil((T.high.ord - T.low.ord) / 8).int
  when size <= 1:
    toCType(uint8, name, false)
  elif size <= 2:
    toCType(uint16, name, false)
  elif size <= 4:
    toCType(uint32, name, false)
  elif size <= 8:
    toCType(uint64, name, false)
  else:
    toCType(array[size + 1, uint8], name, false)

proc toCType*[T: SomeInteger](_: typedesc[T], name: string, procArg: bool): string =
  headers.incl "<stdint.h>"
  when T is (int or BiggestInt):
    "intptr_t " & name
  elif T is (uint or BiggestUInt):
    "uintptr_t " & name
  elif T is byte:
    "uint8_t " & name
  else:
    $T & "_t " & name

macro getRangeBase(t: typed): untyped =
  newCall("typeof", t.getType()[^1][1])

proc toCType*[T: range](_: typedesc[T], name: string, procArg: bool): string =
  toCType(getRangeBase(T), name, false)

proc toCType*[T](_: typedesc[openArray[T]], name: string, procArg: bool): string =
  addType(T)
  result.add toCType(ptr T, name & "_data", false)
  result.add ", "
  result.add toCType(int, name & "_len", false)

proc toTypeDefs*[T](_: typedesc[seq[T]]): string =
  addType(T)
  addType(int)
  let dataName = formatName("seq_data_" & ($T).toCName)
  result.add "struct "
  result.add dataName
  result.add "{\n"
  result.add "    "
  result.add toCType(int, "capacity", false)
  result.add ";\n    "
  result.add toCType(T, "data", false)
  result.add "[];"
  result.add "};\n\n"

  let structName = formatName("seq_" & ($T).toCName)
  result.add "struct "
  result.add structName
  result.add "{\n"
  result.add "    "
  result.add toCType(int, "len", false)
  result.add ";\n    "

  result.add "struct "
  result.add dataName
  result.add " *data;\n};\n\n"

proc toCType*[T](_: typedesc[seq[T]], name: string, procArg: bool): string =
  result = "struct " & formatName(("seq_" & $T).toCName())
  result.add " "
  result.add name

proc toTypeDefs*(_: typedesc[string]): string =
  addType(char)
  addType(int)
  let dataName = formatName("string_data")
  result.add "struct "
  result.add dataName
  result.add "{\n"
  result.add "    "
  result.add toCType(int, "capacity", false)
  result.add ";\n    "
  result.add toCType(char, "data", false)
  result.add "[];"
  result.add "};\n\n"

  let structName = formatName("string")
  result.add "struct "
  result.add structName
  result.add "{\n"
  result.add "    "
  result.add toCType(int, "len", false)
  result.add ";\n    "

  result.add "struct "
  result.add dataName
  result.add " *data;\n};\n\n"

proc toCType*(_: typedesc[string], name: string, procArg: bool): string =
  result = "struct " & formatName("string")
  result.add " "
  result.add name

proc toCType*[T: float or float64](_: typedesc[T], name: string, procArg: bool): string =
  "double " & name

proc toCType*(_: typedesc[float32], name: string, procArg: bool): string =
  "float " & name

proc toCType*(_: typedesc[bool], name: string, procArg: bool): string =
  headers.incl "<stdbool.h>"
  "bool " & name

proc toCType*(_: typedesc[char], name: string, procArg: bool): string =
  "char " & name

proc toTypeDefs*[T](_: typedesc[OpaqueRef[T]]): string =
  when T.getType notin generatedTypes:
    result = "struct "
    result.add ("opaque_" & $T).toCName.formatName
    result.add ";\n\n"
    generatedTypes.incl T.getType()


proc toCType*[T](_: typedesc[OpaqueRef[T]], name: string, isProcArg: bool): string =
  result = "struct "
  result.add ("opaque_" & $T).toCName.formatName()
  result.add "* "
  result.add name

proc toTypeDefs*(_: typedesc[OpaqueString]): string =
  addType(int)
  result = "struct "
  result.add formatName"opaque_string"
  result.add "{intptr_t len; void* data;};\n"

proc toCType*(_: typedesc[OpaqueString], name: string, isProcArg: bool): string =
  result = "struct "
  result.add formatName"opaque_string"
  result.add " "
  result.add name

proc toTypeDefs*[T](_: typedesc[OpaqueSeq[T]]): string =
  addType(int)
  result = "struct "
  result.add ("opaque_seq_" & ($T).toCName).formatName()
  result.add "{intptr_t len; void* data;};\n"

proc toCType*[T](_: typedesc[OpaqueSeq[T]], name: string, isProcArg: bool): string =
  result = "struct "
  result.add ("opaque_seq_" & ($T).toCName).formatName()
  result.add " "
  result.add name

macro getEnumNames(t: typed): untyped =
  result = nnkBracket.newTree()
  for node in t.getTypeImpl()[1..^1]:
    result.add nnkTupleConstr.newTree(newLit $node, newCall("ord", node))

proc toTypeDefs*[T: enum](_: typedesc[T]): string =
  result.add "enum "
  result.add formatName($T)
  result.add " {\n"
  const nameVal = default(T).getEnumNames()
  for i, (name, val) in nameVal:
    result.add "   "
    result.add formatName(name)
    result.add " = "
    result.add $val
    if i != nameVal.high:
      result.add ",\n"
    else:
      result.add "\n"
  result.add "};\n\n"

proc toCType*[T: enum](_: typedesc[T], name: string, procArg: bool): string =
  addType(T)
  "enum " & formatName($T) & " " & name

proc toTypeDefs*(T: typedesc[proc]): string =
  let p = default(T)
  when compiles(addType p.returnType()):
    addType p.returnType()
  when tupleLen(p.paramsAsTuple()) > 0:
    let tup = default(p.paramsAsTuple())
    for field in tup.fields:
      addType typeof(field)

proc toCType*(T: typedesc[proc], name: string, procArg: bool): string =
  let p = default(T)
  when compiles(p.returnType().toCType("", true)):
    result = p.returnType().toCType("", true)
  else:
    result = "void"
  result.add "(*"
  result.add name
  result.add ")("
  when tupleLen(p.paramsAsTuple()) > 0:
    let tup = default(p.paramsAsTuple())
    for i, field in enumerate tup.fields:
      result.add field.typeof.toCtype("", true)
      if i < tup.tupleLen - 1:
        result.add ", "
  result.add ")"

when isMainModule:
  when defined(genHeader):
    {.warning[UnsafeDefault]: off.}

  const nameStr = "test_$1"

  static:
    setFormatter(nameStr)

  {.pragma: exporter, cdecl, dynlib, exportc: nameStr.}
  {.pragma: exporterVar, dynlib, exportc: nameStr.}

  type
    MyInt = distinct int

    MyType = object
      x, y: int
      z: float

    MyRange = range[3u8..5u8]
    Color = enum
      red
      green
      blue
      yellow
      orange
      purple
      indigo

    MyOtherType = object
      x, y: uint8
      z: float
      u: ref MyType
      a: MyType
      dist: MyInt
      bleh: set[char]
      meh: set[0..16]
      hmm: set[Color]
      test: array[Color, MyType]
      color: Color
      blerg: (int, int, float, bool)
      rng: MyRange
      otherRange: range[3u32..5u32]

    MyRef = ref object
      child: MyRef

    Base = object of RootObj
      x: int

    Child = ref object of Base
      y: float

  proc bleh() {.noconv, exportc: nameStr, dynlib, expose.} =
    discard

  proc doThing(
      oa: openArray[int],
      otherOa: openArray[cstring],
      typ: MyOtherType,
      a, b: seq[float32],
  ): cstring {.exporter, expose.} =
    discard

  proc doOtherThing(s: string) {.exporter, expose.} =
    discard

  proc doThingy(i: var int) {.exporter, expose.} =
    discard

  proc doOtherStuff(r: MyRef) {.exporter, expose.} =
    discard

  var myGlobal {.exporterVar, expose.} = MyOtherType(rng: 3, otherRange: 3)
  var inheritance {.exporterVar, expose.} = Child(x: 300)
  makeHeader("tests/gend.h")
  when defined(genHeader):
    static:
      discard staticExec("clang-format -i tests/gend.h")
