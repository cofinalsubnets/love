---
title: LOVE
section: 1
source: love @VERSION@
manual: love manual
---

# NAME

love - a curried lisp over a tiny generic core

# SYNOPSIS

**love** \[**-l** *lib*\] \[**-e** *expr*\] \[**-v**\] \[**-h**\] \[**--**\] \[*file* \[*arg* ...\]\]

# DESCRIPTION

**love** is a small lisp in which every value is a total function of one argument and application is left-to-right currying: (*f* *x* *y*) is ((*f* *x*) *y*) and (*f*) is *f*. Numbers are Church numerals, a list of numbers is a tower of exponents, and data self-applies (it indexes). The core is fully generic: every operation dispatches on a value's kind, and the kinds form a lattice ordered by a single total order over all values.

There are three special forms — **:** (letrec\*/sequence), **?** (cond), and **\\** (lambda, or quote with a single operand) — and everything else is a function call. Truth is the net measure: a value is false when it nets to nothing and true when it nets positive.

With a *file* argument (or **-e**), **love** runs it as the program and exits; any further arguments are the program's, in **argv**. With no program it starts an interactive read-eval-print loop when standard input is a terminal, and otherwise reads and evaluates standard input to end of file.

A first word that names a verb runs that verb instead, with the words after it: `love verbs` lists them. A verb is the binary's own, baked or carried as source and read at its first call, or a pack's. A pack is a folder in the nest's `pack/`, named by the folder, whose `.l` files are read at the first call of a verb they register or the first `borrow` of a module they open, each file after the ones holding modules it needs. A pack with no verb is a library. The binary's verbs always win over a pack's, and `love pack` lists each pack, its verbs and modules, and any name another one answers first.

# OPTIONS

The short flags cluster: **-qe** *expr* is **-q** **-e** *expr*. A letter that takes an argument ends the chain and takes the rest of its own word, or the next word when there is no rest — so **-m8m** and **-m** *8m* are the same. A word carrying a letter that is not an option does not cluster at all, and reaches the *file* lane whole.

**-l** *lib*, **--load** *lib*
:   Preload *lib* (read-eval it to end of file) before the program. May be repeated.
**-e** *expr*, **--eval** *expr*
:   Read-eval the forms in *expr*, as the program, and print the answer through **show**.
**-q**, **--quiet**
:   With **-e**, do not print the answer. The status is unchanged.
**-m** *size*, **--memory** *size*
:   Cap the heap at *size*, suffixed **k**, **m** or **g**. **0m**, the default, is unlimited. The last **-m** wins.
**-v**, **--version**
:   Print the version. Not terminal: the walk carries on, so `love -v -e 1` prints both.
**-h**, **--help**
:   Print a usage summary. Not terminal either, and neither excludes the other.
**--**
:   End option processing: the next argument is the program, the rest are its arguments.
*file*
:   A program to load. The first *file* is the program; further arguments are passed to it in **argv**. A file that cannot be opened is a fatal error.

# EXAMPLES

Evaluate a file:

> ```
> love prog.l
> ```

Load a library, then run a script:

> ```
> love -l lib.l prog.l
> ```

Evaluate an expression:

> ```
> love -e '(. (+ 1 2))'
> ```

Evaluate from standard input:

> ```
> echo '(+ 1 2)' | love
> ```

Start the interactive shell:

> ```
> love
> ```

# ENVIRONMENT

**LOVE_NEST**
:   The nest, where love keeps its settings (`etc/`), its install (`bin/`), its run state (`run/`) and its packs (`pack/`). `$HOME/.love` when unset or empty, and `/.love` with no `HOME`.

# FILES

`~/.love/pack/NAME/`
:   A pack: its `.l` files, read as one unit when it is first needed.

# EXIT STATUS

**love** exits **0** on success and non-zero on a fatal error, such as a file that cannot be opened or an explicit (*exit* *n*).

# SEE ALSO

The project README and the executable specification in *test/spec.l*, which asserts every claim of the language on every build target.
