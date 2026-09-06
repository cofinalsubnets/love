
type ('a, 'b) prod =
| Pair of 'a * 'b



val add : int -> int -> int

val mul : int -> int -> int

module Nat :
 sig
  val sub : int -> int -> int

  val leb : int -> int -> bool

  val divmod : int -> int -> int -> int -> (int, int) prod
 end

type byte = int

type reg = int

type op =
| Omov
| Oadd
| Osub
| Oand
| Oor
| Oxor
| Ocmp

val opcode : op -> byte

val rex : reg -> reg -> byte

val modrm : reg -> reg -> byte

val encode : op -> reg -> reg -> byte list

val all_ops : op list
