import ../seeya

when defined(genHeader):
  {.warning[UnsafeDefault]: off.}

const nameStr = "mylib_$1"

static:
  setFormatter(nameStr)
  codeFormatter = "clang-format -i $file"
{.pragma: exporter, cdecl, dynlib, exportc: nameStr.}
{.pragma: exporterVar, dynlib, exportc: nameStr.}

type
  MyObj = ref object
    a: int
    b: string

proc hello_world(msg: cstring) {.exporter, expose.} =
  ## This prints the string passed in
  echo $msg

proc do_thing(a, b: int): int {.exporter, expose.} =
  ## This is just simple math
  a + b

proc join(a, b: cstring): string {.exporter, expose.} =
  ## This joins two cstrings and returns a Nim string
  $a & $b

proc free_string(s: string) {.exporter, expose.} =
  ## This frees the Nim string
  `=destroy`(s)

proc new_my_obj(i: int): MyObj {.exporter, expose.} =
  ## This allocates an object and sets the b field to a Nim string of i
  MyObj(a: i, b: $i)

proc free_my_obj(obj: MyObj) {.exporter, expose.} =
  ## This frees `obj`
  `=destroy`(obj)

proc free_float_seq(s: seq[float]) {.exporter, expose.} =
  ## This frees `obj`
  `=destroy`(s)

proc new_float_seq(data: openArray[float]): seq[float] {.exporter, expose.} = @data

proc float_seq_cmp(a, b: seq[float]): bool {.exporter, expose.} = a == b

proc doStuff[T](obj: T): T {.cdecl.} =
  echo obj
  obj

let
  do_stuff_int {.exporterVar, expose.} = doStuff[int]
  do_stuff_float {.exporterVar, expose.} = doStuff[float]
  do_stuff_seq_float {.exporterVar, expose.} = doStuff[seq[float]]

static: makeHeader("tests/mylib.h")
