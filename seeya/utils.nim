import ../seeya
import std/[macros, genasts]

macro genHelpers*(typ: typedesc[seq], formatter: static string): untyped =
  let name = ("seq_" & typ[1].repr.toCName()).formatName()
  genast(
    typ,
    T = typ[1],
    formatter = newLit formatter,
    destroyName = ident(name & "_destroy"),
    indexName = ident(name & "_index"),
    indexMutName = ident(name & "_index_mutable"),
    asgnName = ident(name & "_assign_index"),
    cmpName = ident(name & "_cmp"),
  ):
    proc destroyName(
        the_seq {.inject.}: typ
    ) {.exportc: formatter, dynlib, cdecl, expose.} =
      ## Destroys the sequence should only be called once
      `=destroy`(the_seq)

    proc indexName(
        the_seq {.inject.}: typ, ind {.inject.}: int
    ): T {.exportc: formatter, dynlib, cdecl, expose.} =
      ## Indexes the sequence
      the_seq[ind]

    proc indexMutName(
        the_seq {.inject.}: var typ, ind {.inject.}: int
    ): ptr T {.exportc: formatter, dynlib, cdecl, expose.} =
      ## Indexes the sequence returning a mutable reference
      the_seq[ind].addr

    proc asgnName(
        the_seq {.inject.}: var typ, ind {.inject.}: int, val {.inject.}: T
    ) {.exportc: formatter, dynlib, cdecl, expose.} =
      ## Assigns the value at an index
      the_seq[ind] = val

    proc cmpName(
        a {.inject.}, b {.inject.}: typ
    ): bool {.exportc: formatter, dynlib, cdecl, expose.} =
      ## Compares two sequences
      a == b

macro genHelpers*(typ: typedesc[OpaqueSeq], formatter: static string): untyped =
  let name = "opaque_seq_" & typ[1].repr.toCName()
  genast(
    typ,
    T = typ[1],
    formatter = newLit formatter,
    destroyName = ident(name & "_destroy"),
    indexName = ident(name & "_index"),
    indexMutName = ident(name & "_index_mutable"),
    asgnName = ident(name & "_assign_index"),
    cmpName = ident(name & "_cmp"),
  ):
    proc destroyName(
        the_seq {.inject.}: typ
    ) {.exportc: formatter, dynlib, cdecl, expose.} =
      ## Destroys the sequence should only be called once
      `=destroy`(seq[T](the_seq))

    proc indexName(
        the_seq {.inject.}: typ, ind {.inject.}: int
    ): T {.exportc: formatter, dynlib, cdecl, expose.} =
      ## Indexes the sequence
      seq[T](the_seq)[ind]

    proc indexMutName(
        the_seq {.inject.}: var typ, ind {.inject.}: int
    ): ptr T {.exportc: formatter, dynlib, cdecl, expose.} =
      ## Indexes the sequence returning a mutable reference
      seq[T](the_seq)[ind].addr

    proc asgnName(
        the_seq {.inject.}: var typ, ind {.inject.}: int, val {.inject.}: T
    ) {.exportc: formatter, dynlib, cdecl, expose.} =
      ## Assigns the value at an index
      seq[T](the_seq)[ind] = val

    proc cmpName(
        a {.inject.}, b {.inject.}: typ
    ): bool {.exportc: formatter, dynlib, cdecl, expose.} =
      ## Compares two sequences
      seq[T](a) == seq[T](b)
