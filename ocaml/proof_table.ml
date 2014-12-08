open Term
open Proof
open Container
open Support
open Printf

type desc = {nbenv0:     int;
             term:       term;
             proof_term: proof_term;}

type entry = {nbenv:  int;
              names:  int array;
              imp_id: int;
              all_id: int;
              mutable count: int;
              mutable nreq:  int   (* number of local assumptions *)
            }

type t = {seq:  desc Seq.t;
          mutable entry: entry;
          mutable stack: entry list;
          c: Context.t;
          verbosity: int}

let context (at:t): Context.t = at.c
let class_table (at:t):   Class_table.t   = Context.class_table at.c
let feature_table (at:t): Feature_table.t = Context.feature_table at.c


let is_private (at:t): bool = Context.is_private at.c
let is_public  (at:t): bool = Context.is_public  at.c
let is_interface_use   (at:t): bool = Context.is_interface_use  at.c
let is_interface_check (at:t): bool = Context.is_interface_check  at.c


let add_used_module (name:int*int list) (used:IntSet.t) (at:t): unit =
  Context.add_used_module name used at.c

let add_current_module (name:int) (used:IntSet.t) (at:t): unit =
  Context.add_current_module name used at.c

let set_interface_check (pub_used:IntSet.t) (at:t): unit =
  Context.set_interface_check pub_used at.c


let depth (at:t): int =
  List.length at.stack

let is_global (at:t): bool =
  at.stack = []

let is_local (at:t): bool =
  not (is_global at)

let is_toplevel (at:t): bool =
  Mylist.is_singleton at.stack

let count (at:t): int =
  Seq.count at.seq


let count_previous (at:t): int =
  if is_global at then
    0
  else
    (List.hd at.stack).count


let count_global (pt:t): int =
  let rec count (lst: entry list): int =
    match lst with
      []     -> assert false
    | [e]    -> e.count
    | _::lst -> count lst
  in
  if pt.stack = []
  then
    Seq.count pt.seq
  else
    count pt.stack


let count_last_local (pt:t): int =
  (count pt) - (count_previous pt)


let nbenv (at:t): int = at.entry.nbenv

let nbenv_local (at:t): int =
  at.entry.nbenv - if at.stack = [] then 0 else (List.hd at.stack).nbenv

let names (at:t): int array =
  at.entry.names

let imp_id (at:t): int =
  at.entry.imp_id

let all_id (at:t): int =
  at.entry.all_id

let all_id_outer (at:t): int =
  at.entry.all_id - nbenv_local at

let some_id (at:t): int =
  nbenv at + Feature_table.some_index

let split_implication (t:term) (at:t): term * term =
  Term.binary_split t at.entry.imp_id

let split_all_quantified (t:term) (at:t): int * int array * term =
  Term.quantifier_split t at.entry.all_id

let split_some_quantified (t:term) (at:t): int * int array * term =
  Term.quantifier_split t (some_id at)

let implication (a:term) (b:term) (at:t): term =
  Term.binary at.entry.imp_id a b

let implication_chain (ps: term list) (tgt:term) (at:t): term =
  Term.make_implication_chain ps tgt (imp_id at)

let split_implication_chain (t:term) (at:t): term list * term =
  Term.split_implication_chain t (imp_id at)

let all_quantified (nargs:int) (names:int array) (t:term) (at:t): term =
  Term.quantified at.entry.all_id nargs names t

let some_quantified (nargs:int) (names:int array) (t:term) (at:t): term =
  Term.quantified (some_id at) nargs names t

let all_quantified_outer (t:term) (at:t): term =
  let nargs  = nbenv_local at          in
  let all_id = at.entry.all_id - nargs in
  Term.quantified all_id nargs at.entry.names t

let rec stacked_counts (pt:t): int list =
  List.map (fun e -> e.count) pt.stack


let string_of_term (t:term) (at:t): string =
  Context.string_of_term t 0 at.c

let string_of_term_outer (t:term) (at:t): string =
  Context.string_of_term_outer t 0 at.c


let make (verbosity:int): t =
  {seq   = Seq.empty ();
   entry = {count   = 0;
            names   = [||];
            nbenv   = 0;
            nreq    = 0;
            imp_id  = Feature_table.implication_index;
            all_id  = Feature_table.all_index};
   stack = [];
   c = Context.make verbosity;
   verbosity = verbosity}


let push0 (nbenv:int) (names: int array) (at:t): unit =
  assert (nbenv = Array.length names);
  at.entry.count <- Seq.count at.seq;
  at.stack       <- at.entry :: at.stack;
  at.entry       <-
    {at.entry with
     nreq   = 0;
     nbenv  = at.entry.nbenv + nbenv;
     names  = names;
     imp_id = at.entry.imp_id + nbenv;
     all_id = at.entry.all_id + nbenv}



