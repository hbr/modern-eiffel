(** Fmlib: Functional Monadic Library *)


(** {1 Basics} *)


val identity: 'a -> 'a
(** Identity function *)


module Module_types  = Module_types


module List = List

module Option = Option

module Result = Result

module Finite_map = Finite_map

module Segmented_array = Segmented_array



module Monad = Monad



module Array = Array
module Vector = Vector
module Pool = Pool



module Common = Common




(** {1 Parsing }*)

module Character_parser = Character_parser
module Generic_parser   = Generic_parser


(** {1 Pretty Printing }*)

module Pretty_printer = Pretty_printer



(** {1 IO }*)

module Io = Io

module Make_io = Make_io

module String_printer = String_printer



(** {1 Web Applications} *)

module Web_application = Web_application


(** {1 Old modules (deprecated)} *)

module Argument_parser = Argument_parser
