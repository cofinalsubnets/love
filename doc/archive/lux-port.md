# Porting xmonad to love — the plan

Goal: an **love window manager with the same features** as `/home/gwen/.xmonad/xmonad.hs` —
not the Haskell config kept alive, but a fresh, idiomatic **love config** that does everything
yours does. The DSL borrows xmonad's *vocabulary* (layouts, messages, manageHook rules,
a keymap) because those names are good and you know them — but `crew/lux/config.l` is genuine love,
read and edited as love, not a transliteration of Haskell. **Single monitor** throughout (no
Xinerama) — the model is simpler for it. The X mechanics already work
(the `doc/proto/{x11,lux,xsend}.l` spike ladder, rungs 1–5): raw X11 wire protocol, the
substructure redirect, MapRequest/DestroyNotify, focus + `SetInputFocus`, Tall tiling,
and grabbed-key dispatch (XTEST-verified). What remains is surface area: the float half
of `StackSet`, a library of layout combinators, `GetProperty`/atoms + EWMH, and the
config DSL itself.

This doc is the map. It is anchored to the actual config — every layout modifier,
manageHook rule, and keybinding in `xmonad.hs` is accounted for below.

---

## 1. Architecture: the `crew/lux/` app

The spike lives in one giant body-having `:`, which shares ONE flat scope with every nif
and all of prel. That is a collision minefield — rung 6 died because a sheaf helper named
`put` shadowed the `put` nif the wire codec depends on. A whole window manager cannot live
in one `:`. So the port graduates into a proper **`crew/lux/` app** beside ain/bao/cook, each
file its own scope, helpers local, only entry points leaking:

```
crew/lux/
  core.l      the pure StackSet: zipper + sheaf + FLOATING map. No X, no sockets.
              (test/lux.l's core, extended with floats. Corpus-testable, all targets.)
  wire.l      the X11 codec: connect, setup, request writers, event decoder, atoms.
              (host-only: needs connectu. The doc/proto/x11.l lineage, modularized.)
  layout.l    layouts as CLOSURES + messages as SYMBOLS: Tall/ResizableTall/Dwindle/
              Full + the modifier stack (toggle/mirror/smartBorders/avoidStruts/nav).
  manage.l    the manageHook DSL: property predicates -> placement actions.
  keys.l      the keymap DSL + xmonad's DEFAULT keymap (the config unions onto it).
  ewmh.l      the _NET_* property protocol + the support window.
  lux.l        the driver: wire the config's hooks into the event loop.
  config.l    THE PORTED xmonad.hs, in the DSL. This is what the user edits.
  host/lux.c   the connectu nif (already landed).
```

`core.l` needs no nifs, so it rides the corpus on every target (host + love0 + kernel + wasm)
with xmonad's QuickCheck laws as asserts — the invariants stay machine-checked. The rest is
host-only (it speaks sockets), smoke-tested the `boot/lux.l` way (in `test_hostnif`) plus the
Xephyr integration runs.

---

## 2. The DSL: how the config reads

The target — `crew/lux/config.l`, a love config with your config's features. Same vocabulary, love
shape: `mod4` is `sup`, layouts are constructors returning closures, `|||` is a choice
combinator, messages are symbols. Idioms that were Haskell (the inline `fib` for Dwindle's
ratio, the `M.union . M.fromList` comprehension) are just written in love — a constant or a
`map`, whichever reads best — not preserved as Haskell:

```love
(xmonad (. ewmh-fullscreen ewmh docks
   (config
     border-width       3
     normal-border      "Dark Slate Blue"
     focused-border     "Light Cyan"
     mod-mask           sup
     workspaces         (map show (jot-from 1 9))
     startup-hook       (>> (spawn "setxkbmap -option ctrl:nocaps")
                            (set-lux-name "LG3D (XMonad)")
                            (set-cursor 'left-ptr))
     layout-hook        (: l1 (ResizableTall 1 1/50 1/2 ())
                            l2 (Dwindle 'R 'CW phi 1.1)
                            t  (. minimize smart-borders avoid-struts window-nav
                                  (toggle-layouts Full) (mk-toggle (single 'MIRROR)))
                          (t (||| l1 l2)))
     handle-event-hook  minimize-event-hook
     manage-hook        (compose-all (L (manage-hook def) transience manage-docks
                          (compose-one (L
                            (-?> (<||> (prop? "_NET_WM_WINDOW_TYPE" "..._NOTIFICATION")
                                       (prop? "_NET_WM_WINDOW_TYPE" "..._DOCK"))
                                 (>> do-raise do-ignore))
                            (-?> (prop? "_NET_WM_STATE" "..._FULLSCREEN") do-full-float)
                            (-?> (<||> (prop? "_NET_WM_WINDOW_TYPE" "..._DIALOG")
                                       (class-of? '("Xmessage" "feh" "vlc")))
                                 do-center-float)
                            (-?> (<||> (prop? "_NET_WM_STATE" "..._MODAL")
                                       (class-of? '("steam" "Gimp" "krita")))
                                 do-float)))))
     keys               (union (from-list <the directional + command table>)
                               (keys def)))))
```

