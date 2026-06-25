#!/bin/sh
# mkhtml.sh <lang-roster> < raw-result-lines > bench.html
#
# Turn the raw "<name> <lang> <reps> <ms> <chk>" lines (the same stream `make
# raw` prints) into a self-contained benchmarks page: one table of per-iteration
# milliseconds (benches down the side, languages across), and a button that
# transposes benches<->languages (handy on a narrow portrait screen).
# <lang-roster> is the column SET (e.g. $(ALL_LANGS)). The page (in JS, at render)
# orders EVERY column by NET time ascending -- Σ of a language's per-bench ms/it
# EXCLUDING bell and sat (single-implementation benches: luajit/rust lack bell, sat
# is ai-only, so counting either hands the skippers a free 0 and skews the net). ai
# takes its HONEST position (still tinted gold); a language with no rows sorts last.
# The page embeds its data, so it opens straight off disk -- no server.
roster="$1"

cat <<'HEAD'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>ai benchmarks</title>
<style>
  /* tokyo-night, matching the site (style.css): periwinkle on polar-night blue,
     the self-hosted DOS/V bitmap font, green = a kept (fastest) answer. */
  @font-face {
    font-family: "Web437 DOS/V TWN16";
    src: url("../fonts/Web437_DOS-V_TWN16.woff2") format("woff2"),
         url("../fonts/Web437_DOS-V_TWN16.woff") format("woff");
    font-display: swap;
  }
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  body { background: #04060e; color: #a9b1d6;
         font-family: "Web437 DOS/V TWN16", "Px437 IBM VGA8", "DejaVu Sans Mono",
                      ui-monospace, Menlo, Consolas, monospace;
         font-size: 16px; line-height: 1.5; font-variant-ligatures: none;
         -webkit-font-smoothing: none; font-smooth: never;
         margin: 0; padding: 1.6em 1.2em 4em; }
  h1 { font-size: 1.5em; font-weight: normal; letter-spacing: .04em; color: #c0caf5; margin: 0 0 .3em; }
  .note { color: #565f89; font-size: .9em; max-width: 64ch; margin: .3em 0 1.2em; }
  .bar { margin: 0 0 1em; display: flex; gap: .75rem; align-items: baseline; }
  button { font: inherit; padding: .35em .85em; cursor: pointer; color: #a9b1d6;
           border: 1px solid #3b4261; border-radius: 4px; background: #1f2335; }
  button:hover { background: #292e42; }
  #mode { color: #565f89; font-size: .9em; }
  .wrap { overflow: auto; max-height: 86vh; border: 1px solid #292e42; border-radius: 6px; }
  table { border-collapse: collapse; font-variant-numeric: tabular-nums; }
  th, td { padding: .28em .7em; text-align: right; border: 1px solid #292e42; white-space: nowrap; }
  thead th { position: sticky; top: 0; background: #1f2335; color: #737aa2; font-weight: normal;
             box-shadow: inset 0 -1px #3b4261; }
  tbody th { text-align: left; position: sticky; left: 0; background: #1f2335; color: #9aa5ce;
             box-shadow: inset -1px 0 #3b4261; font-weight: normal; }
  td.miss { color: #3b4261; }
  td.fast { color: #9ece6a; font-weight: bold; }              /* a kept answer: the green */
  .ai { background: rgba(169,177,214,.09) !important; }        /* the ai axis: translucent periwinkle */
  th.ai { background: rgba(169,177,214,.20) !important; color: #c0caf5 !important; }
  td.okc, .okrow td { color: #9ece6a; }
  td.bad, .okrow td.bad { color: #f7768e; }
  .netrow th, .netrow td { border-top: 2px solid #545c7e; color: #e0af68; }   /* selective net: Σ ms/it excl bell+sat -- the column-ordering key, made visible */
  th.net, td.net { border-left: 2px solid #545c7e; color: #e0af68; }          /* ... as a column in the transposed view */
  td.to { color: #f7768e; }                                                   /* a solver that exceeded the timeout */
  h2 { font-weight: normal; color: #c0caf5; margin: 1.6em 0 .4em; }
</style>
</head>
<body>
<h1>ai benchmarks &mdash; milliseconds per iteration</h1>
<p class="note">Lower is better. Each language self-times its inner loop (reps
auto-scaled past a 200&nbsp;ms floor, so startup is excluded). The fastest cell
per bench is <b style="color:#9ece6a">green</b>; the <span class="ai"
style="padding:0 .3em">ai</span> axis is tinted; a dot means no implementation
(or an unavailable toolchain). <b>ok</b> = every language's checksum agrees.</p>
<div class="bar">
  <button id="btn" type="button">transpose</button>
  <span id="mode"></span>
</div>
<div class="wrap"><div id="t"></div></div>
HEAD

# -- the SECOND table: the SAT-solver shootout (arg 2 = a satrace.sh result file,
# "<instance> <solver> <ms> <verdict>" lines). Rendered STATIC at generation time
# (no transpose needed), solvers ordered by net ms ascending -- ai its honest
# position, a timeout ranking it last. Skipped if no file. --
if [ -n "$2" ] && [ -s "$2" ]; then
cat <<'SAT'
<h2>SAT solvers &mdash; pigeonhole UNSAT, milliseconds to solve</h2>
<p class="note">A separate field: ai&rsquo;s own CDCL solver (<code>sat/sat.l</code>)
against reference C solvers on PHP(<i>n</i>) &mdash; (<i>n</i>+1) pigeons into <i>n</i>
holes, UNSAT and resolution-hard, so CDCL is <b>exponential</b> here. ai is timed by its
own solve clock (interpreter warmup excluded); the C solvers by process wall-clock (their
startup is ~ms). <code>timeout</code> = exceeded the cutoff. This is where a tuned C
solver pulls away from an interpreted one &mdash; the honest other side of the language
table above.</p>
<div class="wrap">
SAT
awk '
  function fmt(x){ return x<1?sprintf("%.4f",x):x<100?sprintf("%.3f",x):sprintf("%.1f",x) }
  { inst=$1; solv=$2; ms=$3
    if(!(inst in si)){iord[++ni]=inst; si[inst]=1}
    if(!(solv in ss)){sord[++ns]=solv; ss[solv]=1}
    val[inst,solv]=ms }
  END{
    for(j=1;j<=ns;j++){s=sord[j]; net=0; to=0; for(i=1;i<=ni;i++){v=val[iord[i],s]; if(v=="timeout"){to=1; net+=1e9}else net+=v+0} netv[s]=net; anyto[s]=to; ord[j]=s}
    for(a=1;a<=ns;a++)for(b=a+1;b<=ns;b++)if(netv[ord[b]]<netv[ord[a]]){t=ord[a];ord[a]=ord[b];ord[b]=t}
    for(i=1;i<=ni;i++){m=1e18; for(j=1;j<=ns;j++){v=val[iord[i],ord[j]]; if(v!="timeout"&&v!=""&&v+0<m)m=v+0} minr[iord[i]]=m}
    printf "<table><thead><tr><th>instance</th>"
    for(j=1;j<=ns;j++){s=ord[j]; printf "<th%s>%s</th>", (s=="ai"?" class=\047ai\047":""), s}
    print "</tr></thead><tbody>"
    for(i=1;i<=ni;i++){inst=iord[i]; printf "<tr><th>%s</th>", inst
      for(j=1;j<=ns;j++){s=ord[j]; v=val[inst,s]; c=(s=="ai"?"ai ":"")
        if(v==""){printf "<td class=\047%smiss\047>·</td>",c}
        else if(v=="timeout"){printf "<td class=\047%sto\047>timeout</td>",c}
        else{f=(v+0==minr[inst]?"fast ":""); printf "<td class=\047%s%s\047>%s</td>",c,f,fmt(v+0)}}
      print "</tr>"}
    printf "<tr class=\047netrow\047><th>net</th>"
    for(j=1;j<=ns;j++){s=ord[j]; printf "<td class=\047net%s\047>%s</td>", (s=="ai"?" ai":""), (anyto[s]?"dnf":fmt(netv[s]))}
    print "</tr></tbody></table>"
  }' "$2"
echo "</div>"
fi

echo "<script>"

awk -v langs="$roster" '
  BEGIN { nl = split(langs, L, " ") }
  NF==5 && $3+0>0 {
    if (!($1 in seen)) { order[++n] = $1; seen[$1] = 1 }
    per[$1 SUBSEP $2] = $4/$3
    csum[$1 SUBSEP $2] = $5
    have[$1 SUBSEP $2] = 1
  }
  END {
    printf "const LANGS=["
    for (j=1;j<=nl;j++) printf "%s\"%s\"", (j>1?",":""), L[j]
    print "];"
    printf "const BENCHES=["
    for (i=1;i<=n;i++) printf "%s\"%s\"", (i>1?",":""), order[i]
    print "];"
    print "const PER={},OK={};"
    for (i=1;i<=n;i++) {
      b = order[i]; printf "PER[\"%s\"]={", b; first=1; base=""; ok="true"
      for (j=1;j<=nl;j++) {
        lg = L[j]
        if (have[b SUBSEP lg]) {
          printf "%s\"%s\":%.4f", (first?"":","), lg, per[b SUBSEP lg]; first=0
          if (base=="") base = csum[b SUBSEP lg]
          else if (csum[b SUBSEP lg] != base) ok = "false"
        }
      }
      print "};"
      printf "OK[\"%s\"]=%s;\n", b, ok
    }
  }
'

cat <<'TAIL'
const fmt = x => x == null ? "·"
  : x < 1 ? x.toFixed(4) : x < 100 ? x.toFixed(3) : x.toFixed(1);

// column order: every language (ai included -- its HONEST position) by NET time
// ascending -- Σ of a language's per-bench ms/it EXCLUDING bell and sat. Both are
// single-implementation benches (luajit/rust lack bell; sat is ai-only), so
// counting either gives the languages that skip it a free 0 and skews the net.
// ai is still TINTED (the gold column) wherever it lands. No-data langs sort last.
const NET = l => BENCHES.reduce((s, b) => s +
  ((b === "bell" || b === "sat") ? 0 : (PER[b] && PER[b][l] != null ? PER[b][l] : 0)), 0);
const HAS = l => BENCHES.some(b => PER[b] && PER[b][l] != null);
const LANGORD = LANGS.slice().sort((a, b) =>
  (HAS(a) ? NET(a) : Infinity) - (HAS(b) ? NET(b) : Infinity));

// default arrangement: benches down the side, languages across; the button
// flips to languages-down-the-side (handy on a narrow portrait screen).
let transposed = false;

function build() {
  const rows = transposed ? LANGORD : BENCHES;
  const cols = transposed ? BENCHES : LANGORD;
  const minB = {};
  for (const b of BENCHES) {
    let m = Infinity;
    for (const l of LANGORD) { const v = PER[b] && PER[b][l]; if (v != null && v < m) m = v; }
    minB[b] = m;
  }
  const td = (b, l) => {
    const v = (PER[b] && PER[b][l] != null) ? PER[b][l] : null;
    const c = [];
    if (l === "ai") c.push("ai");
    if (v == null) c.push("miss"); else if (v === minB[b]) c.push("fast");
    return "<td" + (c.length ? " class='" + c.join(" ") + "'" : "") + ">" + fmt(v) + "</td>";
  };
  const netc = (l) => "<td class='net" + (l === "ai" ? " ai" : "") + "'>" + (HAS(l) ? fmt(NET(l)) : "·") + "</td>";
  let h = "<table><thead><tr><th>" + (transposed ? "language" : "bench") + "</th>";
  for (const c of cols) h += "<th" + (c === "ai" ? " class='ai'" : "") + ">" + c + "</th>";
  h += !transposed ? "<th>ok</th>" : "<th class='net'>selective net</th>";   // ok column (benches down) / net column (langs down)
  h += "</tr></thead><tbody>";
  for (const r of rows) {
    h += "<tr><th" + (r === "ai" ? " class='ai'" : "") + ">" + r + "</th>";
    for (const c of cols) h += td(transposed ? c : r, transposed ? r : c);
    if (!transposed) h += "<td class='" + (OK[r] ? "okc" : "bad") + "'>" + (OK[r] ? "✓" : "✗") + "</td>";
    else h += netc(r);                                                       // per-language selective net (transposed)
    h += "</tr>";
  }
  if (transposed) {
    h += "<tr class='okrow'><th>ok</th>";                                    // the ok marks as a bottom row (langs down)
    for (const c of cols) h += "<td class='" + (OK[c] ? "" : "bad") + "'>" + (OK[c] ? "✓" : "✗") + "</td>";
    h += "<td class='net'></td></tr>";
  } else {
    h += "<tr class='netrow'><th>selective net</th>";                        // the column-ordering key, as a bottom row (benches × languages)
    for (const c of cols) h += netc(c);
    h += "<td class='net'></td></tr>";
  }
  h += "</tbody></table>";
  document.getElementById("t").innerHTML = h;
  document.getElementById("mode").textContent =
    transposed ? "languages × benches" : "benches × languages";
}
document.getElementById("btn").onclick = () => { transposed = !transposed; build(); };
build();
</script>
</body>
</html>
TAIL
