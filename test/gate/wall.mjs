// test/gate/wall.mjs -- what a page lets a link and a guest ask, asked without a page.
// cpu.mjs's pageurl is the gate a link's module and image pass through: this origin only.
// its neturl is the guest's fetch door: any http(s) url, as the page's own script could
// ask -- `love doom` in a page lays its tree off github, so that door stays open.
// usage: node test/gate/wall.mjs
import { pageurl, neturl } from '../../inle/wasm/cpu.mjs';

let bad = 0;
const law = (ok, m) => { if (ok) console.log('  ' + m); else bad++, console.log('FAIL wall: ' + m); };
const here = 'https://love.example/inle/wasm/cpu.mjs';

law(pageurl('/VERSION', here) === 'https://love.example/VERSION', 'a link\'s path on this origin is taken');
law(pageurl('../../web/wasm/love.wasm', here) === 'https://love.example/web/wasm/love.wasm', 'a relative one too');
law(pageurl('https://love.example/x', here) === 'https://love.example/x', 'and this origin spelled whole');
law(pageurl('https://evil.example/x.wasm', here) === null, 'a module off another origin is refused');
law(pageurl('//evil.example/x', here) === null, 'a scheme-relative one too');
law(pageurl('http://love.example/x', here) === null, 'another scheme is another origin');
law(pageurl('https://love.example:8443/x', here) === null, 'and another port');
law(pageurl('data:text/plain,hi', here) === null, 'a data: url has no origin to share');
law(pageurl('javascript:alert(1)', here) === null, 'nor a javascript: one');

law(neturl('/VERSION', here) === 'https://love.example/VERSION', 'the guest fetches this origin');
for (const u of ['https://api.github.com/repos/ozkl/doomgeneric/git/trees/master?recursive=1',
                 'https://raw.githubusercontent.com/ozkl/doomgeneric/master/doomgeneric/doomgeneric.c',
                 'https://raw.githubusercontent.com/Daivuk/PureDOOM/master/doom1.wad'])
  law(neturl(u, here) === u, 'and another origin: ' + new URL(u).host + ' (love doom lays off it)');
law(neturl('http://plain.example/x', here) === 'http://plain.example/x', 'plain http too');
law(neturl('data:text/plain,hi', here) === null, 'but not a data: url');
law(neturl('javascript:alert(1)', here) === null, 'nor a javascript: one');
law(neturl('blob:https://love.example/0', here) === null, 'nor the page\'s own blobs');

if (bad) { console.log(`FAIL wall: ${bad} law(s)`); process.exit(1); }
console.log('  wall: ok -- a link\'s module off this origin only, the guest\'s fetch any http(s) url');
