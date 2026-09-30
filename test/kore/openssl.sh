#!/bin/sh
# test/kore/openssl.sh -- openssl: x509, verify, dgst, rand, base64, genpkey, req, x509 -req, and bad input
. "$(dirname "$0")/common.sh"

# the chain fixtures are test/host/tlschain's (gen.sh lays them). the fixed answers below
# are the host openssl's own, pinned, so the check stands where no openssl is installed;
# where one is and it speaks openssl 3's current face, whole outputs are compared too.
tc=test/host/tlschain
d=$ho/.kore-openssl
rm -rf "$d"; mkdir -p "$d"
k() { korerun openssl "$@"; }
is() { [ "$2" = "$3" ] || fail "kore openssl $1: got \"$2\""; }
# a run that must fail cleanly: its exit code, and no scare on err
clean() { n=$1; want=$2; shift 2
          k "$@" > "$o" 2> "$d/err"; r=$?
          [ $r -eq "$want" ] || fail "kore openssl $n (exit $r)"
          grep -q '^;;' "$d/err" && fail "kore openssl $n scared: $(head -1 "$d/err")"; :; }

# --- the door ---
is version "$(k version)" "love kore openssl (a subset; not OpenSSL)"
clean "with no command" 1
clean "an unknown command" 1 nosuch
grep -q "^Invalid command 'nosuch'" "$d/err" || fail "kore openssl nosuch: no complaint"

# --- x509, answers pinned from openssl 3.6 ---
is subject "$(k x509 -in $tc/leafr.pem -noout -subject)" "subject=CN=leafr"
is issuer "$(k x509 -in $tc/leafr.pem -noout -issuer)" "issuer=CN=interr"
is serial "$(k x509 -in $tc/leafr.pem -noout -serial)" "serial=30721B40F3DE43F9"
is fingerprint "$(k x509 -in $tc/leafr.pem -noout -fingerprint)" \
  "SHA1 Fingerprint=9F:A7:09:51:65:D4:28:E2:5C:22:FF:C1:C2:2B:21:E9:08:6F:0D:07"
is "fingerprint -sha256" "$(k x509 -in $tc/leafr.pem -noout -fingerprint -sha256)" \
  "sha256 Fingerprint=17:E7:59:FB:62:D5:9E:C8:FB:D4:D4:36:E2:F8:53:DE:F3:EB:1E:D1:84:89:02:C0:C7:37:31:2C:B2:C7:90:17"
is dates "$(k x509 -in $tc/leafr.pem -noout -dates | tr '\n' '|')" \
  "notBefore=Jan  1 00:00:00 2025 GMT|notAfter=Jan  1 00:00:00 2035 GMT|"
k x509 -in $tc/leafr.pem -noout -text > "$o"
grep -q '^                DNS:good.test, DNS:\*.wild.test, IP Address:127.0.0.1$' "$o" || fail "kore openssl x509 -text: the SAN"
grep -q '^        Serial Number: 3490882626948842489 (0x30721b40f3de43f9)$' "$o" || fail "kore openssl x509 -text: the serial"
grep -q '^                Public-Key: (2048 bit)$' "$o" || fail "kore openssl x509 -text: the key"
k x509 -in $tc/roote.pem -noout -text > "$o"
grep -q '^                NIST CURVE: P-384$' "$o" || fail "kore openssl x509 -text: the curve"
grep -q '^                Certificate Sign, CRL Sign$' "$o" || fail "kore openssl x509 -text: the key usage"
is -ext "$(k x509 -in $tc/leafe.pem -noout -ext keyUsage,subjectAltName | tr '\n' '|')" \
  "X509v3 Key Usage: critical|    Digital Signature|X509v3 Subject Alternative Name: |    DNS:good.test|"
