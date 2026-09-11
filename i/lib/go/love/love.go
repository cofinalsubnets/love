// Package love embeds the love interpreter.
//
// what cgo's rules cost, and what the C shape already pays for:
//   - no Go pointer ever crosses into C. a value is a stack index, and the one
//     userdata a callback carries is a cgo.Handle, which is an integer. that is
//     the cgo pointer rule satisfied by construction rather than by discipline.
//   - a session is not safe for concurrent use and the runtime has no lock, so
//     Lv pins itself to one OS thread and every entry point goes through it.
//   - a scare is a return code, so nothing unwinds through cgo.
package love

/*
#cgo CFLAGS: -I${SRCDIR}/../../
#cgo LDFLAGS: ${SRCDIR}/../../../../b/liblv.o
#include <stdlib.h>
#include "lv.h"

int lv_go_tramp(struct lv*, void*, int);
static int lv_defn_go(struct lv *l, char const *n, int a, void *ud) {
  return lv_defn(l, n, a, lv_go_tramp, ud); }
*/
import "C"

import (
	"errors"
	"runtime"
	"runtime/cgo"
	"strings"
	"unsafe"
)

type Type int

const (
	Nil Type = iota
	Int
	Flo
	Str
	Sym
	List
	Proc
	Other
)

// Lv is one session. Not safe for concurrent use.
type Lv struct {
	raw  *C.struct_lv
	kept []cgo.Handle
}

// Fn is a Go function love can call. Arguments are at indices 0..n-1; push one
// answer and return nil.
type Fn func(*Lv, int) error

func Open() (*Lv, error) {
	runtime.LockOSThread()
	raw := C.lv_open(nil)
	if raw == nil {
		return nil, errors.New("lv_open failed")
	}
	return &Lv{raw: raw}, nil
}

func (l *Lv) Close() {
	C.lv_close(l.raw)
	for _, h := range l.kept {
		h.Delete()
	}
	l.kept = nil
	runtime.UnlockOSThread()
}

func (l *Lv) check(rc C.int) error {
	if rc == 0 {
		return nil
	}
	return errors.New(strings.TrimSpace(C.GoString(C.lv_error(l.raw))))
}

func (l *Lv) Eval(src string) error {
	c := C.CString(src)
	defer C.free(unsafe.Pointer(c))
	return l.check(C.lv_eval(l.raw, c))
}

// Apply applies the value under nargs arguments: push the function, then the
// arguments in order.
func (l *Lv) Apply(nargs int) error { return l.check(C.lv_apply(l.raw, C.int(nargs))) }

func (l *Lv) OK() bool           { return C.lv_ok(l.raw) != 0 }
func (l *Lv) Top() int           { return int(C.lv_top(l.raw)) }
func (l *Lv) Pop(n int)          { C.lv_pop(l.raw, C.int(n)) }
func (l *Lv) Dup(i int)          { C.lv_dup(l.raw, C.int(i)) }
func (l *Lv) PushInt(n int)      { C.lv_pushint(l.raw, C.intptr_t(n)) }
func (l *Lv) PushFlo(d float64)  { C.lv_pushflo(l.raw, C.double(d)) }
func (l *Lv) TypeAt(i int) Type  { return Type(C.lv_type_at(l.raw, C.int(i))) }
func (l *Lv) ToInt(i int) int    { return int(C.lv_toint(l.raw, C.int(i))) }
func (l *Lv) ToFlo(i int) float64 { return float64(C.lv_toflo(l.raw, C.int(i))) }
func (l *Lv) Count(i int) int    { return int(C.lv_count(l.raw, C.int(i))) }
func (l *Lv) At(i, k int)        { C.lv_at(l.raw, C.int(i), C.int(k)) }

func (l *Lv) PushStr(s string) {
	c := C.CString(s)
	defer C.free(unsafe.Pointer(c))
	C.lv_pushstr(l.raw, c, C.size_t(len(s)))
}

// String copies. love's collector moves every string, so a []byte view of heap
// bytes would be stale by the next call.
func (l *Lv) String(i int) string {
	n := C.lv_strcpy(l.raw, C.int(i), nil, 0)
	if n == 0 {
		return ""
	}
	b := make([]byte, n+1)
	C.lv_strcpy(l.raw, C.int(i), (*C.char)(unsafe.Pointer(&b[0])), C.size_t(n+1))
	return string(b[:n])
}

// Defn binds a Go function as a love function. The handle lives as long as the
// session: the nif cell the runtime keeps is immortal, and so is what it names.
func (l *Lv) Defn(name string, arity int, f Fn) error {
	c := C.CString(name)
	defer C.free(unsafe.Pointer(c))
	h := cgo.NewHandle(goNif{l, f})
	l.kept = append(l.kept, h)
	return l.check(C.lv_defn_go(l.raw, c, C.int(arity), unsafe.Pointer(uintptr(h))))
}

type goNif struct {
	l *Lv
	f Fn
}

//export lv_go_tramp
func lv_go_tramp(_ *C.struct_lv, ud unsafe.Pointer, n C.int) C.int {
	g := cgo.Handle(uintptr(ud)).Value().(goNif)
	if err := g.f(g.l, int(n)); err != nil {
		return -1
	}
	return 0
}
