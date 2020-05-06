open Fmlib
open Common



type t = {
    gamma: Gamma.t;
    map: Name_map.t
  }



let count (c: t): int =
    Gamma.count c.gamma



let gamma (c: t): Gamma.t =
    c.gamma



let name_map (c: t): Name_map.t =
    c.map


let standard (): t =
    let gamma = Gamma.standard () in
    {gamma;
     map =
        Interval.fold
            Name_map.empty
            (fun i m ->
                let open Gamma in
                match
                    Name_map.add_global
                        (name_at_level i gamma)
                        (type_at_level i gamma)
                        gamma
                        m
                with
                | None ->
                    Printf.printf "Context.standard Cannot add %s\n"
                        (name_at_level i gamma);
                    assert false
                | Some map ->
                    map
            )
            0
            (Gamma.count gamma)
    }


let compute (t: Term.t) (c: t): Term.t =
    Gamma.compute t c.gamma


let find_name (name: string) (c: t): int list =
    Name_map.find name c.map


let add_definition
    (name: string) (typ: Term.typ) (exp: Term.t) (c: t): t option
=
    Option.map
        (fun map ->
            {
                map;

                gamma =
                    Gamma.push_definition name typ exp c.gamma
            })
        (Name_map.add_global
            name
            typ
            c.gamma
            c.map)



module Pretty (P: Pretty_printer.SIG) =
struct
    module P0 = Term_printer.Pretty (Gamma) (P)

    let print (t:Term.t) (c:t): P.t =
        P0.print t c.gamma
end