# the certificate back out, pem and der, and the der read back
k x509 -in $tc/leafe.pem > "$o"; cmp -s "$o" $tc/leafe.pem || fail "kore openssl x509: the pem back out"
k x509 -in $tc/leafr.pem -outform DER -out "$d/l.der" || fail "kore openssl x509 -outform DER"
is "-inform DER" "$(k x509 -inform DER -in "$d/l.der" -noout -subject)" "subject=CN=leafr"
is "stdin" "$(k x509 -noout -subject < $tc/leafe.pem)" "subject=CN=leafe"
is "der fingerprint" "$(k x509 -in "$d/l.der" -noout -fingerprint -sha256 | tr -d ':' | cut -d= -f2 | tr 'A-F' 'a-f')" \
  "$(sha256sum < "$d/l.der" | cut -d' ' -f1)"
clean "x509 no file" 1 x509 -in "$d/none.pem"
clean "x509 an unknown option" 1 x509 -bogus

# --- verify: every kind of failure the fixtures carry, as openssl numbers it ---
cat $tc/rootr.pem $tc/interr.pem > "$d/rr.pem"
cat $tc/inter0.pem $tc/inter1.pem > "$d/i01.pem"
is "verify ok" "$(k verify -CAfile "$d/rr.pem" $tc/leafr.pem)" "$tc/leafr.pem: OK"
is "verify -untrusted" "$(k verify -CAfile $tc/rootr.pem -untrusted $tc/interr.pem $tc/leafr.pem)" "$tc/leafr.pem: OK"
is "verify SSL_CERT_FILE" "$(SSL_CERT_FILE=$d/rr.pem korerun openssl verify $tc/leaf512.pem)" "$tc/leaf512.pem: OK"
is "verify, no purpose asked" "$(k verify -CAfile "$d/rr.pem" $tc/client.pem)" "$tc/client.pem: OK"
vfail() { n=$1; want=$2; shift 2
          k verify "$@" > "$o" 2> "$d/err"; r=$?
          [ $r -eq 2 ] || fail "kore openssl verify $n (exit $r)"
          grep -q "^$want\$" "$d/err" || fail "kore openssl verify $n: $(grep '^error [0-9]' "$d/err")"; }
vfail expired "error 10 at 0 depth lookup: certificate has expired" -CAfile "$d/rr.pem" $tc/expired.pem
vfail notyet "error 9 at 0 depth lookup: certificate is not yet valid or the system clock is incorrect" -CAfile "$d/rr.pem" $tc/notyet.pem
vfail "no issuer" "error 20 at 0 depth lookup: unable to get local issuer certificate" -CAfile "$d/rr.pem" $tc/undernoca.pem
vfail "not a ca" "error 24 at 1 depth lookup: invalid CA certificate" -CAfile $tc/rootr.pem -untrusted $tc/noca.pem $tc/undernoca.pem
vfail "no keyCertSign" "error 32 at 1 depth lookup: key usage does not include certificate signing" -CAfile $tc/rootr.pem -untrusted $tc/nosign.pem $tc/undernosign.pem
vfail pathlen "error 25 at 2 depth lookup: path length constraint exceeded" -CAfile $tc/rootr.pem -untrusted "$d/i01.pem" $tc/deep.pem
vfail critical "error 34 at 0 depth lookup: unhandled critical extension" -CAfile "$d/rr.pem" $tc/crit.pem
vfail "self-signed" "error 18 at 0 depth lookup: self-signed certificate" -CAfile $tc/interr.pem $tc/rootr.pem
grep -q "^error $tc/rootr.pem: verification failed\$" "$d/err" || fail "kore openssl verify: the file's failure line"
# a signature with its last byte changed
n=$(wc -c < "$d/l.der"); head -c $((n - 1)) "$d/l.der" > "$d/bad.der"; printf '\001' >> "$d/bad.der"
vfail signature "error 7 at 0 depth lookup: certificate signature failure" -CAfile "$d/rr.pem" "$d/bad.der"
# one good and one bad: both said, and the run fails
k verify -CAfile "$d/rr.pem" $tc/leafr.pem $tc/expired.pem > "$o" 2> /dev/null; r=$?
[ $r -eq 2 ] && grep -q "leafr.pem: OK" "$o" || fail "kore openssl verify two files (exit $r)"
clean "verify a missing CAfile" 2 verify -CAfile "$d/none.pem" $tc/leafr.pem
clean "verify a missing file" 2 verify -CAfile "$d/rr.pem" "$d/none.pem"

