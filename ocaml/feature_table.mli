open Support
open Term
open Signature

type t

type implementation_status = No_implementation | Builtin | Deferred

val count:      t -> int

val implication_index: int
val all_index:         int
val some_index:        int

val base_table: unit -> t

val module_table: t -> Module_table.t
val class_table:  t -> Class_table.t

val implication_term: term -> term -> int -> t -> term

val expand_term: term->int->t->term
  (** [expand_term t nbound ft] expands the definitions of the term [t] within
      an environment with [nbound] bound variables, i.e. a variable [i] with
      [nbound<=i] refers to the global feature [i-nbound] *)


val normalize_term: term->int->t->term
  (** [normalize_term t nbound ft] expands the definitions of the term [t] and
     beta reduce it within an environment with [nbound] bound variables,
     i.e. a variable [i] with [nbound<=i] refers to the global feature
     [i-nbound] *)


val find_funcs: feature_name -> int -> t -> (int * TVars.t * Sign.t) list

val put_function:
    feature_name withinfo -> (int*type_term) array -> int array
      -> Sign.t -> implementation_status -> term option -> t -> unit

val term_to_string: term -> int array -> t -> string

val print: t -> unit

