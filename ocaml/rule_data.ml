(* Copyright (C) Helmut Brandl  <helmut dot brandl at gmx dot net>

   This file is distributed under the terms of the GNU General Public License
   version 2 (GPLv2) as published by the Free Software Foundation.
*)

open Term
open Signature
open Container
open Printf

type ctxt = {
    c: Context.t;
    nargs:     int;
    nms:       int array;
    tps:       type_term array;
    fgnms:     int array;
    fgcon:     type_term array;
  }

type t = {
    orig:int option;  (* original schematic assertion *)
    ctxt: ctxt;
    spec:      bool;  (* is specialized *)
    fwd_blckd: bool;  (* is blocked as forward rule *)
    nbwd:      int;   (* number of premises to drop until target has all vars *)
    ndropped:  int;   (* number of dropped premises *)
    maxnds_dropped: int; (* max nodes of dropped premises *)
    premises:  (int * int * term) list;
                               (* gp1, gp1_tp, cons,  term
                                  A premise is conservative if it is not
                                  more complex than the target. *)
    target:   term;
    eq:        (int * term * term) option; (* equality id, left, right *)
  }


let count_variables (rd:t): int = Context.count_variables rd.ctxt.c

let count_all_type_variables (rd:t): int =
  TVars_sub.count_all (Context.tvars_sub rd.ctxt.c)

let is_schematic (rd:t) : bool =  not rd.spec

let is_generic (rd:t): bool =
  Array.length rd.ctxt.fgcon > 0

let is_orig_schematic (rd:t): bool =
  match rd.orig with
    None -> false
  | Some _ -> true



let previous_schematic (rd:t): int option =
  rd.orig


let is_implication (rd:t): bool =
  rd.premises <> []


let is_intermediate (rd:t): bool =
  is_implication rd && is_orig_schematic rd


let is_specialized (rd:t): bool =
  (* Has the first premise been specialized? *)
  rd.spec


let is_fully_specialized (rd:t): bool =
  rd.ctxt.nargs = 0



let allows_partial_specialization (rd:t): bool =
  (* Can the rule be partially specialized i.e. can it be specialized and
     are there still unspecialized arguments after the specialization? *)
  is_implication rd &&
  let gp1,gp1_tp,_ = List.hd rd.premises in
  gp1 < rd.ctxt.nargs && gp1_tp = Array.length rd.ctxt.fgcon




let allows_premise_specialization (rd:t): bool =
  (* Is there a premise and can it be specialized? *)
  is_implication rd &&
  let gp1,gp1_tp,_ = List.hd rd.premises in
  gp1_tp = Array.length rd.ctxt.fgcon




let is_backward_recursive (rd:t): bool =
  assert (is_implication rd);
  assert (rd.nbwd = 0);
  List.exists
    (fun (_,_,p) -> Term.equivalent p rd.target)
    rd.premises


let is_forward_catchall (rd:t): bool =
  is_implication rd &&
  let _,_,p = List.hd rd.premises in
  match p with
    Variable i when i < rd.ctxt.nargs ->
      true
  | _ ->
      false



let is_equality (rd:t): bool =
  Option.has rd.eq


let count_arguments (rd:t): int =
  rd.ctxt.nargs


let equality_data (rd:t): int * int * term * term =
  match rd.eq with
    None -> raise Not_found
  | Some(eq_id, left, right) ->
      rd.ctxt.nargs, eq_id, left, right


let count_premises (rd:t): int =
  List.length rd.premises


let implication_chain (ps:(int*int*term) list) (tgt:term) (nbenv:int): term =
  let imp_id = nbenv + Constants.implication_index in
  List.fold_right
    (fun (_,_,p) tgt -> Term.binary imp_id p tgt)
    ps
    tgt





let prepend_premises
    (ps:(int*int*term) list) (rd:t)
    : term =
  (* Prepend the premises [ps] in front of the target and universally quantify
     the term.
   *)
  let t =
    implication_chain ps rd.target (rd.ctxt.nargs + count_variables rd)
  in
  Term.all_quantified
    rd.ctxt.nargs
    (rd.ctxt.nms,   rd.ctxt.tps)
    (rd.ctxt.fgnms, rd.ctxt.fgcon)
    t



