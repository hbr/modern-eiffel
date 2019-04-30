[![Build Status](https://travis-ci.org/hbr/albatross.svg?branch=develop)](https://travis-ci.org/hbr/albatross)

# General

This repository holds the sources for the Albatross compiler.

The language Albatross allows static verification (i.e. correctness proofs) of
programs.

The albatross compiler is a proof assistant and a compiler for the Albatross
language.


# Documentation

[Language Description](http://www.gitbook.com/book/hbr/alba-lang-description)


# Installation

Prerequisites:

You need to have the Ocaml compile and the Ocaml package manager `opam`
installed.

- `opam install alba`

In order to work with the Albatross compiler you have to install and compile
the basic library.

- `mkdir <alba-libs>`
- `cd <alba-libs>`
- `wget https://github.com/hbr/alba.base/archive/x.y.z.tar.gz` where `x.y.z`
  is the version of the library you want to install.
- `tar xzf x.y.z.tar.gz`
- `mv alba.base-x.y.z alba.base`
- `alba init -work-dir alba.base`
- `alba compile -work-dir alba.base`


After the installation you can go the source directory of your Albatross
sources and issue

    alba init                    -- to initialize the directory
    alba compile -I <alba-libs>  -- to compile your sources


Instead of using the `-I` option explicitly to indicate the location of the
libraries you can also set the environment variable `ALBA_LIBRARY_PATH` to
<alba-libs> and then ommit the `-I <alba-libs>`.




<!---
Local Variables:
mode: outline
coding: iso-latin-1
outline-regexp: "#+"
End:
-->