Each xmonad combinator gets a love twin with the same name and shape. The list-comprehension
that builds the directional keys becomes a `map`/`for` over the same `(dir keys delta)` rows.

---

## 3. API mapping — every symbol the config uses

### Config record
| xmonad | love | tier | note |
|---|---|---|---|
| `borderWidth = 3` | `border-width 3` | ✓ | ConfigureWindow border |
| `normal/focusedBorderColor` | `normal/focused-border "name"` | 1 | needs X color-name → pixel (AllocNamedColor) |
| `modMask = mod4Mask` | `mod-mask sup` | ✓ | already the spike's grab mod |
| `workspaces = 1..9` | `workspaces (...)` | ✓ | sheaf is N-tag already |
| `startupHook` | `startup-hook (>> ...)` | 1 | spawn + set-lux-name + set-cursor |
| `layoutHook` | `layout-hook ...` | 2 | §4 — the biggest piece |
| `handleEventHook` | `handle-event-hook` | 2 | minimize event hook |
| `manageHook` | `manage-hook ...` | 2 | §5 |
| `keys` | `keys ...` | 2 | §6 |

### Contrib modules → crew/lux/ modules
| import | provides (used here) | love home | tier |
|---|---|---|---|
| `XMonad` core | the WM, `def`, `spawn`, `kill`, `windows`, `sendMessage` | lux.l/core.l | ✓ done |
| `StackSet as W` | `W.sink` `W.floating` `W.member` | core.l (float half) | 2 |
| `Layout.ResizableTile` | `ResizableTall` + `MirrorShrink/Expand` | layout.l | 2 |
| `Layout.Dwindle` | `Dwindle R CW phi` (spiral) | layout.l | 2 |
| `Layout.ToggleLayouts` | `toggleLayouts Full` + `ToggleLayout` | layout.l | 2 |
| `Layout.MultiToggle` (+MIRROR) | `mkToggle (single MIRROR)` + `Toggle` | layout.l | 2 |
| `Layout.NoBorders` | `smartBorders` | layout.l | 2 |
| `Layout.WindowNavigation` | `windowNavigation` + `Go/Swap L/R/U/D` | layout.l+core | 2 (2D) |
| `Layout.Minimize` + `Hooks.Minimize` | `minimize` + `minimizeEventHook` | layout.l | 2 |
| `Layout.Hidden` | (imported; withdraw/restore) | layout.l | 3 (if used) |
| `Actions.FloatKeys` | `keysMoveWindow` `keysResizeWindow` | manage.l | 2 |
| `Actions.GroupNavigation` | `nextMatch Fwd/Bwd isOnAnyVisibleWS` | core.l (history) | 2 |
| `Hooks.ManageHelpers` | `transience'` `doCenterFloat` `doFullFloat` `isInProperty` `composeOne` `-?>` `<||>` | manage.l | 2 |
| `Hooks.ManageDocks` | `docks` `avoidStruts` `manageDocks` `ToggleStruts` | layout.l+ewmh | 2 |
| `Hooks.EwmhDesktops` | `ewmh` `ewmhFullscreen` | ewmh.l | 3 |
| `Hooks.SetWMName` | `setWMName "LG3D"` | ewmh.l | 3 (one property) |
| `Hooks.Place` | (imported; placement) | manage.l | 3 (if used) |
| `Util.Cursor` | `setDefaultCursor xC_left_ptr` | wire.l | 3 (font cursor) |
| `Data.Map` | the keymap | prel maps | ✓ |
| `System.Exit`/`Posix.Process` | `exitWith` `executeFile "openbox"` | run/exit nifs | ✓ |
| `XF86` extra types | (imported, unused in bindings) | — | skip |

---

## 4. Layouts (layout.l) — a layout is a closure, a message is a symbol

