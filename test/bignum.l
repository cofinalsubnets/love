; bignums: overflow promotes, a result that fits a smaller tier demotes back

(: (bfact n) (n < 2 ? 1 (n * bfact (n - 1)))
   (bpow2 n) (n < 1 ? 1 (2 * bpow2 (n - 1)))
   B100 (bpow2 100)
   F25 (bfact 25)
   F24 (bfact 24)
   ; KL-limb operands take karatsuba; Kref splits KA in halves, on schoolbook, as a check
   KL 150  KE (64 * KL)  KHE (64 * (KL // 2))
   KA (KE 2 - 1)  KBb (KE 2 - 7)  KHB (KHE 2)   ; (KE 2) = 2^KE, no deep recursion
   KP (KA * KBb)
   Kref (((KA % KHB) * KBb) + (((KA // KHB) * KBb) * KHB))
   ; near-equal lengths take it too (200 limbs by 150)
   KC ((64 * 200) 2 - 3)  KHC ((64 * 100) 2)
   KCref (((KC % KHC) * KBb) + (((KC // KHC) * KBb) * KHC)))

(test
 ; --- overflow promotion, read round-trip against a literal ---
 (F25 = 15511210043330985984000000)
 (B100 = 1267650600228229401496703205376)
 (1000000000000 * 1000000000000 = 1000000000000000000000000)
 (F25 + 1 = 15511210043330985984000001)
 (F25 - 1 = 15511210043330985983999999)
 (bpow2 200 = B100 * B100)
 (bpow2 64 = 18446744073709551616)

 ; --- karatsuba vs schoolbook ---
 (KP = Kref)
 (KP = KBb * KA)
 (KA = KP // KBb) ; cross-checks knuth-d
 (0 = KP % KBb)
 (KA * KA = KA * KA)                  ; the na==nb self-multiply lane
 (KC * KBb = KCref) (KBb * KC = KCref) (KC = (KC * KBb) // KBb)

 ; --- a bignum is its own tier: not a fixnum, truthy, not falsy, not a chain ---
 !(charm? B100)
 (B100 ? 1 0)
 !!B100
 (atom? B100)

 ; --- canonical demotion: shrinking results fall back to the smallest tier ---
 (0 = F25 - F25)
 (charm? (F25 - F25))
 ; exact bignum `/` stays an integer; an inexact one is a float
 (25 = F25 / F24)
 (charm? (F25 / F24))
 (F24 = F25 / 25)
 (1 = B100 / B100)
 (charm? (B100 / B100))
 (gem? (B100 / 7))
 (25 = F25 // F24)

 ; --- divmod identities: a == (a//b)*b + a%b ---
 (B100 = B100 // 1000000007 * 1000000007 + B100 % 1000000007)
 (B100 = B100 // bpow2 40 * bpow2 40 + B100 % bpow2 40)
 (F25 = F25 // F24 * F24 + F25 % F24)
 (2 = B100 % 7)

 ; --- signs: `//` truncates toward zero, remainder follows the dividend ---
 (-25 = -F25 // F24)
 (25 = -F25 // -F24)
 (-25 = F25 // -F24)
 (-2 = -B100 % 7)
 (2 = B100 % -7)
 (-2 = -B100 % -7)
 (-B100 = -1 * B100)
 (B100 = --B100)
 (-B100 = -1267650600228229401496703205376)

 ; --- the lone INT_MIN/-1 case: -2^63 // -1 is the exact 2^63, %-1 is 0 ---
 (bpow2 63 = -(bpow2 63) // -1)
 (0 = -(bpow2 63) % -1)

 ; --- mixed-tier comparison (fixnum / box / bignum) ---
 (F24 < F25)
 (F25 > F24)
 (F25 <= F25)
 (F25 >= F25)
 (5 < B100)
 (-B100 < 5)
 (-B100 < B100)
 (F25 = bfact 25)
 !(F25 = B100)
 !(B100 = B100 + 1)
 (B100 < B100 + 1)

 ; --- mixed with floats: a float operand widens the bignum to double ---
 (gem? (B100 + 0.5))
 (gem? (B100 * 1.0))
 (B100 < 1e40)
 (B100 > 1e20)
 (0 = B100 * 0)
 (charm? (B100 * 0))

 ; --- printer round-trip (base 10, with sign) ---
 ("1267650600228229401496703205376" = show B100)
 ("-1267650600228229401496703205376" = show (0 - B100))
 ("9223372036854775808" = show (bpow2 63))
 ("15511210043330985984000000" = show F25)

 ; --- bignums as hash keys (eqv over slen+limbs) ---
 ('hit = peep (pin (pin {} F25 'fk) B100 'hit) B100 'miss)
 ('fk = peep (pin (pin {} F25 'fk) B100 'hit) F25 'miss)
 ('miss = peep (pin {} B100 'hit) (B100 + 1) 'miss)

 ; --- prel ** / gcd / modpow (the float `power` nif is tested in math.l) ---
 (8 = 3 2)
 (charm? (3 2))
 (B100 = 100 2)
 (bpow2 200 = 200 2)
 (1 = 0 999)
 (1024 = 10 2)
 (21 = gcd 1071 462)
 (21 = gcd 462 1071)
 (4 = gcd -12 8)     ; normalized non-negative
 (4 = gcd 12 -8)
 (F24 = gcd F25 F24)
 (1 = gcd B100 (B100 + 1))
 (976371285 = modpow 2 100 1000000007)
 (1 = modpow 7 0 100)
 (B100 % 1000000007 = modpow 2 100 1000000007)

 ; --- int array vs bignum: ordered by magnitude, not low bits (2^100's low word is 0) ---
 (aall (star-tray '(3) '(1 2 3) < B100))
 (aall (star-tray '(3) '(1 2 3) <= B100))
 !(aall (star-tray '(3) '(1 2 3) > B100))
 !(aall (star-tray '(3) '(1 2 3) >= B100))
 (aall (star-tray '(3) '(1 2 3) > -B100))
 (aall (-B100 < star-tray '(3) '(1 2 3)))
 !(aall (star-tray '(2) '(0 0) = B100)))

; --- bitlen: the bits of the magnitude, 2^(n-1) <= |x| < 2^n ---
(test (0 = bitlen 0) (1 = bitlen 1) (1 = bitlen -1) (10 = bitlen 1023) (11 = bitlen 1024)
      (62 = bitlen (62 2 - 1)) (63 = bitlen (62 2)) (64 = bitlen (0 - 63 2)) (65 = bitlen (64 2))
      (100 = bitlen (100 2 - 1)) (101 = bitlen (100 2)) (101 = bitlen (0 - 100 2))
      (() = bitlen 1.5) (() = bitlen "10") (() = bitlen ()))

; --- show by halves at levels 10^(18 2^j): digits at each level's edge, zero runs, read-back
(: (bn-ones d k) (string (map (_ \ d) (jot k)))
   (bn-back x) (x = <(sound (show x)))
   ks [77 78 144 145 288 576 1152 2304 4608 4609 9216 18432]
   (test (all (k \ show (k 10) = "1" + bn-ones 48 k) ks)
         (all (k \ show (k 10 - 1) = bn-ones 57 k) ks)
         (all (k \ show (k 10 + 1) = "1" + bn-ones 48 (k - 1) + "1") ks)
         (all (k \ show (0 - k 10) = "-1" + bn-ones 48 k) ks)
         (show (300 10 * (300 10 + 7)) = "1" + bn-ones 48 299 + "7" + bn-ones 48 300)
         (all bn-back [(40000 3) (20000 7) (0 - 30000 3) (70000 2 - 1) (70000 2) ((5000 10 + 1) * (9000 10 - 1))])))


; --- read by halves: 19 digits a limb, joined in pairs as hi 10^(19 w) + lo; hex and
; octal pack their bits
(: (bn-rd s) <(sound s)
   (bn-ones d k) (string (map (_ \ d) (jot k)))
   (bn-rep s r) (string (cats (map (_ \ s) (jot r))))
   ks [1400 1463 1464 1520 1521 2432 2433 4864 4865 9728 20000]
   (test (all (k \ bn-rd ("1" + bn-ones 48 k) = k 10) ks)
         (all (k \ bn-rd (bn-ones 57 k) = k 10 - 1) ks)
         (all (k \ bn-rd ("+1" + bn-ones 48 (k - 1) + "1") = k 10 + 1) ks)
         (all (k \ bn-rd ("-7" + bn-ones 48 k) = 0 - 7 * k 10) ks)
         (all (r \ bn-rd (bn-rep "123456789" r) = 123456789 * ((9 * r) 10 - 1) // 999999999) [160 167 333 1000])
         (all (k \ bn-rd ("0x1" + bn-ones 48 k) = (4 * k) 2) [15 16 17 1000 4097])
         (bn-rd ("0x" + bn-ones 102 3000) = 12000 2 - 1) (bn-rd ("0X" + bn-ones 70 3000) = 12000 2 - 1)
         (bn-rd ("-0x" + bn-rep "f0" 1000) = 0 - (240 * (8000 2 - 1) // 255))
         (all (k \ bn-rd ("01" + bn-ones 48 k) = (3 * k) 2) [21 22 23 1000 4097])
         (bn-rd ("0" + bn-ones 55 4000) = 12000 2 - 1)
         (all (x \ bn-rd ("0x" + radix x 16) = x) [(40000 3) (5000 7 + 1) (64 2) (64 2 - 1)])))

; --- radix by halves, as show: a level is r^k, k0 the most a charm holds
(: (bn-dv c) (c < 58 ? (c - 48) (c - 87))
   (bn-ones d k) (string (map (_ \ d) (jot k)))
   (bn-unradix s b) (foldl (a \ c \ a * b + bn-dv c) 0 (chars s))
   x (3000 3)
   (test (radix x 10 = show x) (radix (0 - x) 16 = "-" + radix x 16)
         (#(radix x 2) = bitlen x) (#(radix (40000 3) 2) = bitlen (40000 3))
         (all (b \ bn-unradix (radix x b) b = x) [2 3 7 8 10 16 36])
         (all (k \ radix (k 16) 16 = "1" + bn-ones 48 k) [15 16 30 31 60 120 240 2048 2049 4096])
         (all (k \ radix (k 16 - 1) 16 = bn-ones 102 k) [15 16 30 31 60 2048 2049])
         (all (k \ radix (k 7) 7 = "1" + bn-ones 48 k) [22 23 44 45 88 1000 3001])
         (all (k \ radix (k 2) 2 = "1" + bn-ones 48 k) [61 62 63 124 4096 4097])))

; --- lopsided products: past twice the shorter's width the longer goes in karatsuba pieces
(: LA (40000 3) LB (3000 7)
   (bn-pieces a b) (: w (bitlen b) mk (w 2 - 1)
                      (go a i acc) (a = 0 ? acc (go (a >> w) (i + w) (acc + (((a & mk) * b) << i))))
                      (go a 0 0))
   P4 (64 * 528) P1 (64 * 132) P2 (64 * 265)
   (test (LA * LB = bn-pieces LA LB) (LB * LA = LA * LB)
         ((LA * LB) // LB = LA) ((LA * LB) % LB = 0)
         ((0 - LA) * LB = 0 - LA * LB) (LA * (0 - LB) = 0 - LA * LB)
         ((P4 2 - 1) * (P1 2 - 1) = (P4 + P1) 2 - P4 2 - P1 2 + 1)
         ((P2 2 - 5) * (P1 2 - 7) = (P2 + P1) 2 - 7 * P2 2 - 5 * P1 2 + 35)
         (LA * (1920 2 - 1) = (LA << 1920) - LA)
         ((50000 3) * (2600 2 + 1) = ((50000 3) << 2600) + 50000 3)))
