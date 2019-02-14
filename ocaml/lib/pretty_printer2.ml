open Common
open Printf

module type PRINTER =
  sig
    include Monad.MONAD
    val putc: char -> unit t
    val put_string: string -> unit t
    val put_substring: string -> int -> int -> unit t
    val fill: char -> int -> unit t
  end


type alternative_text = string
type start = int
type length = int
type indent = int
type width  = int
type ribbon = int


module Document =
  struct
    type t =
      | Nil
      | Concat of t * t
      | Nest of int * t
      | Text of string * start * length
      | Line of alternative_text
      | Group of t

    let empty = Nil

    let (^) (a:t) (b:t): t = Concat(a,b)

    let nest (i:int) (a:t): t = Nest(i,a)

    let text (s:string): t = Text (s,0,String.length s)

    let text_sub (s:string) (i:start) (len:length): t = Text(s,i,len)

    let space: t = Line " "

    let cut: t   = Line ""

    let line (s:string): t = Line s

    let group (d:t): t = Group d

    let bracket (ind:indent) (l:string) (d:t) (r:string): t =
        group (text l ^ (nest ind (cut ^ d)) ^ cut ^ text r)

    let group_nested (ind:indent) (d:t): t =
      group (nest ind d)

    let group_nested_space (ind:indent) (d:t): t =
      nest ind (space ^ group d)
  end

type command =
  | Text of start * length * string
  | Line of alternative_text * indent



module State =
  struct
    type open_groups = int
    type position = int

    type t = {width: int;          (* desired maximal line width *)
              ribbon: int;         (* desired maximal ribbon width *)
              mutable line_indent: indent;
              mutable current_indent: indent;
              mutable p: position;
              mutable pe: position; (* all line breaks in pending group
                                       effective *)
              mutable oe: open_groups;  (* effective *)
              mutable oa: open_groups;  (* active *)
              mutable oa0: open_groups; (* active at pending line break *)
              mutable opr: open_groups; (* to the right of the pending group *)
              mutable buf: command list
             }


    let start (indent:int) (width:int) (ribbon:int): t =
      assert (0 <= indent);
      assert (0 <= width);
      assert (0 <= ribbon);
      {width; ribbon;
       current_indent = indent;   line_indent = indent;
       p = 0;  pe = 0;
       oe = 0; oa = 0; oa0 = 0; opr = 0;
       buf = []
      }

    let normal (st:t): bool =
      st.buf = []

    let buffering (st:t): bool =
      st.buf <> []


    let is_active_open (st:t): bool =
      (* Is there still a group enclosing the pending line break open? *)
      st.oa > 0

    let is_pending_open (st:t): bool =
      (* Is the group of the pending line break still open? *)
      assert (0 < st.oa0);
      let res = st.oa0 <= st.oa in
      if res then
        (assert (st.opr = 0);
         assert (st.oa > 0)
        );
      res


    let fits (len:int) (st:t): bool =
      let newpos = st.p + len
      in
      newpos <= st.width
      && newpos - st.line_indent <= st.ribbon

    let out_text(len:length) (st:t): unit =
      assert (normal st);
      st.p <- st.p + len

    let out_line (st:t): unit =
      assert (normal st);
      assert (st.oa = 0);  (* Otherwise we must start buffering. *)
      assert (st.opr = 0); (* There is no active group. *)
      st.p <- st.current_indent;
      st.line_indent <- st.current_indent

    let active_to_effective (st:t): unit =
      assert (normal st);
      assert (st.opr = 0);
      assert (st.oa0 = 0);
      st.oe <- st.oe + st.oa;
      st.oa <- 0


    let start_buffering (s:alternative_text) (st:t): unit =
      assert (normal st);
      assert (0 < st.oa);
      let len = String.length s in
      assert (fits len st);
      st.buf <- Line (s, st.current_indent) :: st.buf;
      st.oa0 <- st.oa;
      st.p <- st.p + len;
      st.pe <- st.current_indent


    let flush (flatten:bool) (st:t): command list =
      assert (buffering st);
      if flatten then
        (assert (not (is_pending_open st));
         st.oa <- st.oa + st.opr;
         st.opr <- 0;
         st.oa0 <- 0)
      else
        ( (* All open groups enclosing the pending line break (the active
             groups) become effective, all groups to the right of the pending
             group become the new active groups. *)
          st.oe <- st.oe + st.oa;
          st.oa <- st.opr;
          st.opr <- 0;
          st.oa0 <- 0;
          (* update p and line_indent *)
          st.p   <- st.pe;
          st.line_indent <- st.current_indent);
      let buf = List.rev st.buf in
      st.buf <- [];
      buf


    let buffer_text (s:string) (start:start) (len:length) (st:t): unit =
      assert (buffering st);
      assert (fits len st);
      st.buf <- Text (start,len,s) :: st.buf;
      st.p <- st.p + len;
      st.pe <- st.pe + len


    let buffer_line (s:alternative_text) (st:t): unit =
      assert (buffering st);
      let len = String.length s in
      assert (fits len st);
      assert (is_pending_open st);
      st.buf <- Line (s,st.current_indent) :: st.buf;
      st.p   <- st.p + len;
      st.pe  <- st.current_indent


    let increment_indent (i:indent) (st:t): unit =
      st.current_indent <- st.current_indent + i


    let decrement_indent (i:indent) (st:t): unit =
      assert (i <= st.current_indent);
      st.current_indent <- st.current_indent - i


    let open_group (st:t): unit =
      if normal st then
        (assert (st.opr = 0);
         st.oa <- st.oa + 1)
      else (* buffering *)
        if is_pending_open st then
          st.oa <- st.oa + 1
        else
          st.opr <- st.opr + 1


    let close_group (st:t): unit =
      if normal st then
        (assert (st.opr = 0);
         if st.oa > 0 then
           st.oa <- st.oa - 1
         else
           (assert (st.oe > 0);
            st.oe <- st.oe - 1)
        )
      else (* buffering *)
        if is_pending_open st then
          st.oa <- st.oa - 1
        else if st.opr > 0 then
          st.opr <- st.opr - 1
        else
          (assert (st.oa > 0);
           st.oa <- st.oa - 1)
  end (* State *)