let term (rd:t): term =
  if is_implication rd && is_specialized rd then
    let (gp1,gp1_tp,p), ps = List.hd rd.premises, List.tl rd.premises in
    assert (gp1 = 0);
    assert (gp1_tp = 0);
    let p = Term.down rd.ctxt.nargs p
    and t = prepend_premises ps rd
    and imp_id = count_variables rd + Constants.implication_index in
    Term.binary imp_id p t
  else
    prepend_premises rd.premises rd


let string_of_term (rd:t): string =
  Context.string_long_of_term (term rd) rd.ctxt.c



let complexity (t:term) (rd:t): int =
  let nvars = Context.count_variables rd.ctxt.c
  and tvs = Context.tvars rd.ctxt.c
  and ft  = Context.feature_table rd.ctxt.c in
  Feature_table.complexity t (rd.ctxt.nargs + nvars) tvs ft



let premises (rd:t) (c:Context.t): (term*bool) list =
  (* The premises of [rd] transformed into the context [c]. *)
  assert (Context.is_outer rd.ctxt.c c);
  assert (is_fully_specialized rd);
  assert (is_implication rd);
  let conservative = (* A premise is conservative if the original rule is not
                        schematic or it is not more complex than the target.*)
    if is_orig_schematic rd then
      let ntgt = complexity rd.target rd in
      (fun p -> complexity p rd <= ntgt)
    else
      (fun p -> true)
  and trans t = Context.transformed_term t rd.ctxt.c c in
  List.map
    (fun (_,_,p) -> trans p, conservative p)
    rd.premises



let is_backward_catchall (rd:t): bool =
  let nargs = rd.ctxt.nargs in
  match rd.target with
    Variable i when i < nargs ->
      true
  | Application(Variable i,args,_) when i < nargs ->
      assert (Array.length args = 1);
      let nvars = count_variables rd
      and ft = Context.feature_table rd.ctxt.c in
      let args = Feature_table.args_of_tuple args.(0) (nargs + nvars) ft in
      let len = Array.length args in
      interval_for_all
        (fun i ->
          match args.(i) with
            Variable j when j < nargs ->
              true
          | _ ->
              false
        )
        0 len
  | _ ->
      false


let is_backward (rd:t): bool =
  is_implication rd &&
  (rd.nbwd = 0 &&
   not (is_backward_catchall rd) &&
   not (is_backward_recursive rd))



let is_forward (rd:t): bool =
  is_implication rd &&
  not (is_schematic rd && is_backward rd) &&
  (not (is_forward_catchall rd)) &&
  (not rd.fwd_blckd || allows_partial_specialization rd) (* partial specialization
                                                            can overrule fwd_blckd *)
    &&
  (allows_premise_specialization rd) (* premise must always contain all formal
                                        generics *)


let short_string (rd:t): string =
  let lst = ref [] in
  if is_intermediate rd then
    lst := "i" :: !lst;
  if is_backward rd then
    lst := "b" :: !lst;
  if is_forward rd then
    lst := "f" :: !lst;
  String.concat "" !lst



let forward_blocked
    (ps_rev:(int*int*term)list)
    (tgt:term)
    (nb:int)
    (tvs:Tvars.t)
    (ft:Feature_table.t)
    : (int*int*term)list * bool =
  let ntgt = Feature_table.complexity tgt nb tvs ft in
  let ps,max_nds =
    List.fold_left
      (fun (ps,max_nds) (gp1,gp1_tp,p) ->
        let nds  = Feature_table.complexity p nb tvs ft in
        let nds  = max nds max_nds in
        let ps   = (gp1,gp1_tp,p)::ps in
        ps,nds)
        ([],0)
      ps_rev
  in
  ps, max_nds <= ntgt


let split_term
    (t:term) (nargs:int) (nbenv:int) (nfgs:int) (tps:type_term array)
    : (int*int*term) list * term =
  let imp_id = nbenv + nargs + Constants.implication_index
  in
  let ps, tgt = Term.split_implication_chain t imp_id
  in
  let ps =
    List.rev_map
      (fun p ->
        let gp1 = Term.greatestp1_arg p nargs in
        let gp1_tp =
          interval_fold
            (fun gp1_tp ivar ->
              let gp1 = Term.greatestp1_arg tps.(ivar) nfgs in
              max gp1_tp gp1
            )
            0
            0
            gp1
        in
        gp1, gp1_tp, p
      )
      ps
  in
  ps, tgt




