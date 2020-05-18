open Fmlib


type t

val count: t -> int

val gamma: t -> Gamma.t
val name_map: t -> Name_map.t

val empty: t
val standard: unit -> t

val find_name: string -> t -> int list

val compute: Term.t -> t -> Term.t

val push_local: string -> Term.typ -> t -> t

val add_builtin_type: string -> string -> Term.typ -> t -> t

val add_definition: string -> Term.typ -> Term.t -> t -> (t, int) result


module Pretty (P:Pretty_printer.SIG):
sig
  val print: Term.t -> t -> P.t
end
