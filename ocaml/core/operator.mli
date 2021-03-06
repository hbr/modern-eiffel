type t


type assoc =
  | Left
  | Right
  | No


val is_unary: string -> bool

val is_binary: string -> bool

val is_keyword_operator: string -> bool


val where: t

(** Precedence/associativity of assignment ":=". *)
val assign: t

(** Precedence/associativity of arrow operators ["->", "=>"]. *)
val arrow: t

(** Precedence/associativity of colon ':' operator. *)
val colon: t

(** Precedence/associativity of relation operators. *)
val relation: t

(** Precedence/associativity of addition operators. *)
val addition: t


(** Precedence/associativity of multiplication operators. *)
val multiplication: t


(** Precedence/associativity of function application. *)
val application: t


(** [compare op1 op2] compares the precedence of the operators. *)
val compare: t -> t -> int


(** [of_string op] computes the precedence information of the operator [op]
   given as a string. for unknow operators the highest precedence below
   function application and left associativity is returned. *)
val of_string: string -> t


(** [needs_parens lower is_left upper] decides if the lower operand [lower]
   used as a left or right operand (indicated by the flag [is_left]) for
   [upper] needs parentheses. *)
val needs_parens: t option -> bool -> t -> bool



val is_left_leaning:  t -> t -> bool
(** [is_left_leaning op1 op2]

    [a op1 b op2 c] has to be parsed as [(a op1 b) op2 c]
*)



val is_right_leaning: t -> t -> bool
(** [is_right_leaning op1 op2]

    [a op1 b op2 c] has to be parsed as [a op1 (b op2 c)]
*)




val associativity: t -> assoc

val precedence: t -> int