The core seam, and where love beats Haskell: xmonad needs existential types + `LayoutClass`
to put `ResizableTall` and `Dwindle` in one `|||`; in love a layout is just

    layout : rect -> [window] -> ([(window rect)] . layout')

a closure from a screen rect + the window row to placements plus a (possibly updated) next
layout. A message is a symbol the layout answers or passes on:

    handle : layout -> msg -> layout | ()      ; () = "I don't take this message"

- **Tall / ResizableTall**: nmaster + master-ratio + per-slave height deltas. `Shrink`/
  `Expand` nudge the ratio (have it), `MirrorShrink`/`MirrorExpand` the per-row deltas,
  `IncMasterN` the master count (have it). This extends the spike's Tall.
- **Dwindle** `R CW phi 1.1`: recursive split, each frame `1/phi` of the last, alternating —
  pure geometry, the fib ratio precomputed. A clean corpus-testable pure function.
- **Modifiers wrap a layout** (a modifier is `layout -> layout`):
  - `toggleLayouts Full`: hold two, a `ToggleLayout` message flips; `Full` gives the focused
    window the whole rect.
  - `mkToggle (single MIRROR)`: `Toggle MIRROR` transposes x<->y of every output rect.
  - `smartBorders`: emit border-width 0 when the row is a singleton or fullscreen (needs the
    driver to set borders per-window from the layout's hint).
  - `avoidStruts`: shrink the input rect by the docks' reserved struts (needs §7).
  - `windowNavigation`: intercept `Go/Swap dir`, resolve against output geometry (§below).
  - `minimize`: filter minimized windows out of the row; `RestoreMinimized` puts them back.
- **`|||` (choice)** + **`NextLayout`**: hold a list + an index; `NextLayout` bumps it.
- **WindowNavigation 2D**: `Go R` = focus the window whose rect is nearest rightward of the
  focused one; `Swap` exchanges them in the stack. This is the one piece that needs real
  geometry, not the linear zipper — a `nearest-in-direction` over the placement list.

Messages ride `sendMessage`: the driver hands the symbol to the current layout's `handle`;
`()` back means "unhandled," so it can fall through a modifier stack cleanly (that fallthrough
is what the existential machinery buys Haskell, free here).

## 5. manageHook (manage.l) — property predicate -> placement

A manageHook is `window -> (endo sheaf)` (a rule that maybe repositions a new window). The
DSL mirrors ManageHelpers exactly:

- `prop? ATOM VALUE` (`isInProperty`): GetProperty on the window, test membership. Needs
  `InternAtom` (have it) + `GetProperty` (new, straightforward) + list decode.
- `class-of? '(names)`: GetProperty `WM_CLASS`, match.
- `<||>` (or), `-?>` (matched-guard), `compose-one` (first match wins), `compose-all` (run
  all): pure combinators over the predicate/action type.
- Actions: `do-float` (into `W.floating` with the window's current geometry), `do-center-float`
  (centered rect), `do-full-float` (screen rect), `do-ignore` (never manage — for docks/
  notifications), `do-raise` (stack on top).
- `transience'`: read `WM_TRANSIENT_FOR`; if set, place the window on its parent's workspace
  as a float.
- `manageDocks`: `doIgnore` for dock/panel windows, and register their struts (§7).

Depends on the **float half of StackSet** landing in core.l: `floating` as a `window -> rect`
map, `W.sink` (float->tile), `W.member`, and the layout skipping floating windows.

## 6. keys (keys.l) — the keymap DSL + the default map

The config is `(. keys def) . M.union . M.fromList $ [custom]` — custom bindings UNION over
xmonad's **default keymap**, custom winning. So keys.l ships BOTH:

- **`keys def`** — xmonad's stock table, minus the multi-screen bindings (single monitor, so
  `mod+w/e/r` and `mod+shift+w/e/r` are dropped, not ported): `mod+1..9` view,
  `mod+shift+1..9` shift-to-ws, `mod+shift+c` kill, `mod+space` layout, `mod+j/k` focus,
  `mod+return` swap-master, `mod+t` sink, `mod+,`/`mod+.` IncMasterN, `mod+shift+return` term,
  `mod+shift+space` reset, `mod+n` refresh, `mod+shift+q` quit. (Some overridden below.)
- **The custom table**, exactly as written:
  - The directional block: `(dir keys delta)` over `L/D/U/R` × `{hjkl, arrows}`, three
    modifiers each — `sup` = float? move-by-delta : `Go dir`; `sup+shift` = float? resize :
    `Swap dir`; `sup+ctrl` = float? resize : `Shrink`/`Expand`. The `f_t` float-test is the
    hinge (needs `W.floating`).
  - Commands: `sup+x` kill, `sup+shift+q` exit, `sup+return` term, `sup+grave` rofi,
    `sup+space` NextLayout, `sup+b` ToggleStruts, `sup+m` Toggle MIRROR, `sup+f` ToggleLayout,
    `sup+p` screenshot, `sup+w` sink/float, `sup+shift+e` edit-config, `sup+e` rofimoji,
    `sup+z` screensaver, `sup+shift+o` exec openbox --replace, `sup+shift+z` lock,
    `alt+Tab`/`sup+Tab` nextMatch, `sup+,`/`sup+.` IncMasterN±1, `sup+shift+,`/`.` Shrink/Expand.

Mechanically: build the `(mod . keysym) -> action` map, `GetKeyboardMapping` for keysyms,
`GrabKey` each chord (have the machinery), KeyPress `(state keycode)` looks up + runs the
action. `keysMoveWindow`/`keysResizeWindow` (FloatKeys) mutate a float's rect by pixels.
`nextMatch` (GroupNavigation) needs a focus-history ring maintained on every focus change.

## 7. EWMH + docks (ewmh.l) — the protocol tax

`ewmh . ewmhFullscreen . docks` is what makes fullscreen apps, panels, and pagers behave:
- A **support window** advertising `_NET_SUPPORTING_WM_CHECK` + `_NET_WM_NAME` (also carries
  the `LG3D` name for the Java hack — `setWMName`).
- `_NET_SUPPORTED` (the atoms we honor), `_NET_CLIENT_LIST`, `_NET_ACTIVE_WINDOW`,
  `_NET_CURRENT_DESKTOP`/`_NET_WM_DESKTOP` (kept in sync with the sheaf, so pagers track us),
  `_NET_WM_STATE_FULLSCREEN` (client asks fullscreen -> full-float; `ewmhFullscreen`).
- **docks/struts**: read `_NET_WM_STRUT_PARTIAL` off dock windows, subtract from each screen
  rect before layout; `avoidStruts` toggles this, `ToggleStruts` (`sup+b`) flips it live.

Every item is a ChangeProperty/GetProperty — bounded, just voluminous. This tier is what
separates "manages my windows" from "my taskbar and fullscreen video work."

---

## 8. Rung order (each Xephyr-testable, like rungs 1–5)

1. **crew/lux/ scaffold** — split rungs 1–5 into core.l/wire.l/lux.l, kill the single-`:` collision
   trap. Rung 6 (workspaces 1–9) lands here, clean. *Unblocks everything.*
2. **Float half of StackSet** (core.l) — `floating` map, `W.sink`, `f_t`; corpus laws for it.
3. **Layout engine** (layout.l) — the closure/message protocol + Tall/ResizableTall/Full/
   `|||`/NextLayout. Two real windows tile and toggle.
4. **Layout modifiers** — toggle/mirror/smartBorders/windowNavigation/minimize + Dwindle.
5. **manageHook DSL** (manage.l) — GetProperty/atoms + the float placements + transience.
6. **keymap DSL + default map** (keys.l) — the full `keys def ∪ custom` table wired live.
7. **EWMH + docks** (ewmh.l) — support window, `_NET_*`, struts, fullscreen.
8. **config.l** — transliterate `xmonad.hs`, run it against Xephyr, then real X.
9. **Graduate** — `make install` a `lux` binary; restart-in-place (`sup+shift+o`-style) via the
   dock's adopt re-exec ([[the-dock]] memory).

---

## 9. Honest hard bits / open questions

- **Single monitor — settled.** No Xinerama, no screen list; the sheaf's one-visible-workspace
  model is exactly right, and xmonad's multi-screen bindings (`mod+w/e/r`) are simply not
  ported. This removes what would otherwise be the biggest structural extension.
- **`XMonad.Layout.Hidden` / `Hooks.Place`** are imported but not obviously exercised in the
  record — will confirm before building them (may be dead imports).
- **Fonts/cursors/colors** need a few extra requests (AllocNamedColor, CreateGlyphCursor) —
  small but new wire surface.
- **Exact fidelity of `def`.** xmonad's default keymap/manageHook has a specific shape; I'll
  pin it to the xmonad version you run so `keys def` matches byte-for-byte behavior.

Nothing here is a blocker — it is a bounded, multi-rung build, every rung concrete and
testable against Xephyr exactly as rungs 1–5 were.
