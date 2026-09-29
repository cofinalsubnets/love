// test/gate/wall.mjs -- what a page lets a link and a guest ask, asked without a page.
// cpu.mjs's pageurl is the guest's fetch door and the gate a link's module and image pass
// through: this origin only. machine.js's linkboot is what a link's boot line may be
// without the reader agreeing: one program's bare name, or the page's own line.
// usage: node test/gate/wall.mjs
import { pageurl } from '../../inle/wasm/cpu.mjs';
import { linkboot } from '../../inle/wasm/machine.js';

let bad = 0;
const law = (ok, m) => { if (ok) console.log('  ' + m); else bad++, console.log('FAIL wall: ' + m); };
const here = 'https://love.example/inle/wasm/cpu.mjs';

law(pageurl('/VERSION', here) === 'https://love.example/VERSION', 'a path on this origin is fetched');
law(pageurl('../../web/wasm/love.wasm', here) === 'https://love.example/web/wasm/love.wasm', 'a relative one too');
law(pageurl('https://love.example/x', here) === 'https://love.example/x', 'and this origin spelled whole');
law(pageurl('https://evil.example/x?leak=1', here) === null, 'another origin is refused');
law(pageurl('//evil.example/x', here) === null, 'a scheme-relative one too');
law(pageurl('http://love.example/x', here) === null, 'another scheme is another origin');
law(pageurl('https://love.example:8443/x', here) === null, 'and another port');
law(pageurl('data:text/plain,hi', here) === null, 'a data: url has no origin to share');
law(pageurl('javascript:alert(1)', here) === null, 'nor a javascript: one');

const own = 'sh --login';
law(linkboot(null, own).join() === [own, false].join(), 'no link line: the page boots its own');
law(linkboot('tower', own).join() === ['tower', false].join(), 'a bare program name boots as asked');
law(linkboot(own, own).join() === [own, false].join(), 'the page\'s own line boots as asked');
law(linkboot('sh -c "wget x; echo y > /proc/lift"', own)[1] === true, 'a shell line waits for the reader');
law(linkboot('bake /x', own)[1] === true, 'so does any line with arguments');
law(linkboot('Tower', own)[1] === true && linkboot('a/b', own)[1] === true && linkboot('x'.repeat(40), own)[1] === true,
    'and a name that is not a bare lower-case word');

if (bad) { console.log(`FAIL wall: ${bad} law(s)`); process.exit(1); }
console.log('  wall: ok -- this origin only, and a link runs one bare name unasked');