let push (entlst:entities list withinfo) (at:t): unit =
  let c = context at in
  assert (depth at = Context.depth c);
  Context.push entlst None true false c;
  let nbenv = Context.arity c
  and names = Context.local_fargnames c in
  assert (nbenv = Array.length names);
  push0 nbenv names at


let push_untyped (names:int array) (at:t): unit =
  let c = context at in
  Context.push_untyped names c;
  let nbenv = Context.arity c in
  assert (nbenv = Array.length names);
  assert (names = Context.local_fargnames c);
  push0 nbenv names at



let keep (cnt:int) (at:t): unit =
  assert (count_previous at <= cnt);
  Seq.keep cnt at.seq


let pop (at:t): unit =
  assert (is_local at);
  assert (depth at = Context.depth (context at));
  Context.pop (context at);
  at.entry  <- List.hd at.stack;
  at.stack  <- List.tl at.stack;
  Seq.keep at.entry.count at.seq



let term (i:int) (at:t): term * int =
  (** The [i]th proved term with the number of variables of its environment.
   *)
  assert (i < count at);
  let desc = Seq.elem i at.seq in
  desc.term, desc.nbenv0


let nbenv_term (i:int) (at:t): int =
  (** The number of variables of the environment of the  [i]th proved term.
   *)
  assert (i < count at);
  (Seq.elem i at.seq).nbenv0



let local_term (i:int) (at:t): term =
  (** The [i]th proved term in the local environment.
   *)
  assert (i < count at);
  let desc = Seq.elem i at.seq in
  let n_up = at.entry.nbenv - desc.nbenv0
  in
  Term.up n_up desc.term


let variant (i:int) (cls:int) (at:t): term =
  let ft = feature_table at in
  let t,nbenv = term i at   in
  let t = Feature_table.variant_term t nbenv cls ft in
  t



let discharged_assumptions (i:int) (at:t): int * int array * term =
  (* The [i]th term of the current environment with all quantified variables
     of the term and assumptions discharged. A potential quantifier in the
     term is moved up (prenex normal form) all assumptions.

     Note: If [i] is not in the current environment it cannot be quantified!
   *)
  let cnt0 = count_previous at
  and tgt  = local_term i at in
  let n,nms,tgt =
    try
      let n,nms,t = split_all_quantified tgt at in
      if i < cnt0 then
        printf "  i %d, cnt0 %d tgt %s\n" i cnt0 (string_of_term tgt at);
      assert (cnt0 <= i);
      n,nms,t
    with Not_found -> 0,[||],tgt
  in
  let imp_id = n + imp_id at in
  let tref = ref tgt in
  for k = cnt0 + at.entry.nreq - 1 downto cnt0 do
    let t = local_term k at in
    let t = Term.up n t in
    tref := Term.binary imp_id t !tref
  done;
  n,nms,!tref




let discharged_term (i:int) (at:t): term =
  (* The [i]th term of the current environment with all local variables and
     assumptions discharged.
   *)
  let n1,nms1,t = discharged_assumptions i at in
  let nargs = n1 + nbenv_local at
  and nms   = Array.append nms1 (names at) in
  Term.quantified (all_id_outer at) nargs nms t



let is_axiom (i:int) (at:t): bool =
  assert (i < count at);
  let desc = Seq.elem i at.seq in
  match desc.proof_term with
    Axiom _ -> true
  | _            -> false


let is_assumption (i:int) (at:t): bool =
  assert (i < count at);
  let desc = Seq.elem i at.seq in
  match desc.proof_term with
    Assumption _ -> true
  | _            -> false


let proof_term (i:int) (at:t): proof_term =
  assert (i < count at);
  (Seq.elem i at.seq).proof_term


let add_proved_0 (t:term) (pt:proof_term) (at:t): unit =
  (** Add the term [t] and its proof term [pt] to the table.
   *)
  let raw_add () =
    Seq.push {nbenv0 = at.entry.nbenv;
              term   = t;
              proof_term = pt} at.seq
  in
  match pt with
    Assumption _ ->
      let idx = count at in
      assert (idx = count_previous at + at.entry.nreq);
      raw_add ();
      at.entry.nreq <- at.entry.nreq + 1
  | _ ->
      raw_add ()


exception Illegal_proof_term


let definition (idx:int) (nb:int) (at:t): term =
  let nbenv = nbenv at in
  if idx < nbenv then
    raise Not_found
  else
    let idx = idx - nbenv in
    Feature_table.definition idx (nb + nbenv) (feature_table at)



