; crew/rune/seal.l -- the module boundary. crew/rune/rune.l opened a named scope
; ((enter 'rune)); closing it here unwinds the layer and REGISTERS it as `rune`
; in the module registry. a consumer splices it -- (use 'rune), bare names
; resolve, cleared by a bare (leave ()) -- or reaches one member through the
; opaque accessor: (from 'rune 'deriv); (from 'rune 'keys) lists the internals.
(leave ())
