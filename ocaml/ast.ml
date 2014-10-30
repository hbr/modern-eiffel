open Term
open Support
open Printf

let put_class
    (hm:       header_mark withinfo)
    (cn:       classname)
    (fgs:      formal_generics)
    (inherits: inherit_clause list)
    (pc: Proof_context.t)
    : unit =
  (** Analyze the class declaration [hm,cn,fgs,inherits] and add or update the
      corresponding class.  *)
  assert (Proof_context.is_global pc);
  let ft = Proof_context.feature_table pc in
  let ct = Feature_table.class_table ft in
  let idx =
    try
      let idx = Class_table.find_2 (snd cn.v) ct in
      Class_table.update idx hm fgs  ct;
      idx
    with Not_found ->
      let idx = Class_table.count ct in
      Class_table.add hm cn fgs ct;
      idx
  in
  List.iter
    (fun par_lst ->
      List.iter
        (fun (ghost,tp,adapt_lst) ->
          assert (adapt_lst = [] ); (* nyi: feature adaption *)
          let par_idx, par_args = Class_table.parent_type idx tp ct in
          let lst, lst_priv =
            Class_table.inherited_ancestors idx par_idx par_args tp.i ct in
          Class_table.do_inherit idx lst ct;
          if lst_priv <> [] then
            Class_table.export_inherited idx lst_priv ct;
          Feature_table.do_inherit idx lst tp.i ft;
          Feature_table.export_inherited idx lst_priv ft;
          Proof_context.do_inherit idx lst tp.i pc)
        par_lst)
    inherits



let assertion_list (lst:compound) (context:Context.t): term list =
  List.map (fun e -> Typer.result_term e context) lst


let result_term (lst:info_expression list) (context:Context.t): term =
  match lst with
    [] -> assert false
  | [e] -> begin
      match e.v with
        Binexp (Eqop, ExpResult,def) ->
          Typer.result_term
            (withinfo e.i def)
            context
      | _ ->
          raise Not_found
  end
  | _ -> raise Not_found




let put_feature
    (fn: feature_name withinfo)
    (entlst: entities list withinfo)
    (rt: return_type)
    (is_func: bool)
    (bdy: feature_body option)
    (exp: info_expression option)
    (context: Context.t): unit =
  Context.push entlst rt false is_func context;
  let impstat,term_opt =
    match bdy, exp with
      None, None ->
        Feature_table.No_implementation,
        None
    | None, Some ie ->
        let term = Typer.result_term ie context in
        Feature_table.No_implementation,
        Some term
    | Some bdy, None ->
        begin
          match bdy with
            None, Some Impbuiltin, None ->
              Feature_table.Builtin,
              None
          | Some reqlst, Some Impbuiltin, None ->
              let _ = assertion_list reqlst context in
              Feature_table.Builtin,
              None
          | Some reqlst, None, Some enslst ->
              (try
                let term = result_term enslst context in
                let _ = assertion_list reqlst context in
                Feature_table.No_implementation, Some term
              with Not_found ->
                not_yet_implemented fn.i
                  "functions not defined with `Result = ...'")
          | None, Some Impdeferred, None ->
              Feature_table.Deferred,
              None
          | _ -> not_yet_implemented fn.i
                "functions with implementation/preconditions"
        end
    | _ -> assert false (* cannot happen *)
  in
  Context.put_global_function fn impstat term_opt context;
  Context.pop context






let analyze(ast: declaration list) (pc:Proof_context.t): unit =
  let context = Proof_context.context pc in
  let rec analyz (ast: declaration list): unit =
    let one_decl (d:declaration) =
      match d with
        Class_declaration (hm, cname, fgens, inherits) ->
          put_class hm cname fgens inherits pc
      | Named_feature (fn, entlst, rt, is_func, body, expr) ->
          put_feature fn entlst rt is_func body expr context
      | Assertion_feature (label, entlst, body) ->
          Prover.prove_and_store entlst body pc
      | Formal_generic (name, concept) ->
          Context.put_formal_generic name concept context
    in
    match ast with
      [] -> ()
      | f::t -> one_decl f; analyz t
  in
  analyz ast;
  if Proof_context.is_interface_check pc then
    Proof_context.check_interface pc
