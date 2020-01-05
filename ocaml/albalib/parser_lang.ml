open Fmlib
open Common

module Located = Character_parser.Located
type 'a located = 'a Located.t

module Position = Character_parser.Position

type range = Position.t * Position.t





module Expression = struct
  type operator = string * Operator.t


  type t =
    t0 located


  and t0 =
    | Proposition
    | Any
    | Identifier of string
    | Number of string
    | Char of int
    | String of string
    | Operator of operator
    | Binary of t * operator located * t
    | Typed of t * t
    | Function of string located list * t
    | Parenthesized of t


  let rec binary
            (e0:t)
            (rest: (operator Located.t * t) list)
          : (t, Position.t * Position.t * string * string) result
    (* Analyze the precedence and associativity of an operator expresssion

        e0 op1 e1 op2 e2 ... opn en

       where [e0] is given explicitly and the rest is given as a list

        [(op1,e1), (op2,e2), ...]
     *)
    =
    let mk_bin e1 op e2 =
      let pos_start = Located.start e1
      and pos_end   = Located.end_ e2
      and op_str,_    = Located.value op
      in
      Located.make
        pos_start
        (if op_str = ":" then
           Typed (e1, e2)
         else
           Binary (e1,op,e2))
        pos_end
    in
    match rest with
    | [] ->
       Ok e0

    | [op, e1] ->
       Ok (mk_bin e0 op e1)

    | (op1,e1) :: (op2,e2) :: rest ->
       (* e0 op1 e1 op2 e2 rest *)
       let op1_string, op1_data = Located.value op1
       and op2_string, op2_data = Located.value op2
       in
       match Operator.leaning op1_data op2_data with
       | Operator.Left ->
          (* (e1 op1 e2) op2 e2 rest *)
          binary (mk_bin e0 op1 e1) ((op2,e2) :: rest)

       | Operator.Right ->
          (* e1 op1 (e2 op2 e2 rest) *)
          let module Res =
            Monad.Result
              (struct type t = Position.t * Position.t * string * string end)
          in
          Res.map (mk_bin e0 op1) (binary e1 ((op2,e2) :: rest))

       | Operator.No ->
          (* Error case: I cannot decide on how to parenthesize *)
          Error (Located.start e0, Located.end_ e2, op1_string, op2_string)
end







module Final =
  struct
    type t = Expression.t option
  end






module Context_msg =
  struct
    type t =
      | Operand
  end







module Problem =
  struct
    type t =
      | Operator_precedence of
          range
          * string * string (* the 2 operatos strings *)

      | Unexpected_keyword of range * string (* expectation *)
  end

module P =
  Character_parser.Advanced (Unit) (Final) (String) (Problem) (Context_msg)
include P



let keywords: String_set.t =
  let open String_set in
  empty
  |> add "create"
  |> add "inspect"


let string (str: string): unit t =
  P.string str (fun i -> "'" ^ String.one str.[i] ^ "'")


let char (c:char): unit t =
  P.char c ("'" ^ String.one c ^ "'")


let whitespace_char: char t =
  P.whitespace_char "whitespace"


let line_comment: unit t =
  backtrackable (string "--") "\"--\""
  >>= fun _ ->
  skip_zero_or_more
    (expect
       (fun c -> c <> '\n')
       "any char except newline")
  >>= fun _ ->
  return ()


let multiline_comment: unit t =
  let rec to_end (): unit t =
    (char '-' >>= fun _ ->
     (char '}'
     <|> to_end ()))
    <|> (expect (fun _ -> true) "any char"
         >>= fun _ ->
         to_end ())
  in
  backtrackable
    (string "{-")
    "\"{-\""
  >>= fun _ ->
  to_end ()



let whitespace: int t =
  skip_zero_or_more
    ((map (fun _ -> ()) whitespace_char)
     <|> line_comment
     <|> multiline_comment)



let word_ws
      (start: char->bool)
      (inner: char->bool)
      (msg:   string)
    : string located t
  =
  located @@ word start inner msg
  |. whitespace
  >>= succeed


let identifier: string located t =
  word_ws
    Char.is_letter
    (fun c -> Char.is_letter c || Char.is_digit c || c = '_')
    "identifier"


let number: string located t =
  word_ws
    Char.is_digit
    Char.is_digit
    "number"


let identifier_expression: Expression.t t =
  map
    (Located.map
       (fun s ->
         if s = "Proposition" then
           Expression.Proposition
         else if s = "Any" then
           Expression.Any
         else
           Expression.Identifier s
    ))
    (identifier >>= fun s ->
     if String_set.mem (Located.value s) keywords then
       fail (Problem.Unexpected_keyword (Located.range s, "<identifier>"))
     else
       return s)


let number_expression: Expression.t t =
  map
    (Located.map (fun s -> Expression.Number s))
    number



let literal_string: Expression.t t =
  located (
      return
        (fun chars ->
          let chars = Array.of_list chars in
          let len   = Array.length chars in
          Expression.String (String.init len (fun i -> chars.(i))))
      |. char '"'
      |= zero_or_more
           (expect
              (fun c ->
                let i = Char.code c in
                Char.code ' ' <= i && i < 128 && c <> '"')
              "string character")
      |. char '"')
  |. whitespace


let literal_char: Expression.t t =
  located (
      return
        (fun c -> Expression.Char (Char.code c))
      |. char '\''
      |= expect
           (fun c -> c <> '\'' && c <> '\n')
           "character"
      |. char '\'')
  |. whitespace



let operator: Expression.operator Located.t t =
  let op_chars = "+-^*/=~<>" in
  let len = String.length op_chars in
  let is_op_char c =
    String.find (fun op_char -> c = op_char) 0 op_chars < len
  in
  located
  @@ map
       (fun lst ->
         let op_str = String.of_list lst
         in
         op_str, Operator.of_string op_str)
       (one_or_more
          (expect
             is_op_char
             "operator character")
        <|> map (fun _ -> [':']) (char ':')
        <?> "operator or ':'"
       )
  |. whitespace
  >>= succeed


let lonely_operator: Expression.t t =
  map
    (fun op_located ->
      Located.map (fun op -> Expression.Operator op) op_located)
    operator


let char_ws (c:char): unit t =
  char c |. whitespace

let string_ws (s:string): unit t =
  string s |. whitespace


let rec expression (): Expression.t t =
  let primary (): Expression.t t =
    identifier_expression
    <|> number_expression
    <|> literal_char
    <|> literal_string
    <|> located
          (return
             (fun op_exp -> Expression.Parenthesized op_exp)
           |= (char_ws '('
               >>= fun _ ->
               (* op_expression has to be encapsulated in a function,
                  otherwise infinite recursion!! *)
               expression () <|> lonely_operator)
           |. char_ws ')'
          )
    <|> located
          (return (fun args exp -> Expression.Function (args, exp))
           |. char_ws '\\'
           |= one_or_more identifier
           |= (string_ws ":=" >>= fun _ -> expression ()))
    <?> "expression"
  in
  let operator_and_operand =
    return (fun op exp -> (op,exp))
    |= operator
    |= in_context Context_msg.Operand (primary ())
  in

  primary () >>= fun e1 ->

  zero_or_more operator_and_operand >>= fun lst ->

  match Expression.binary e1 lst with
  | Ok e ->
     return e

  | Error (p0, p1, op1, op2) ->
     fail (Problem.Operator_precedence ((p0, p1), op1, op2))


let initial: parser =
  make
    (return identity
     |. whitespace
     |= optional @@ expression ()
     |. expect_end "end of command")
    ()
