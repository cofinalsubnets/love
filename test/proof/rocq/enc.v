(* enc.v -- a proven x86-64 encoder for mov + the reg-reg alu ops (REX + opcode
   + ModRM mod=11); decode inverts encode over all 16x16 registers x 7 ops *)

From Stdlib Require Import List Arith Bool.
Import ListNotations.

Definition byte := nat.
Definition reg  := nat.

Inductive op := Omov | Oadd | Osub | Oand | Oor | Oxor | Ocmp.

(* primary opcode for the "r/m64, r64" (/r) direction: r/m = dest, reg = src *)
Definition opcode (o:op) : byte :=
  match o with
  | Omov => 137 | Oadd => 1  | Osub => 41
  | Oand => 33  | Oor  => 9  | Oxor => 49 | Ocmp => 57
  end.

Definition op_eqb (a b:op) : bool :=
  match a, b with
  | Omov,Omov | Oadd,Oadd | Osub,Osub | Oand,Oand
  | Oor,Oor | Oxor,Oxor | Ocmp,Ocmp => true
  | _,_ => false
  end.

(* REX 0100_WRXB: W=1, X=0, R iff src>=8 (ModRM.reg), B iff dest>=8 (ModRM.rm) *)
Definition rex (dest src:reg) : byte :=
  64 + 8 + (if 7 <? src then 4 else 0) + (if 7 <? dest then 1 else 0).

(* ModRM: mod=11 (register direct), reg = src low 3 bits, rm = dest low 3 bits *)
Definition modrm (dest src:reg) : byte :=
  192 + (src mod 8) * 8 + (dest mod 8).

(* REX with W=0, for the zeroing idiom only *)
Definition rex0 (dest src:reg) : byte :=
  64 + (if 7 <? src then 4 else 0) + (if 7 <? dest then 1 else 0).

(* `xor r,r` zeroes through the 32-bit form: W=0, and no REX at all for r<8.
   op carries no width, so the short form still decodes to (Oxor,r,r) *)
Definition zeroing (o:op) (dest src:reg) : bool :=
  op_eqb o Oxor && (dest =? src).

Definition encode (o:op) (dest src:reg) : list byte :=
  if zeroing o dest src
  then (if 7 <? dest
        then [ rex0 dest src ; opcode o ; modrm dest src ]
        else [ opcode o ; modrm dest src ])
  else [ rex dest src ; opcode o ; modrm dest src ].

(* --- decoder --- *)
Definition decode_op (b:byte) : option op :=
  if b =? 137 then Some Omov else if b =? 1  then Some Oadd
  else if b =? 41 then Some Osub else if b =? 33 then Some Oand
  else if b =? 9  then Some Oor  else if b =? 49 then Some Oxor
  else if b =? 57 then Some Ocmp else None.

(* two bytes: the REX-less zeroing form. the three-byte arm ignores W *)
Definition decode (bs:list byte) : option (op * reg * reg) :=
  match bs with
  | [oc; mr] =>
    match decode_op oc with
    | None => None
    | Some o =>
      let m := mr - 192 in
      Some (o, m mod 8, (m / 8) mod 8)
    end
  | [r; oc; mr] =>
    match decode_op oc with
    | None => None
    | Some o =>
      let bB := r mod 2 in           (* REX.B  -> dest high bit *)
      let bR := (r / 4) mod 2 in     (* REX.R  -> src  high bit *)
      let m  := mr - 192 in
      let rm_low  := m mod 8 in
      let reg_low := (m / 8) mod 8 in
      Some (o, rm_low + 8 * bB, reg_low + 8 * bR)
    end
  | _ => None
  end.

Definition all_ops : list op := [Omov;Oadd;Osub;Oand;Oor;Oxor;Ocmp].

(* exhaustive round-trip over the finite domain: every op, every dest, src < 16 *)
Definition roundtrips_all : bool :=
  forallb (fun o =>
    forallb (fun d =>
      forallb (fun s =>
        match decode (encode o d s) with
        | Some (o', d', s') => op_eqb o o' && (d =? d') && (s =? s')
        | None => false
        end) (seq 0 16)) (seq 0 16)) all_ops.

Theorem roundtrip_ok : roundtrips_all = true.
Proof. vm_compute. reflexivity. Qed.

Print Assumptions roundtrip_ok.   (* must stay "Closed under the global context" *)

(* --- extraction --- nat -> int: the proof stays over nat *)
From Stdlib Require Import Extraction.
Extraction Language OCaml.
Set Extraction Output Directory ".".
Extract Inductive nat => "int"
  [ "0" "(fun x -> x + 1)" ]
  "(fun zero succ n -> if n = 0 then zero () else succ (n - 1))".
Extract Inductive list => "list" [ "[]" "(::)" ].
Extract Inductive bool => "bool" [ "true" "false" ].
Extract Inlined Constant Nat.add     => "(+)".
Extract Inlined Constant Nat.mul     => "( * )".
Extract Inlined Constant Nat.modulo  => "(mod)".
Extract Inlined Constant Nat.ltb     => "(<)".
Extraction "enc_ref.ml" encode all_ops opcode.
