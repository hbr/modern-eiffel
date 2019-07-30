open Fmlib

type name =
  | Normal of string
  | Binary_operator of string * Operator.t


type t

val count: t -> int

val is_valid_index: int -> t -> bool

val index_of_level: int -> t -> int

val level_of_index: int -> t -> int

val string_of_name: name -> string


(** [type_at_level level c] type of the entry at [level]. *)
val type_at_level: int -> t -> Term.typ

val int_type: t -> Term.typ

val type_of_term: Term.t -> t -> Term.typ


(** [transfer c c1 t] transfer the term [t] from the context [c] into the
   context [c1] (requires that [c] is an initial segment of [c1]. *)
val transfer: t -> t -> Term.t -> Term.t


val name_of_level: int -> t -> name

val name_of_index: int -> t -> name

val term_at_level: int -> t -> Term.t

val standard: unit -> t

val compute: Term.t -> t -> Term.t

val push_local: string -> Term.typ -> t -> t



(** [push_arguments nargs tp c] treats [tp] as a function type with at least
   [nargs} arguments.

   It pushes the argument types of [tp] into the context [c] and returns the
   context with the arguments and the result type of the functions.

   Returns [None] of [tp] is not a function type with at least [nargs]
   arguments. *)
val push_arguments: int -> Term.typ -> t -> (t * Term.typ) option



(** [push_signature c1 nargs t c2] pushes the last [nargs] entries of [c1]
   into [c2] and transforms [t] into the new [c2].

   It is required that [c1] without the last [nargs] entries is an initial
   segment of [c2].  *)
val push_signature: t -> int -> Term.t -> t -> t * Term.t
  




val push_substitutable: Term.typ -> t -> t


(** [substitute_at_level i t c]. Substitute the variable at level [i] with the
   term [t] in the context [c].

   Precondition: It has to be a substitutable at level [i] which does not yet
   have any substitution.

*)
val substitute_at_level: int -> Term.t -> t -> t


val unify: Term.t -> Term.t -> t -> t option


val is_all_substituted: t -> bool

(** [substitution level t] *)
val substitution_at_level: int -> t -> Term.t




module Pretty:
functor (P:Pretty_printer.SIG) ->
sig
  val print: Term.t -> t -> P.t
end

val string_of_term: Term.t -> t -> string