let reconstruct_evaluation (e:Eval.t) (at:t): term * term =
  let rec reconstruct e nb =
    match e with
      Eval.Term t -> t,t
    | Eval.Expand idx ->
        begin try
          Variable idx,
          definition (idx-nb) nb at
        with Not_found ->
          raise Illegal_proof_term end
    | Eval.Apply (f,args) ->
        let fa,fb = reconstruct f nb
        and nargs = Array.length args in
        let args  = Array.map (fun e -> reconstruct e nb) args in
        let argsa = Array.init nargs (fun i -> fst args.(i))
        and argsb = Array.init nargs (fun i -> snd args.(i)) in
        Application (fa,argsa), Application (fb,argsb)
    | Eval.Lam (n,nms,e) ->
        let ta,tb = reconstruct e (nb+n) in
        Lam (n,nms,ta), Lam (n,nms,tb)
    | Eval.Beta e ->
        let ta,tb = reconstruct e nb in
        begin match tb with
          Application(Lam(n,nms,t0),args) ->
            assert (n = Array.length args);
            let tb = Term.apply t0 args in
            ta,tb
        | _ -> raise Illegal_proof_term end
    | Eval.Simpl (e,idx) ->
        assert false
  in
  reconstruct e 0




let term_of_mp (a:int) (b:int) (at:t): term =
  assert (a < count at);
  assert (b < count at);
  let ta = local_term a at
  and tb = local_term b at
  in
  let b1,b2 =
    try Term.binary_split tb (imp_id at)
    with Not_found ->
      printf "tb is not an implication\n";
      printf "  ta %d:%s\n" a (string_of_term ta at);
      printf "  tb %d:%s\n" b (string_of_term tb at);
      raise Illegal_proof_term
  in
  let ok = (ta = b1) in
  (*let ok = Term.equal_wo_names ta b1 in*)
  if not ok then begin
    printf "antecedent of tb does not conincide with ta (ok %b)\n" ok;
      printf "  ta %d:%s\n" a (string_of_term ta at);
      printf "  tb %d:%s\n" b (string_of_term tb at);
    raise Illegal_proof_term
  end;
  b2



let term_of_eval (i:int) (e:Eval.t) (at:t): term =
  let ta,tb = reconstruct_evaluation e at
  and t = local_term i at in
  let ok = (t = ta) in
  if not ok then begin
    printf "evaluated terms do not coincide\n";
    printf "   term %3d  %s\n" i (string_of_term t at);
    printf "   eval      %s\n" (string_of_term ta at);
    printf "   evaluated %s\n" (string_of_term tb at);
    raise Illegal_proof_term
  end;
  tb


let term_of_eval_bwd (t:term) (e:Eval.t) (at:t): term =
  let ta,tb = reconstruct_evaluation e at in
  let ok = (t = ta) in
  if not ok then begin
    printf "evaluated terms do not coincide\n";
    printf "   term      %s\n" (string_of_term t at);
    printf "   eval      %s\n" (string_of_term ta at);
    printf "   evaluated %s\n" (string_of_term tb at);
    raise Illegal_proof_term
  end;
  implication tb ta at



let term_of_specialize (i:int) (args:term array) (at:t): term =
  assert (i < count at);
  let nargs = Array.length args
  and t = local_term i at
  in
  let n,nms,t0 =
    try Term.quantifier_split t (all_id at)
    with Not_found -> assert false
  in
  assert (nargs <= n);
  let tsub = Term.part_sub t0 n args 0
  in
  if nargs < n then
    let imp_id0 = (imp_id at)           in
    let imp_id1 = imp_id0 + (n-nargs)   in
    try
      let a,b = Term.binary_split tsub imp_id1 in
      Term.binary
        imp_id0
        (Term.down (n-nargs) a)
        (Term.quantified
           (all_id at)
           (n-nargs)
           (Array.sub nms nargs (n-nargs))
           b)
    with Term_capture ->
      printf "term capture\n";
      raise Illegal_proof_term
    | Not_found ->
        printf "not found\n";
        raise Illegal_proof_term
  else
    tsub


let term_of_witness (i:int) (nms:int array) (t:term) (args:term array) (at:t)
    : term =
  let nargs = Array.length args in
  Array.iter (fun t ->
    match t with Variable i when i = -1 ->
      raise Illegal_proof_term
    | _ -> ())
    args;
  let some_term = some_quantified nargs nms t at in
  let ti  = local_term i at in
  let wt  = Term.apply t args in
  if ti = wt (*Term.equal_wo_names ti wt*) then ()
  else begin
    printf "illegal witness ti %s, wt %s, for %s\n"
      (string_of_term ti at)
      (string_of_term wt at)
      (string_of_term some_term at);
    raise Illegal_proof_term
  end;
  implication ti some_term at