# --- dgst, against the coreutils digests ---
printf 'hello\n' > "$d/h"
hx() { "$1" < "$d/h" | cut -d' ' -f1; }
is dgst "$(k dgst "$d/h")" "SHA256($d/h)= $(hx sha256sum)"
is "dgst -sha256" "$(k dgst -sha256 "$d/h")" "SHA2-256($d/h)= $(hx sha256sum)"
is "dgst -md5" "$(k dgst -md5 "$d/h")" "MD5($d/h)= $(hx md5sum)"
is "dgst -sha1" "$(k dgst -sha1 "$d/h")" "SHA1($d/h)= $(hx sha1sum)"
is "dgst -sha224" "$(k dgst -sha224 "$d/h")" "SHA2-224($d/h)= $(hx sha224sum)"
is "dgst -sha384" "$(k dgst -sha384 "$d/h")" "SHA2-384($d/h)= $(hx sha384sum)"
is "dgst -sha512" "$(k dgst -sha512 "$d/h")" "SHA2-512($d/h)= $(hx sha512sum)"
is "dgst -r" "$(k dgst -r "$d/h")" "$(hx sha256sum) *$d/h"
is "dgst stdin" "$(k dgst < "$d/h")" "SHA256(stdin)= $(hx sha256sum)"
clean "dgst a missing file" 1 dgst "$d/none"
clean "dgst an unknown flag" 1 dgst -bogus "$d/h"

