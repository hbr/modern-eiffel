(* Copyright (C) Helmut Brandl  <helmut dot brandl at gmx dot net>

   This file is distributed under the terms of the GNU General Public License
   version 2 (GPLv2) as published by the Free Software Foundation.
*)

(** Structure that implements a table of all classes in the system *)


open Support
open Term
open Signature
open Container

type formal = int * type_term


type t
type parent_descriptor

val dummy_index:     int
val boolean_index:   int
val any_index:       int
val predicate_index: int
val function_index:  int
val tuple_index:     int


val result_type_of_compound: term -> int -> term

val base_table: unit -> t

val put_formal: int withinfo -> type_t withinfo -> t -> unit

val module_table: t -> Module_table.t

val has_current_module: t -> bool
    (** Is there a current module? *)

val current_module: t -> int
    (** The current module *)

val count_modules: t -> int
    (** The number of modules in the system *)

val find_module: (int * int list) -> t -> int
    (** [find_module name ct] finds the module [name] in [ct] *)

val used_modules: int -> t -> IntSet.t
  (** [used_modules mdl ct] returns the used modules of module [mdl] *)


val module_name: int -> t -> string
    (** [module_name mdl ct] returns the name of the module [mdl] *)

val add_used_module:    (int * int list) -> IntSet.t -> t -> unit
val add_current_module: int -> IntSet.t -> t -> unit
val set_interface_check: IntSet.t -> t -> unit

val is_private: t -> bool
   (** Are we within the implementation of a module? *)

val is_public:  t -> bool
   (** Are we either checking or using an interface? *)

val is_interface_check:  t -> bool
   (** Are we checking an interface? *)

val is_interface_use:  t -> bool
   (** Are we using an interface? *)


val count: t -> int

val class_symbol: int -> t -> int

val class_name:   int -> t -> string

val concepts_of_class: int -> t -> type_term array

val class_type: int -> t -> type_term*Tvars.t

val get_type: type_t withinfo -> Tvars.t -> t -> type_term

val is_class_public: int -> t -> bool

val descendants: int -> t -> IntSet.t
    (** [descendants cls ct] returns the set of descendants of the class [cls] *)


val generics: int -> t -> (bool*int) list
val add_generic: int -> bool -> int -> t -> unit
val add_generics: int -> bool -> Tvars.t -> t -> unit


val owner: Tvars.t -> Sign.t -> t -> int
val anchor_class: Tvars.t -> Sign.t -> t -> int
val anchored: Tvars.t -> int -> t -> int array
val anchor_formal_generics: Tvars.t -> Sign.t -> t -> int array
val check_deferred:  int -> int -> info -> t -> unit

val find_for_declaration: int list*int -> t -> int

val split_type_term: type_term -> int * type_term array

val downgrade_signature: int -> Sign.t -> int -> Sign.t
  (** [downgrade_signature ntvs sign nargs] downgrades the constant signature
      [ntvs,sign] (i.e. a signature which has no arguments and is therefore
      not callable) into a function signature with [nargs] arguments or
      downgrade a callable signature with one argument into callable signature
      with more than one argument.

      This is possible only if the result type of [sign] is a function or a
      predicate or a dummy type and the corresponding actual generic is a
      tuple with the corresponding number of elements in case that [nargs > 1]
      or if the signature is callable with a tuple and the tuple has enough
      argments.  *)


val arity_of_downgraded: int -> type_term -> int

val update: int -> header_mark withinfo -> Tvars.t -> t -> unit

val add: header_mark withinfo -> int -> Tvars.t -> t -> unit

val is_case_class:    int -> t -> bool
val has_constructors: int -> t -> bool
val constructors:     int -> t -> IntSet.t
val induction_law:    int -> t -> int
val set_constructors:  IntSet.t -> int -> t -> unit
val set_induction_law: int -> int -> t -> unit

val has_ancestor: int -> int -> t -> bool
val ancestor:     int -> int -> t -> parent_descriptor
val is_ghost_ancestor: int -> int -> t -> bool
val ancestor_type: type_term -> int -> int -> t -> type_term

val descends_from_any: int -> t -> bool
val type_descends_from_any: term -> Tvars.t -> t -> bool

val has_any: t -> bool
val has_predicate: t -> bool

val inherits_any:      int -> t -> bool

val parent_type:    int -> type_t withinfo -> t -> int * type_term array


val inherit_parent: int  -> int -> type_term array -> bool -> info -> t -> unit

val boolean_type:   int -> term

val is_boolean_binary: Sign.t -> int -> bool
val is_boolean_unary:  Sign.t -> int -> bool

val predicate_type: type_term -> int -> type_term
val function_type:  type_term -> type_term -> int -> type_term

val to_tuple: int -> int -> type_term array -> type_term

val to_dummy: int -> Sign.t -> type_term
   (** [to_dummy ntvs s] converts the signature [s] with [ntvs] type variables
       into the dummy type [dum[tup,rt]] where [tup] is a single type or a
       tuple which represents the arguments and [rt] is the return type of the
       signature.

       In case that [s] is a constant signature which is a
       predicate or a function, the class is updated by the dummy index.

       If the constant signature is neither a predicate nor a function then
       the result type of the signature is returned. *)

val to_function: int -> Sign.t -> type_term

val extract_from_tuple_max: int -> type_term -> type_term array

val upgrade_signature: int -> bool -> Sign.t -> type_term


val analyze_signature:
    entities list withinfo -> return_type -> bool -> bool -> bool -> Tvars.t -> t
      -> formal array * Result_type.t

val satisfies: type_term -> Tvars.t -> type_term -> Tvars.t -> t -> bool
  (** [satisfies tp1 tvs1 tp2 tvs2 ct]: Does the type [tp1,tvs1] satisfy the
      type [tp2,tvs2] *)

val type2string: term -> int -> int array -> t -> string

val string_of_signature: Sign.t -> Tvars.t -> t -> string

val string_of_complete_signature: Sign.t -> Tvars.t -> t -> string

val string_of_complete_signature_sub: Sign.t -> TVars_sub.t -> t -> string

val string_of_type: type_term -> Tvars.t -> t -> string
val string_of_type_arr: agens -> Tvars.t -> t -> string

val string_of_concepts: Tvars.t -> t -> string

val string_of_fgconcepts: Tvars.t -> t -> string

val string_of_sub: Term_sub.t -> Tvars.t -> t -> string

val string_of_tvs: Tvars.t -> t -> string

val string_of_tvs_sub: TVars_sub.t -> t -> string

val string_of_detailed_tvs: Tvars.t -> t -> string

val arguments_string: Tvars.t -> formal array -> t -> string

val arguments_string2: Tvars.t -> names -> types -> t -> string

val string_of_reduced_complete_signature: Sign.t -> Tvars.t -> t -> string
