open Alba2_common

module Term = Term2

module type CONTEXT =
  sig
    type t
    val empty: t
    val push: Feature_name.t option -> Term.typ -> t -> t
    val name: int -> t -> Feature_name.t option
    (*val shadow_level: int -> t -> int
    val type_: int -> t -> Term.*)
  end

module Raw_context =
  struct
    type t = unit
    let empty: t = ()
    let push (_:Feature_name.t option) (_:Term.typ) (c:t): t = c
    let name (i:int) (c:t): Feature_name.t option =
      some_feature_name (string_of_int i)
  end

(*
  Basics
  ------

  ((((f a) b) c) ... z)    ~>  f(a,b,c,...,z)

  all(a:A) all(b:B) ... t  ~>  all(a:A,b:B,...) t

  (a:A) := (b:B) := ... e  ~>  (a:A,b:B,...) := e


  Function term f can be a variable, lambda term, ...

  ((x,y) := exp)(a,b):
        exp                           let
          where                         x := a
             x := a                     y := b
             y := b                   then
          end                           exp

   derivable type arguments are supressed

   Fix(idx, (nm,tp,decr,term), ....)

      let mutual
        f1(args):tp := t
        f2(....) ...
        ...
      end then
        fi


  Parentheses:

  1) outer operator has higher precedence than inner operator

  2) same precedence, same left assoc and inner is right operand
     e.g. a + (b + c)

  3) same precedence, some right assoc and inner is left operand
     e.g. (a ^ b) ^ c

  4) same precedence, different assoc

  5) inspect, lambda and all have lower precedence than all operators (must be
     parenthesized if they occur as operand) but higher precedece than comma
     and colon.

  6) oo-dot binds stronger than application, application binds stronger than
     usual operators. 'tgt.f(args)' does not need '(tgt.f)(args)',
     'tgt.f(args) + ...' does not need parentheses. But '(+r)(a,b)' needs
     parentheses around '+r'.

  7) assignment binds stronger than comma i.e. f(...) := (a,b)  needs parentheses
     around 'a,b'.
 *)


module type S =
  sig
    type context
    type ppt
    type _ out
    val print: Term.t -> context -> ppt -> ppt out
  end