let someelim (i:int) (at:t): term =
  (** Transform the term [i] if it has the form [some(a,b,...) e1] into
      [all(e2) (all(a,b,...) e1 => e2) => e2]. Otherwise [raise Not_found]
   *)
  assert (i < count at);
  let t = local_term i at in
  let nargs,nms,tt = split_some_quantified t at in
  let tt = Term.upbound 1 nargs tt in
  let imp_id  = imp_id at
  and all_id  = all_id at
  in
  let imp_id1 = imp_id + (nargs+1)
  and imp_id2 = imp_id + 1
  and all_id1 = all_id + 1
  and all_id2 = all_id
  in
  let impl1   = Term.binary imp_id1 tt (Variable nargs) in
  let lam1    = Lam (nargs,nms,impl1) in
  let all1    = Term.unary all_id1 lam1 in
  let impl2   = Term.binary imp_id2 all1 (Variable 0) in
  let lam2    = Lam (1,[||],impl2) in
  let all2    = Term.unary all_id2 lam2 in
  all2



let term_of_someelim (i:int) (at:t): term =
  try
    someelim i at
  with Not_found ->
    raise Illegal_proof_term


let count_assumptions (pt_arr:proof_term array): int =
  let p (pt:proof_term): bool =
    match pt with
      Assumption _ -> false | _ -> true
  in
  try
    Search.array_find_min p pt_arr
  with Not_found ->
    Array.length pt_arr




let arguments_string (at:t): string =
  let names = Array.to_list at.entry.names in
  let str = String.concat "," (List.map ST.string names) in
  if str = "" then str
  else "(" ^ str ^ ")"



let reconstruct_term (pt:proof_term) (trace:bool) (at:t): term =
  let depth_0 = depth at
  and cnt0    = count at
  in
  let prefix (d:int): string = String.make (4*(d-depth_0)) ' '
  in
  let print (t:term) =
    printf "%s%3d %s"
      (prefix (depth at)) (count at) (string_of_term t at)
  and print_all () =
    let pre = prefix (depth at - 1) in
    printf "%s%3d all%s\n%s    require\n"
      pre (count at) (arguments_string at) pre
  and print_str (str:string):unit =
    let pre = prefix (depth at - 1) in
    printf "%s    %s\n" pre str
  in
  let print0 (t:term) = print t; printf "\n"
  and print1 (t:term) (i:int) = print t; printf "\t{%d}\n" i
  and print2 (t:term) (i:int) (j:int) = print t; printf "\t{%d,%d}\n" i j
  in
  let rec reconstruct (pt:proof_term): term =
    let cnt = count at in
    match pt with
      Axiom t | Assumption t ->
        if trace then print0 t;
        t
    | Detached (a,b) ->
        let t = term_of_mp a b at in
        if trace then print2 t a b;
        t
    | Specialize (i,args) ->
        let t = term_of_specialize i args at in
        if trace then print1 t i;
        t
    | Eval (i,e) ->
        let t = term_of_eval i e at in
        if trace then print1 t i;
        t
    | Eval_bwd (t,e) ->
        let t = term_of_eval_bwd t e at in
        if trace then print0 t;
        t
    | Witness (idx,nms,t,args) ->
        let t = term_of_witness idx nms t args at in
        if trace then print0 t;
        t
    | Someelim idx ->
        let t = term_of_someelim idx at in
        if trace then print0 t;
        t
    | Inherit (idx,cls) ->
        let t =  variant idx cls at in
        if trace then print1 t idx;
        t
    | Subproof (nargs,names,res_idx,pt_arr) ->
        push_untyped names at;
        let pt_len = Array.length pt_arr in
        let pt_nass =
          if trace then count_assumptions pt_arr else 0
        in
        assert (res_idx < cnt + pt_len);
        if trace then print_all ();
        for i = 0 to pt_len - 1 do
          if trace && i = pt_nass then print_str "check";
          let t = reconstruct pt_arr.(i) in
          add_proved_0 t pt_arr.(i) at
        done;
        if trace then begin
          print_str "ensure";
          print1 (local_term res_idx at) res_idx;
          print_str "end";
        end;
        let term = discharged_term res_idx at in
        pop at;
        term
  in
  try
    reconstruct pt
  with Illegal_proof_term ->
    for k = depth_0 to depth at - 1 do pop at done;
    keep cnt0 at;
    raise Illegal_proof_term