let ndrops_to_backward
    (ps:(int*int*term) list) (tgt:term) (nargs:int): int =
  (* compute the number of premises to drop until the target contains all
     variables *)
  let rec bwdfun
      (ndropped:int)                 (* dropped premises *)
      (nspecialized:int)             (* specialized variables *)
      (ps:(int*int*term) list)       (* remaining premises *)
      (set:IntSet.t)                 (* remaining unspecialized variables in
                                        the target *)
      : int =
    if IntSet.cardinal set = nargs - nspecialized then
      ndropped
    else
      match ps with
        [] ->
          assert false (* not possible, because the chain must contain all
                          variables *)
      | (gp1,_,_)::ps ->
          let set =
            if 0 < gp1 then
              IntSet.filter (fun i -> gp1 <= i) set (* only the unspecialized
                                                       remain *)
            else
              set
          in
          bwdfun (1+ndropped) (max nspecialized gp1) ps set
  in
  bwdfun 0 0 ps (Term.bound_variables tgt nargs)



let make (t:term) (c:Context.t): t =
  let nargs,(nms,tps),(fgnms,fgcon),t0 =
    try Term.all_quantifier_split t
    with Not_found -> 0,empty_formals,empty_formals, t
  in
  let ctxt = {c = c;
              nargs     = nargs;
              nms       = nms;
              tps       = tps;
              fgnms     = fgnms;
              fgcon     = fgcon;
            }
  in
  let nbenv = Context.count_variables c in
  let nfgs = Array.length fgcon in
  let ps, tgt = split_term t0 nargs nbenv nfgs tps
  in
  let nbwd = ndrops_to_backward ps tgt nargs in
  let fwd_blckd =
    if nargs = 0 || nbwd > 0 then false
    else
      let ft = Context.feature_table c in
      let tvs =
        if Context.is_global c then
          Tvars.make_fgs fgnms fgcon
        else
          Context.tvars c
      and nb = nargs + nbenv in
      let _,fwd_blckd = forward_blocked (List.rev ps) tgt nb tvs ft in
      fwd_blckd in
  let eq =
    if ps = [] then
      try
        let neq,eq_id,left,right = Context.split_equality tgt nargs c in
        if neq = 0 then Some (eq_id,left,right) else None
      with Not_found -> None
    else None
  in
  let rd = { orig      = None;
             ctxt      = ctxt;
             spec      = nargs = 0;
             fwd_blckd = fwd_blckd;
             nbwd      = nbwd;
             ndropped  = 0;
             maxnds_dropped = 0;
             premises  = ps;
             target    = tgt;
             eq        = eq}
  in
  assert (term rd = t);
  rd



let schematic_premise (rd:t): int * types * int * term =
  assert (is_implication rd);
  let gp1,_,p = List.hd rd.premises in
  let p = Term.down_from (rd.ctxt.nargs - gp1) gp1 p in
  let tps = Array.sub rd.ctxt.tps 0 gp1 in
  gp1, tps, count_variables rd, p



let schematic_target (rd:t): int * int * term =
  if rd.nbwd <> 0 then
    printf "schematic_target nbwd %d\n" rd.nbwd;
  assert (rd.nbwd = 0);
  rd.ctxt.nargs, count_variables rd, rd.target



let schematic_term (rd:t): int * int * term =
  let nvars = count_variables rd in
  let t = implication_chain rd.premises rd.target (rd.ctxt.nargs + nvars) in
  rd.ctxt.nargs, nvars, t




let drop (rd:t) (c:Context.t): t =
  (* Drop the first premise of [rd] and construct the new rule_data valid
     in the context [c]
   *)
  assert (is_specialized rd);
  assert (is_implication rd);
  assert (not (is_generic rd));
  assert (Context.is_outer rd.ctxt.c c);
  let gp1,gp1_tp,p = List.hd rd.premises in
  let nds_p = complexity p rd in
  assert (gp1 = 0);
  assert (gp1_tp = 0);
  let ntvs_delta =
    Context.count_type_variables c - Context.count_type_variables rd.ctxt.c
  in
  assert (0 <= ntvs_delta);
  let ps = List.map
      (fun (gp1,gp1_tp,p) ->
        let p = Context.transformed_term0 p rd.ctxt.nargs rd.ctxt.c c in
        gp1,gp1_tp,p
      )
      (List.tl rd.premises)
  and tgt =
    Context.transformed_term0 rd.target rd.ctxt.nargs rd.ctxt.c c
  and tps =
    Array.map (fun tp -> Term.up_type ntvs_delta tp) rd.ctxt.tps
  in
  {rd with
   spec      = rd.ctxt.nargs = 0;
   nbwd      = if rd.nbwd > 0 then rd.nbwd - 1 else 0;
   ndropped  = rd.ndropped + 1;
   maxnds_dropped = max rd.maxnds_dropped nds_p;
   ctxt = {rd.ctxt with c = c; tps = tps};
   premises  = ps;
   target    = tgt}