module Make (C:CONTEXT) (PP:Pretty_printer.PRETTY)
       : S with type 'a out = PP.t PP.out and
                type ppt = PP.t and
                type context = C.t
  =
  struct
    type ppt   = PP.t
    type _ out = PP.t PP.out
    type context = C.t
    type pp  = PP.t PP.out
    type ppf = PP.t -> pp

    let print_name (nme:Feature_name.t option): ppf =
      let open Feature_name in
      let open PP in
      match nme with
      | None ->
         put "_"
      | Some nme ->
         begin
           match nme with
           | Name s ->
              put s
           | Operator op ->
              let str,_,_ = Operator.data op in
              fun pp -> put "(" pp >>= put str >>= put ")"
           | Bracket ->
              put "[]"
           | True ->
              put "true"
           | False ->
              put "false"
           | Number i ->
              put (string_of_int i)
         end

    let rec print (t:Term.t) (c:C.t): ppf =
      let open Term in
      match t with
      | Sort s ->
         print_sort s
      | Variable i ->
         variable i c
      | Application (f,z,oo) ->
         application f z c
      | Lambda (nme,tp,t) ->
         print_lambda nme tp t c
      | All(nme,tp,t) ->
         print_product nme tp t c
      | Inspect (e,m,f) ->
         print_inspect e m f c
      | Fix (i,arr) ->
         assert false

    and print_sort s =
      let open Term in
      let open PP in
      match s with
      | Sorts.Proposition ->
         put "Proposition"
      | Sorts.Datatype ->
         put "Datatype"
      | Sorts.Any1 ->
         put "Any1"
      | Sorts.Max s ->
         let string_of_sv i b =
           let s = "SV" ^ string_of_int i in
           if b then
             s ^ "'"
           else
             s
         in
         let rec print_list lst =
           match lst with
           | [] ->
              assert false (* cannot happen *)
           | [i,b] ->
              put (string_of_sv i b)
           | (i,b) :: lst ->
              fun pp ->
              put (string_of_sv i b) pp
              >>= put ","
              >>= print_list lst
         in
         match Sorts.Set.bindings s with
         | [] ->
            assert false
         | [i,b] ->
            put (string_of_sv i b)
         | lst  ->
            fun pp -> put "max(" pp >>= print_list lst >>= put ")"


    and variable i c pp =
      let open Feature_name in
      let open PP in
      match C.name i c with
      | None ->
         put "v#" pp >>= put (string_of_int i)
      | Some nme ->
         begin
           match nme with
           | Name s ->
              put s pp
           | Operator op ->
              let str,_,_ = Operator.data op in
              put "(" pp >>= put str >>= put ")"
           | Bracket ->
              put "[]" pp
           | True ->
              put "true" pp
           | False ->
              put "false" pp
           | Number i ->
              put (string_of_int i) pp
         end

    and application f z c pp =
      let f,args = Term.split_application f [z] in
      let open PP in
      let rec print_args args =
        match args with
        | [] ->
           assert false (* cannot happen *)
        | [a] ->
           print a c
        | a :: args ->
           fun pp -> print a c pp >>= put "," >>= print_args args
      in
      print f c pp >>= put "(" >>= print_args args >>= put ")"

    and print_args args str tp c pp =
      let open PP in
      let print_arg nme a pp =
        print_name nme pp >>= put ":" >>= print a c
      in
      match args with
      | [] ->
         assert false (* cannot happen *)
      | [nme,a] ->
         let nme = some_feature_name_opt nme in
         print_arg nme a pp >>= put ")"
         >>= put str >>= break "" 1 2 >>= print tp (C.push nme tp c)
      | (nme,a) :: args ->
         let nme = some_feature_name_opt nme in
         print_arg nme a pp >>= put ","
         >>= print_args args str tp (C.push nme tp c)

    and print_lambda nme tp t c =
      let t,args_rev = Term.split_lambda0 (-1) t 0 [nme,tp] in
      let open PP in
      hovbox 0
        (chain [put "(("; print_args (List.rev args_rev) " :=" t c; put ")"])
      (*put "((" pp
      >>= print_args (List.rev args_rev) ":=" t c
      >>= put ")"*)

    and print_product nme tp t c pp =
      let tp,args_rev = Term.split_product0 t [nme,tp] in
      let open PP in
      put "all(" pp >>= print_args (List.rev args_rev) "" tp c

    (* inspect
           e
           res
       case
           c1(args) := f1
           ...
       end*)
    and print_inspect e res f c =
      let ncases = Array.length f in
      let open PP in
      hvbox 0
        (chain
           [put "inspect"; break "" 1 2;
            (hvbox 0
               (chain [print e c; break ";" 1 0; print res c]));
            space; put "case"; space; put "end"])
  end (* Make *)



module String_printer =
  Make
    (Raw_context)
    (Pretty_printer.Make (Pretty_printer.String_printer))


let string_of_term (t:Term.t): string =
  let module SP = Pretty_printer.String_printer in
  let module PP = Pretty_printer.Make (SP) in
  let module TP = Make (Raw_context) (PP) in
  let open PP in
  SP.run 200 (make 100 () >>= TP.print t Raw_context.empty)



let test (): unit =
  Printf.printf "test term printer\n";
  let open Term in
  let print = string_of_term in
  assert
    begin
      print variable1 = "1"
    end;
  assert
    begin
      let t =
        Application
          (Application(variable0,variable1,false), variable2, false) in
      print t = "0(1,2)"
    end;
  assert
    begin
      let t =
        All (Some "a",
             variable0,
             All (Some "b",
                  variable1, variable2)) in
      print t = "all(a:0,b:1) 2"
    end