# --- rand ---
x=$(k rand -hex 16); y=$(k rand -hex 16)
[ ${#x} -eq 32 ] || fail "kore openssl rand -hex 16: ${#x} digits"
case $x in *[!0-9a-f]*) fail "kore openssl rand -hex: not hex: $x";; esac
[ "$x" != "$y" ] || fail "kore openssl rand: the same bytes twice"
[ "$(k rand 1000 | wc -c)" -eq 1000 ] || fail "kore openssl rand 1000"
[ "$(k rand -base64 48 | base64 -d | wc -c)" -eq 48 ] || fail "kore openssl rand -base64 48"
clean "rand no count" 1 rand
clean "rand a bad count" 1 rand -hex abc
clean "rand a zero count" 1 rand -hex 0
[ -s "$o" ] && fail "kore openssl rand: bytes written on a refusal"

# --- base64 ---
head -c 5000 /dev/urandom > "$d/b"
k base64 -in "$d/b" > "$d/b.64"
base64 -w 64 "$d/b" > "$o"; cmp -s "$o" "$d/b.64" || fail "kore openssl base64: not 64 columns of base64"
k base64 -d -in "$d/b.64" > "$o"; cmp -s "$o" "$d/b" || fail "kore openssl base64 -d: the round trip"
k base64 -A -in "$d/b" > "$o"
[ "$(wc -l < "$o")" -eq 0 ] && [ "$(base64 -d < "$o" | wc -c)" -eq 5000 ] || fail "kore openssl base64 -A"
printf '!!!!' > "$d/junk.64"
clean "base64 -d junk" 1 base64 -d -in "$d/junk.64"

# --- bad input: truncated and bitten certificates answer an error line, never a scare ---
: > "$d/empty"
clean "x509 an empty file" 1 x509 -in "$d/empty"
clean "x509 text" 1 x509 -in "$d/h"
head -c 600 $tc/leafr.pem > "$d/short.pem"
clean "x509 a torn pem" 1 x509 -in "$d/short.pem"
clean "verify a torn pem" 2 verify -CAfile "$d/rr.pem" "$d/short.pem"
for c in 1 2 3 4 5 9 30 100 300 500 800; do
  head -c $c "$d/l.der" > "$d/t.der"
  k x509 -inform DER -in "$d/t.der" -noout -text > "$o" 2> "$d/err"; r=$?
  [ $r -le 1 ] && ! grep -q '^;;' "$d/err" || fail "kore openssl x509 on $c bytes of der (exit $r)"
done
n=$(wc -c < "$d/l.der")
for at in 0 1 3 4 6 8 15 40 70 150 250 400 600 700 800; do
  head -c $at "$d/l.der" > "$d/t.der"; printf '\377' >> "$d/t.der"; tail -c +$((at + 2)) "$d/l.der" >> "$d/t.der"
  k x509 -inform DER -in "$d/t.der" -noout -text -subject -fingerprint > "$o" 2> "$d/err"; r=$?
  [ $r -le 1 ] && ! grep -q '^;;' "$d/err" || fail "kore openssl x509 on a der bitten at $at (exit $r)"
  k verify -CAfile "$d/rr.pem" "$d/t.der" > "$o" 2> "$d/err"; r=$?
  [ $r -le 2 ] && ! grep -q '^;;' "$d/err" || fail "kore openssl verify on a der bitten at $at (exit $r)"
done

# --- making: genpkey, req, x509 -req; each chain checked by our verify (and openssl's below) ---
k genpkey -algorithm ed25519 -out "$d/ca.key" || fail "kore openssl genpkey ed25519"
grep -q '^-----BEGIN PRIVATE KEY-----$' "$d/ca.key" || fail "kore openssl genpkey: not pkcs#8"
k genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out "$d/in.key" || fail "kore openssl genpkey p-256"
k req -new -x509 -key "$d/ca.key" -subj "/CN=kore root/O=love" -days 3650 \
  -addext "keyUsage=critical,keyCertSign,cRLSign" \
  -addext "nameConstraints=critical,permitted;DNS:sb.test,permitted;IP:10.0.0.0/255.0.0.0,excluded;DNS:bad.sb.test" \
  -out "$d/ca.pem" || fail "kore openssl req -x509"
is "req -x509 subject" "$(k x509 -in "$d/ca.pem" -noout -subject -issuer | tr '\n' '|')" "subject=CN=kore root, O=love|issuer=CN=kore root, O=love|"
k req -new -key "$d/in.key" -subj "/CN=kore issuer" -out "$d/in.csr" || fail "kore openssl req -new"
grep -q '^-----BEGIN CERTIFICATE REQUEST-----$' "$d/in.csr" || fail "kore openssl req -new: not a request"
printf 'basicConstraints = critical, CA:TRUE, pathlen:0\nkeyUsage = critical, keyCertSign\n[ leaf ]\nbasicConstraints=critical,CA:FALSE\nextendedKeyUsage=serverAuth\n' > "$d/ext.cnf"
k x509 -req -in "$d/in.csr" -CA "$d/ca.pem" -CAkey "$d/ca.key" -days 365 -extfile "$d/ext.cnf" -out "$d/in.pem" \
  || fail "kore openssl x509 -req (issuer)"
k req -new -newkey ec -pkeyopt ec_paramgen_curve:P-256 -keyout "$d/lf.key" -subj "/CN=kore leaf" \
  -addext "subjectAltName=DNS:a.sb.test,IP:10.1.2.3" -out "$d/lf.csr" || fail "kore openssl req -newkey"
k x509 -req -in "$d/lf.csr" -CA "$d/in.pem" -CAkey "$d/in.key" -set_serial 0x1234 -extfile "$d/ext.cnf" -extensions leaf \
  -copy_extensions copy -out "$d/lf.pem" || fail "kore openssl x509 -req (leaf)"
is "x509 -req serial" "$(k x509 -in "$d/lf.pem" -noout -serial)" "serial=1234"
is "x509 -req extensions" "$(k x509 -in "$d/lf.pem" -noout -ext subjectAltName,basicConstraints,extendedKeyUsage | tr '\n' '|')" \
  "X509v3 Subject Alternative Name: |    DNS:a.sb.test, IP Address:10.1.2.3|X509v3 Basic Constraints: critical|    CA:FALSE|X509v3 Extended Key Usage: |    TLS Web Server Authentication|"
is "verify our chain" "$(k verify -CAfile "$d/ca.pem" -untrusted "$d/in.pem" "$d/lf.pem")" "$d/lf.pem: OK"
k req -new -newkey ed25519 -keyout "$d/bad.key" -subj "/CN=bad" -addext "subjectAltName=DNS:x.bad.sb.test" -out "$d/bad.csr" \
  && k x509 -req -in "$d/bad.csr" -CA "$d/in.pem" -CAkey "$d/in.key" -copy_extensions copy -out "$d/bad.pem" \
  || fail "kore openssl: the excluded leaf"
vfail "excluded name" "error 48 at [0-9] depth lookup: excluded subtree violation" -CAfile "$d/ca.pem" -untrusted "$d/in.pem" "$d/bad.pem"
k x509 -req -in "$d/lf.csr" -signkey "$d/lf.key" -days 2 -out "$d/self.pem" || fail "kore openssl x509 -req -signkey"
is "verify self-signed" "$(k verify -CAfile "$d/self.pem" "$d/self.pem")" "$d/self.pem: OK"
clean "x509 -req a key that is not the CA's" 1 x509 -req -in "$d/lf.csr" -CA "$d/in.pem" -CAkey "$d/ca.key"
clean "x509 -req no signer" 1 x509 -req -in "$d/lf.csr"
clean "req a bad extension" 1 req -new -x509 -key "$d/ca.key" -subj /CN=x -addext "keyUsage=bogus"
clean "req no subject" 1 req -new -key "$d/ca.key"
clean "genpkey rsa" 1 genpkey -algorithm RSA
clean "x509 -req a torn request" 1 x509 -req -in "$d/short.pem" -signkey "$d/lf.key"

# --- whole outputs against the host's openssl, where it speaks the same face ---
if command -v openssl > /dev/null 2>&1 && [ "$(openssl x509 -in $tc/leafr.pem -noout -subject 2>/dev/null)" = "subject=CN=leafr" ]; then
  for c in leafr leafe leaf512 leafw roote rootr rootw inter0 crit client nosan; do
    both "openssl x509 -text $c" openssl x509 -in $tc/$c.pem -noout -text
    both "openssl x509 fields $c" openssl x509 -in $tc/$c.pem -noout -subject -issuer -dates -serial -fingerprint -pubkey
  done
  both "openssl x509 -ext" openssl x509 -in $tc/leafr.pem -noout -ext basicConstraints,subjectAltName,authorityKeyIdentifier
  for a in -md5 -sha1 -sha256 -sha512; do both "openssl dgst $a" openssl dgst $a "$d/h" "$d/b"; done
  both "openssl base64" openssl base64 -in "$d/b"
  for c in expired notyet crit undernoca; do
    openssl verify -CAfile "$d/rr.pem" $tc/$c.pem > "$g" 2>&1; rg=$?
    k verify -CAfile "$d/rr.pem" $tc/$c.pem > "$o" 2>&1; ro=$?
    same "openssl verify $c"; [ $rg -eq $ro ] || fail "kore openssl verify $c exit ($ro vs $rg)"
  done
  # what kore made, read and verified by the host's openssl, and its text the same
  for c in ca in lf self bad; do both "openssl x509 -text made $c" openssl x509 -in "$d/$c.pem" -noout -text; done
  openssl verify -CAfile "$d/ca.pem" -untrusted "$d/in.pem" "$d/lf.pem" > "$o" 2>&1 || fail "openssl verify of kore's chain: $(cat "$o")"
  openssl verify -CAfile "$d/ca.pem" -untrusted "$d/in.pem" "$d/bad.pem" > "$o" 2>&1 && fail "openssl verify took kore's excluded leaf"
  grep -q "excluded subtree violation" "$o" || fail "openssl verify of kore's excluded leaf: $(cat "$o")"
  openssl pkey -in "$d/in.key" -noout 2>/dev/null || fail "openssl reads kore's p-256 key"
  openssl req -in "$d/lf.csr" -noout -verify > /dev/null 2>&1 || fail "openssl verifies kore's request"
  echo "kore: openssl (x509 -text identical to the host openssl on the fixtures and on what genpkey, req and x509 -req made, verify, dgst, rand, base64, bad input) ok"
else
  echo "kore: openssl (x509, genpkey, req, x509 -req, verify, dgst, rand, base64, bad input) ok -- no openssl 3 here to compare whole outputs"
fi