let term_of_pt (pt:proof_term) (at:t): term =
  (** Construct a term from the proof term [pt].
   *)
  reconstruct_term pt false at


let print_pt (pt:proof_term) (at:t): unit =
  let _ = reconstruct_term pt true at in ()



let is_proof_pair (t:term) (pt:proof_term) (at:t): bool =
  try
    let t_pt = term_of_pt pt at in
    let res = (t = t_pt) (*Term.equal_wo_names t t_pt*) in
    if not res then begin
      printf "unequal t    %s\n" (string_of_term t at);
      printf "        t_pt %s\n" (string_of_term t_pt at)
    end;
    res
  with Illegal_proof_term ->
    printf "Illegal proof term\n";
    print_pt pt at;
    false


let add_proved (t:term) (pt:proof_term) (delta:int) (at:t): unit =
  (** Add the term [t] and its proof term [pt] to the table.
   *)
  assert (delta <= count at);
  let start = count at - delta in
  let pt = Proof_term.adapt start delta pt in
  assert (not (is_global at) || is_proof_pair t pt at);
  add_proved_0 t pt at


let add_axiom (t:term) (at:t): unit =
  assert (is_toplevel at);
  let pt = Axiom t in
  add_proved_0 t pt at


let add_assumption (t:term) (at:t): unit =
  let pt = Assumption t in
  add_proved_0 t pt at


let add_inherited (t:term) (idx:int) (cls:int) (at:t): unit =
  assert (is_global at);
  let pt = Inherit (idx,cls) in
  add_proved_0 t pt at


let add_mp (t:term) (i:int) (j:int) (at:t): unit =
  let pt = Detached (i,j) in
  add_proved_0 t pt  at


let add_specialize (t:term) (i:int) (args:term array) (at:t): unit =
  let pt = Specialize (i,args) in
  add_proved_0 t pt  at


let add_eval (t:term) (i:int) (e:Eval.t) (at:t): unit =
  add_proved_0 t (Eval (i,e)) at


let add_eval_backward (t:term) (impl:term) (e:Eval.t) (at:t): unit =
  (* [impl = (teval => t)] *)
  add_proved_0 impl (Eval_bwd (t,e)) at



let add_witness
    (impl:term) (i:int)
    (nms:int array) (t:term)
    (args:term array) (at:t): unit =
  add_proved_0 impl (Witness (i,nms,t,args)) at


let add_someelim (i:int) (t:term) (at:t): unit =
  add_proved_0 t (Someelim i) at



let discharged_proof_term (i:int) (at:t): int * int array * proof_term array =
  (* The [i]th term of the current environment with all quantified variables and
     assumptions discharged.

     Note: If [i] is not in the current environment it cannot be quantified!
   *)
  let cnt0 = count_previous at
  and nreq = at.entry.nreq
  and pt   = proof_term i at in
  let n,nms,pt =
    try
      let n,nms,idx,pt_arr = Proof_term.split_subproof pt in
      assert (n=0 || cnt0 <= i);
      n,nms, Subproof (0,[||],idx,pt_arr)
    with Not_found ->
      0, [||], pt
  in
  let narr = if cnt0+nreq<=i  then i+1-cnt0 else nreq in
  let pterm j =
    let pt = proof_term (cnt0+j) at in
    Proof_term.term_up n pt
  in
  let pt_arr = Array.init narr (fun j -> if cnt0+j=i then pt else pterm j)
  in
  n, nms, pt_arr






let discharged (i:int) (at:t): term * proof_term =  (* new version *)
  let n1,nms1,t = discharged_assumptions i at
  in
  let nargs = n1 + nbenv_local at
  and nms   = Array.append nms1 (names at)
  and nreq  = at.entry.nreq
  and cnt0  = count_previous at
  and axiom = is_axiom i at
  in
  let len, pt_arr =
    let n2,nms2,pt_arr = discharged_proof_term i at in
    assert (axiom || n1 = n2);
    assert (axiom || nms1 = nms2);
    Array.length pt_arr, pt_arr
  in
  if nargs = 0 && nreq = 0 && len = 1 then
    t, pt_arr.(0)
  else
    let i,pt_arr =
      if len=0 then i,pt_arr else Proof_term.remove_unused i cnt0 pt_arr
    in
    let nargs,nms,t,pt_arr =
      try Proof_term.normalize_pair nargs nms t pt_arr
      with Not_found -> assert false (* nyi *)
    in
    let t  = Term.quantified (all_id_outer at) nargs nms t
    in
    let pt = if axiom then Axiom t else Subproof (nargs,nms,i,pt_arr)
    in
    t, pt