let term_a (rd:t) (c:Context.t): term =
  (* The first premise of [rd] in the context [c]
   *)
  assert (is_specialized rd);
  assert (is_implication rd);
  assert (Context.is_outer rd.ctxt.c c);
  let gp1,gp1_tp,p = List.hd rd.premises in
  assert (gp1 = 0);
  assert (gp1_tp = 0);
  let t = Term.down rd.ctxt.nargs p in
  Context.transformed_term t rd.ctxt.c c



let term_b (rd:t) (c:Context.t): term =
  assert (is_specialized rd);
  assert (is_implication rd);
  assert (Context.is_outer rd.ctxt.c c);
  let ps = List.tl rd.premises in
  let t  = prepend_premises ps rd in
  Context.transformed_term t rd.ctxt.c c





let target (rd:t) (c:Context.t): term =
  assert (is_fully_specialized rd);
  assert (Context.is_outer rd.ctxt.c c);
  Context.transformed_term rd.target rd.ctxt.c c




let verify_specialization (args:arguments) (c:Context.t) (rd:t): agens =
  (* Verify that the specialization of the first arguments by [args] is
     possible and return needed actual generics.

     The arguments [args] come from the context [c].

     The rule represented by [rd] might contain formal generics. When substituting
     the first (or all) arguments by [args] some formal generics might be
     substituted by actual generics. Compute these actual generics (which
     have to be valid in the context [c].

     If the rule represented by [rd] comes from the global context, then it
     might have formal generics. Otherwise not.

     If [rd] does not have a global context, then both contexts must agree on
     the formal generics, they must not have global type variables but they may
     have a different number of local (untyped) type variables.

   *)
  let nargs = Array.length args in
  assert (nargs <= rd.ctxt.nargs);
  let argtps = Array.map (fun t -> Context.type_of_term t c) args
  and acttvs = Context.tvars c
  in
  if not (Context.is_global rd.ctxt.c) then begin
    let reqtvs = Context.tvars rd.ctxt.c
    and reqtps = Array.sub rd.ctxt.tps 0 nargs in
    Class_table.verify_substitution reqtps reqtvs argtps acttvs;
    [||]
  end else begin (* global context !! *)
    let nfgs = Array.length rd.ctxt.fgcon in
    let ags = Array.init nfgs (fun i -> empty_term)
    and reqtvs = Tvars.make_fgs rd.ctxt.fgnms rd.ctxt.fgcon
    and ct = Context.class_table c in
    let actnall = Tvars.count_all acttvs
    and reqnall = Tvars.count_all reqtvs
    in
    let do_sub i tp =
      if ags.(i) = empty_term then
        ags.(i) <- tp
      else if ags.(i) = tp then
        ()
      else
        raise Not_found
    in
    let rec unify reqtp acttp =
      let unicls i1 i2 =
        if i1-nfgs = i2-actnall then
          ()
        else
          raise Not_found
      in
      match reqtp, acttp with
        Variable i1,_ when i1 < nfgs ->
          assert (nfgs = reqnall);
          if Class_table.satisfies acttp acttvs reqtp reqtvs ct then
            do_sub i1 acttp
          else
            raise Not_found
      | Variable i1, Variable i2 ->
          unicls i1 i2
      | VAppl(i1,args1,_,_), VAppl(i2,args2,_,_) ->
          if Array.length args1 <> Array.length args2 then
            raise Not_found;
          unicls i1 i2;
          uniargs args1 args2
      | _ ->
          raise Not_found
    and uniargs args1 args2 =
      let len = Array.length args2 in
      assert (len <= Array.length args1);
      for k = 0 to len-1 do
        unify args1.(k) args2.(k)
      done
    in
    uniargs rd.ctxt.tps argtps;
    let nfgs_used =
      try
        Search.array_find_min (fun tp -> tp = empty_term) ags
      with Not_found ->
        nfgs
    in
    assert (interval_for_all (fun i -> ags.(i) = empty_term) nfgs_used nfgs);
    Array.sub ags 0 nfgs_used
  end


let count_args_to_specialize (rd:t): int =
  match rd.premises with
    [] ->
      rd.ctxt.nargs
  | (gp1,_,_) :: _ ->
      gp1


let specialize
    (rd:t) (args:term array) (ags:agens) (orig:int) (c:Context.t)
    : t =
  assert (Context.is_outer rd.ctxt.c c);
  let nargs  = Array.length args
  and nbenv  = Context.count_variables c
  and tvs    = Context.tvars c
  and rdnfgs = Array.length rd.ctxt.fgcon in
  let nall   = Tvars.count_all tvs in
  if rdnfgs <> Array.length ags then begin
    printf "specialize\n";
    printf "   %s\n" (string_of_term rd);
    printf "   rdnfgs %d\n" rdnfgs;
    printf "   |ags|  %d\n" (Array.length ags);
  end;
  assert (rdnfgs = Array.length ags);
  assert (not (is_specialized rd));
  assert (nargs <= rd.ctxt.nargs);
  assert (nargs = rd.ctxt.nargs || is_implication rd);
  if not (nargs = rd.ctxt.nargs || let gp1,_,_ = List.hd rd.premises in nargs = gp1)
  then begin
    printf "specialize\n";
    printf "   %s\n" (string_of_term rd);
    printf "   nargs %d, gp1 %d\n" nargs
      (let gp1,_,_ = List.hd rd.premises in gp1)
  end;
  assert (nargs = rd.ctxt.nargs || let gp1,_,_ = List.hd rd.premises in nargs = gp1);
  let full        = nargs = rd.ctxt.nargs
  and nbenv_delta = nbenv - count_variables rd
  and nall0 = count_all_type_variables rd
  in
  let nms = Array.sub rd.ctxt.nms nargs (rd.ctxt.nargs - nargs)
  and tps =
    Array.init
      (rd.ctxt.nargs-nargs)
      (fun i -> Term.subst rd.ctxt.tps.(nargs+i) (nall-nall0) ags)
  in
  let sub t =
    let t = Feature_table.substituted
      t rd.ctxt.nargs (count_variables rd) nall0
      args nbenv_delta
      ags  tvs (Context.feature_table c) in
    t
  in
  assert begin match rd.premises with
    [] -> nargs = rd.ctxt.nargs
  | (gp1,_,_)::_ ->
      nargs = rd.ctxt.nargs || nargs = gp1 end;
  let tgt  = sub rd.target in
  let ps_rev =
    List.fold_left
      (fun lst (gp1,gp1_tp,p) ->
        let gp1 = if nargs <= gp1 then gp1-nargs else 0
        and p   = sub p in
        (gp1,0,p)::lst)
      []
      rd.premises
  in
  let nargs_new = rd.ctxt.nargs - nargs in
  let ps,fwd_blckd =
    if full then
      let tvs = Context.tvars c
      and nb  = Context.count_variables c
      and ft  = Context.feature_table c
      in
      forward_blocked ps_rev tgt nb tvs ft
    else
      List.rev ps_rev, false
  in
  {rd with
   orig  = Some orig;
   spec  = true;
   fwd_blckd = fwd_blckd;
   nbwd = if nargs_new = 0 then 0 else rd.nbwd; (* ???? WRONG ??? *)
   ctxt  = {c = c;
            nargs = nargs_new;
            nms   = nms;
            tps   = tps;
            fgnms = [||];
            fgcon = [||]};
   premises = ps;
   target   = tgt}



let find_constructor (t:term) (pvar:int) (rd:t): int =
  (* extract the constructor from the premise [t] using the predicate
     variable [pvar]. Raise [Not_found] if [t] does not represent a premise
     of an induction law.*)
  let imp_id = rd.ctxt.nargs + Context.implication_index rd.ctxt.c
  in
  let n,args,ps_rev,tgt =
    Term.split_general_implication_chain t imp_id
  in
  assert false


let constructors (rd:t): int list =
  (* Extract the constructors from the rule [rd]. If [rd] does not represent
     an induction law then return the empty list.

     A rule is an induction law if it has the form

       all(x:T, p:{T})  pp1 ==> pp2 ==> ... ==> x in p

       ppi:  all(args) cond ==> ra1 in p ==> ... ==> c(args) in p

       cond must not involve [p] and [c], only the arguments [args]
   *)

  assert false