module type PRETTY =
  sig
    include Monad.MONAD

    val text_sub: string -> start -> length -> unit t
    val text: string -> unit t
    val line: alternative_text -> unit t
    val cut: unit t
    val space: unit t
    val nest: indent -> 'a t -> unit t
    val group: 'a t -> unit t
    val fill_of_string: string -> unit t
    val fill_of_stringlist: string list -> unit t
    val chain: unit t list -> unit t
    val of_document: Document.t -> unit t
  end


module Make:
  functor (P:PRINTER) ->
  sig
    include PRETTY
    val run: int -> int -> int -> 'a t -> unit P.t
  end
  =
  functor (P:PRINTER) ->
  struct
    type state = State.t

    include
      Monad.Make(
          struct
            type 'a t = state -> 'a P.t
            let make (a:'a): 'a t =
              fun st -> P.make a
            let bind (m:'a t) (f:'a -> 'b t) (st:state): 'b P.t =
              P.(m st >>= fun a -> f a st)
          end
        )

    let print_nothing: unit P.t =
      P.make ()

    let out_command (flatten:bool) (c:command): unit P.t =
      match c with
      | Text (start,len,s) ->
         P.put_substring s start len
      | Line (s, i) ->
         if flatten then
           P.put_string s
         else
           P.(putc '\n' >>= fun _ -> fill ' ' i)

    let out_text (s:string) (start:start) (len:length) (st:state): unit P.t =
      State.out_text len st;
      P.put_substring s start len


    let flush (flatten:bool) (st:state): unit P.t =
      let buf = State.flush flatten st in
      let rec write buf =
        match buf with
        | [] ->
           assert false (* buffer cannot be empty *)
        | [c] ->
           out_command flatten c
        | c :: buf ->
           P.(out_command flatten c >>= fun _ ->
              write buf)
      in
      write buf

    let text_sub (s:string) (start:int) (len:int) (st:state): unit P.t =
      assert (0 <= start);
      assert (start+len <= String.length s);
      if State.normal st then
        out_text s start len st
      else if State.fits len st then
        (State.buffer_text s start len st;
         print_nothing)
      else
        (flush false >>= fun _ -> out_text s start len) st


    let text (s:string): unit t =
      text_sub s 0 (String.length s)


    let line_normal (s:alternative_text) (st:state): unit P.t =
      assert (State.normal st);
      let len = String.length s
      in
      if State.is_active_open st && State.fits len st then
        (State.start_buffering s st;
         print_nothing)
      else
        (State.active_to_effective st;
         State.out_line st;
         P.(putc '\n' >>= fun _ ->
            fill ' ' st.State.line_indent))


    let line_buffering (s:alternative_text) (st:state): unit P.t =
      assert (State.buffering st);
      if State.is_pending_open st then
        if State.fits (String.length s) st then
          (State.buffer_line s st;
           print_nothing)
        else
          (flush false >>= fun _ -> line_normal s) st
      else
        (flush true >>= fun _ -> line_normal s) st


    let line (s:string) (st:state): unit P.t =
      if State.normal st then
        line_normal s st
      else
        line_buffering s st



    let cut: unit t =
      line ""

    let space: unit t =
      line " "

    let nest (i:int) (m:'a t): unit t =
      let start st =
        State.increment_indent i st;
        print_nothing
      and close st =
        State.decrement_indent i st;
        print_nothing
      in
      start >>= fun _ -> m >>= fun _ -> close


    let group (m:'a t): unit t =
      let start st =
        State.open_group st;
        print_nothing
      and close st =
        State.close_group st;
        print_nothing
      in
      start >>= fun _ ->
      m >>= fun _ ->
      close


    let rec chain (l: unit t list) (st:state): unit P.t =
      match l with
      | [] ->
         print_nothing
      | hd :: tl ->
         P.(hd st >>= fun _ -> chain tl st)

    let fill_of_string (s:string) (st:state): unit P.t =
      let word_start i = String.find (fun c -> c <> ' ') i s
      and word_end   i = String.find (fun c -> c =  ' ') i s
      and len = String.length s
      in
      let rec fill p =
        let i = word_start p in
        (if p < i then
           group space
         else
           make ())
        >>= fun _ ->
        if i < len then
          let j = word_end i in
          text_sub s i (j-i) >>= fun _ ->
          fill j
        else
          make ()
      in
      fill 0 st


    let fill_of_stringlist (l:string list) (st:state): unit P.t =
      let rec fill l first =
        match l with
        | [] ->
           make ()
        | s :: tl ->
           let body = fill_of_string s >>= fun _ -> fill tl false in
           if first then
             body
           else
             group space >>= fun _ -> body
      in
      fill l true st


    let rec of_document (d:Document.t): unit t =
      match d with
      | Document.Nil ->
         make ()
      | Document.Text (s,i,len) ->
         text_sub s i len
      | Document.Line s ->
         line s
      | Document.Concat (a,b) ->
         of_document a >>= fun _ ->
         of_document b
      | Document.Nest (i,d) ->
         nest i (of_document d)
      | Document.Group d ->
         group (of_document d)

    let run (indent:int) (width:int) (ribbon:int) (m:'a t): unit P.t =
      let st = State.start indent width ribbon in
      P.(m st >>= fun _ ->
         if State.buffering st then
           flush true st
         else
           print_nothing)
  end

module Pretty_string =
  struct
    include Make (Monad.String_buffer)
    let string_of (pp:'a t) (size:int) (ind:indent) (w:width) (r:ribbon): string =
      Monad.String_buffer.run
        size
        (run ind w r pp)
  end


let test () =
  let open Printf in
  printf "test pretty printer 2\n";
  let module PP = Make (Monad.String_buffer) in
  let open PP
  in
  let formatw p_flag w pp =
    let s = Pretty_string.string_of pp 200 0 w w in
    if p_flag then
      printf "%s\n" s;
    s
  in

  begin
    let str = "01234 6789 0 2 4 6 8 01 34 6789 0"
    and strlst = ["01234"; "6789 0 2"; "4 6 8 01 34"; "6789 0"]
    and res = "01234 6789\n0 2 4 6 8\n01 34 6789\n0"
    in
    assert (formatw false 10 (fill_of_string str) = res);
    assert (formatw false 10 (fill_of_stringlist strlst) = res);
  end;

  assert
    begin
      formatw
        false 10
        (nest 4 (chain [text "0123"; cut; text "456"]) >>= fun _ ->
        chain [cut; text "0123"])
      = "0123\n    456\n0123"
    end;

  assert
    begin
      formatw
        false 20
        (group
           (chain [
                (group (chain
                          [text "class";
                           nest 4 (chain [space; text "Natural"]);
                           space; text "create"]));
                nest 4
                  (chain
                     [space;
                      (group
                         (chain
                            [text "0"; line "; "; text "succ(Natural)"]))
                     ]
                  );
                chain [space; text "end"]
              ]
        ))
      = "class Natural create\n    0; succ(Natural)\nend"
    end;

  begin
    let maybe =
      Document.(
        group (group (text "class"
                      ^ nest 4 (space ^ text "Maybe(A)")
                      ^ space
                      ^  text "create")
             ^ nest 4 (space
                       ^ group (text "nothing" ^ line "; " ^ text "just(A)"))
             ^ space
             ^ text "end")
      )
    in
    let maybe = of_document maybe
    in
    assert(
        formatw false 70 maybe
        = "class Maybe(A) create nothing; just(A) end"
      );
    assert(
        formatw false 20 maybe
        = "class\n    Maybe(A)\ncreate\n    nothing; just(A)\nend"
      );
    assert(
        formatw false 15 maybe
        = "class\n    Maybe(A)\ncreate\n    nothing\n    just(A)\nend"
      )
  end
