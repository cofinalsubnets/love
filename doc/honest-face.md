# Note: the honest face is the missing face of the answer

A reading of the condition system (user's framing, 2026-06-19). `help` is the global
function that turns a raise into an **answer** (`(help s a b)` → a value, delivered per the
status bits). So when help is missing, the *answer* is missing — and what shows instead is
the **honest face** `;; a b` (host/main.c, the scare exit-face).

**Three layers when a condition rises:**
1. **help present** → an **answer** (a value).
2. **welp** (the floor handler — help that has given up) → the **zero point** for a bare
   scare: absence *caught* and handed back as a value (the fromempty, `()`).
3. **nothing at all** → the **honest face** `;; a b`, terminal — not a value, just shown.

So the honest face sits **below even the zero point**. The zero point is the face of a
missing **nom** — absence in the *value* space, which the floor still resolves to a value.
The honest face is the face of a missing **answer** — absence in the *condition* space, with
no floor to convert it, so it never becomes a value: it is just *shown*, and stops.

That is why it is **honest**: an answer would *resolve* the condition; the honest face refuses
to fake one — it shows the raw `a b`, unresolved, and admits there is nothing behind it. The
zero point is absence pretending (gracefully) to be a value; the honest face is absence not
even pretending. **The honest face is the missing answer made visible — the zero point's
reflection across the help boundary, one floor further down.**

(Corollary, the `;; 0 11` UX nit: the *form* is right — `;; a b` is honest — but the
double-prelude load raised a bare *data* scare, handing the face two mute numbers instead of
a word. The form is honest; the payload is silent. A self-load guard could raise a legible
condition ("prelude already loaded") so the honest face has something to say.)

Relates: [[faces]] (the hourglass / one core), the zero point + `welp` in test/spec.l's control section.
