# test/host/tlschain/gen.sh -- lays the chain fixtures test/host/tls.l reads: sh gen.sh DIR
# roots, intermediates and leaves, rsa and ec, and one certificate for each rule broken
set -e
D=$1
cd "$D"
NB=20250101000000Z; NA=20350101000000Z
ext() { printf '%s\n' "$@" > "$D/ext.cnf"; }
key() { case $1 in rsa) openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out $2.key 2>/dev/null;;
  p256) openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out $2.key;;
  p384) openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-384 -out $2.key;;
  p521) openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-521 -out $2.key;; esac; }
root() { key $2 $1; ext "basicConstraints=critical,CA:TRUE" "keyUsage=critical,keyCertSign,cRLSign" "subjectKeyIdentifier=hash";
  openssl req -new -key $1.key -subj "/CN=$1" -out $1.csr;
  openssl x509 -req -in $1.csr -signkey $1.key -$3 -not_before $NB -not_after $NA -extfile ext.cnf -out $1.pem 2>/dev/null; }
cert() { n=$1 k=$2 is=$3 md=$4 nb=$5 na=$6; shift 6; key $k $n; ext "$@";
  openssl req -new -key $n.key -subj "/CN=$n" -out $n.csr;
  openssl x509 -req -in $n.csr -CA $is.pem -CAkey $is.key -set_serial 0x$(openssl rand -hex 8) -$md -not_before $nb -not_after $na -extfile ext.cnf -out $n.pem 2>/dev/null; }
CA="basicConstraints=critical,CA:TRUE"; KU="keyUsage=critical,keyCertSign,cRLSign"
LEAF="basicConstraints=critical,CA:FALSE"; LKU="keyUsage=critical,digitalSignature,keyEncipherment"; SA="extendedKeyUsage=serverAuth"
root rootr rsa sha256
cert interr rsa rootr sha384 $NB $NA "$CA" "$KU"
cert leafr rsa interr sha256 $NB $NA "$LEAF" "$LKU" "$SA" "subjectAltName=DNS:good.test,DNS:*.wild.test,IP:127.0.0.1"
root roote p384 sha384
cert intere p256 roote sha384 $NB $NA "$CA" "$KU"
cert leafe p256 intere sha256 $NB $NA "$LEAF" "keyUsage=critical,digitalSignature" "$SA" "subjectAltName=DNS:good.test"
cert leaf512 rsa interr sha512 $NB $NA "$LEAF" "$SA" "subjectAltName=DNS:good.test"
cert expired rsa interr sha256 20200101000000Z 20210101000000Z "$LEAF" "subjectAltName=DNS:good.test"
cert notyet rsa interr sha256 20400101000000Z 20410101000000Z "$LEAF" "subjectAltName=DNS:good.test"
cert partial rsa interr sha256 $NB $NA "$LEAF" "subjectAltName=DNS:f*.wild.test,DNS:*.test"
cert noca rsa interr sha256 $NB $NA "$LEAF" "subjectAltName=DNS:noca.test"
cert undernoca rsa noca sha256 $NB $NA "$LEAF" "subjectAltName=DNS:good.test"
cert inter0 rsa rootr sha256 $NB $NA "basicConstraints=critical,CA:TRUE,pathlen:0" "$KU"
cert inter1 rsa inter0 sha256 $NB $NA "$CA" "$KU"
cert deep rsa inter1 sha256 $NB $NA "$LEAF" "subjectAltName=DNS:good.test"
cert crit rsa interr sha256 $NB $NA "$LEAF" "subjectAltName=DNS:good.test" "1.2.3.4=critical,ASN1:NULL"
cert client rsa interr sha256 $NB $NA "$LEAF" "extendedKeyUsage=clientAuth" "subjectAltName=DNS:good.test"
cert nosign rsa rootr sha256 $NB $NA "$CA" "keyUsage=critical,digitalSignature"
cert undernosign rsa nosign sha256 $NB $NA "$LEAF" "subjectAltName=DNS:good.test"
cert nosan rsa interr sha256 $NB $NA "$LEAF"
root rootw p521 sha512
cert leafw p384 rootw sha512 $NB $NA "$LEAF" "$SA" "subjectAltName=DNS:good.test"
