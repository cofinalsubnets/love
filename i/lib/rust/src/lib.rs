//! love as a rust library.
//!
//! what the C header's shape buys here:
//!  - a scare is a return code, so `Result` needs no `catch_unwind` around the
//!    interpreter and no `setjmp` shim. that is the whole reason this is easier
//!    than embedding a runtime that unwinds through C.
//!  - a value is a stack index, never a pointer, so nothing needs a lifetime
//!    tied to the collector. the copying door is the only way a string leaves.
//!  - `Ctx` is `!Send` and `!Sync` by construction: the runtime has no lock and
//!    its three console ports are process-global.

use std::ffi::{c_char, c_int, c_void, CStr, CString};
use std::marker::PhantomData;

#[repr(C)]
struct LvOpt {
    write: Option<extern "C" fn(*mut c_void, c_int, *const c_char, usize)>,
    write_ud: *mut c_void,
    budget_mb: usize,
    image: *const c_void,
    image_len: usize,
}

type LvFn = extern "C" fn(*mut c_void, *mut c_void, c_int) -> c_int;

unsafe extern "C" {
    fn lv_open(o: *const LvOpt) -> *mut c_void;
    fn lv_close(l: *mut c_void);
    fn lv_eval(l: *mut c_void, s: *const c_char) -> c_int;
    fn lv_apply(l: *mut c_void, n: c_int) -> c_int;
    fn lv_ok(l: *const c_void) -> c_int;
    fn lv_error(l: *mut c_void) -> *const c_char;
    fn lv_top(l: *const c_void) -> c_int;
    fn lv_pop(l: *mut c_void, n: c_int);
    fn lv_dup(l: *mut c_void, i: c_int) -> c_int;
    fn lv_pushint(l: *mut c_void, n: isize) -> c_int;
    fn lv_pushflo(l: *mut c_void, d: f64) -> c_int;
    fn lv_pushstr(l: *mut c_void, s: *const c_char, n: usize) -> c_int;
    fn lv_type_at(l: *mut c_void, i: c_int) -> c_int;
    fn lv_toint(l: *mut c_void, i: c_int) -> isize;
    fn lv_toflo(l: *mut c_void, i: c_int) -> f64;
    fn lv_strcpy(l: *mut c_void, i: c_int, dst: *mut c_char, cap: usize) -> usize;
    fn lv_count(l: *mut c_void, i: c_int) -> c_int;
    fn lv_at(l: *mut c_void, i: c_int, k: c_int) -> c_int;
    fn lv_defn(l: *mut c_void, n: *const c_char, a: c_int, f: LvFn, ud: *mut c_void) -> c_int;
}

#[derive(Debug, PartialEq, Eq, Clone, Copy)]
pub enum Type { Nil, Int, Flo, Str, Sym, List, Fn, Other }

impl Type {
    fn of(n: c_int) -> Type {
        [Type::Nil, Type::Int, Type::Flo, Type::Str,
         Type::Sym, Type::List, Type::Fn, Type::Other][n.clamp(0, 7) as usize]
    }
}

pub type Res<T> = Result<T, String>;

/// a borrowed session. every operation lives here so a host callback gets the
/// same surface the owner has, without owning the close.
pub struct Ctx { raw: *mut c_void, _nosend: PhantomData<*const ()> }

impl Ctx {
    fn check(&mut self, rc: c_int) -> Res<()> {
        if rc == 0 { return Ok(()); }
        let e = unsafe { CStr::from_ptr(lv_error(self.raw)) };
        Err(e.to_string_lossy().trim().to_string())
    }

    pub fn eval(&mut self, src: &str) -> Res<()> {
        let c = CString::new(src).map_err(|e| e.to_string())?;
        let rc = unsafe { lv_eval(self.raw, c.as_ptr()) };
        self.check(rc)
    }

    /// apply the value under `nargs` arguments. push the function, then the
    /// arguments in order.
    pub fn apply(&mut self, nargs: i32) -> Res<()> {
        let rc = unsafe { lv_apply(self.raw, nargs) };
        self.check(rc)
    }

    pub fn ok(&self) -> bool { unsafe { lv_ok(self.raw) != 0 } }
    pub fn top(&self) -> i32 { unsafe { lv_top(self.raw) } }
    pub fn pop(&mut self, n: i32) { unsafe { lv_pop(self.raw, n) } }
    pub fn dup(&mut self, i: i32) { unsafe { lv_dup(self.raw, i); } }
    pub fn push_int(&mut self, n: isize) { unsafe { lv_pushint(self.raw, n); } }
    pub fn push_flo(&mut self, d: f64) { unsafe { lv_pushflo(self.raw, d); } }
    pub fn push_str(&mut self, s: &str) {
        unsafe { lv_pushstr(self.raw, s.as_ptr() as *const c_char, s.len()); }
    }
    pub fn type_at(&mut self, i: i32) -> Type { Type::of(unsafe { lv_type_at(self.raw, i) }) }
    pub fn to_int(&mut self, i: i32) -> isize { unsafe { lv_toint(self.raw, i) } }
    pub fn to_flo(&mut self, i: i32) -> f64 { unsafe { lv_toflo(self.raw, i) } }
    pub fn count(&mut self, i: i32) -> i32 { unsafe { lv_count(self.raw, i) } }
    pub fn at(&mut self, i: i32, k: i32) { unsafe { lv_at(self.raw, i, k); } }

    /// the copying door. a borrowed `&str` cannot be handed out: the collector
    /// moves every string, so heap bytes are good only until the next call.
    pub fn get_string(&mut self, i: i32) -> String {
        let n = unsafe { lv_strcpy(self.raw, i, std::ptr::null_mut(), 0) };
        let mut b = vec![0u8; n + 1];
        unsafe { lv_strcpy(self.raw, i, b.as_mut_ptr() as *mut c_char, n + 1) };
        b.truncate(n);
        String::from_utf8_lossy(&b).into_owned()
    }
}

type Cb = Box<dyn FnMut(&mut Ctx, i32) -> Res<()>>;

/// an owned session.
pub struct Lv { ctx: Ctx, kept: Vec<*mut Cb> }

impl Lv {
    pub fn open() -> Res<Lv> {
        let o = LvOpt { write: None, write_ud: std::ptr::null_mut(),
                        budget_mb: 0, image: std::ptr::null(), image_len: 0 };
        let raw = unsafe { lv_open(&o) };
        if raw.is_null() { return Err("lv_open failed".into()); }
        Ok(Lv { ctx: Ctx { raw, _nosend: PhantomData }, kept: Vec::new() })
    }

    /// bind a rust closure as a love function. the box is kept for the life of
    /// the session: the nif cell the runtime holds must be immortal, and so must
    /// whatever it points at.
    pub fn defn<F>(&mut self, name: &str, arity: i32, f: F) -> Res<()>
    where F: FnMut(&mut Ctx, i32) -> Res<()> + 'static {
        let c = CString::new(name).map_err(|e| e.to_string())?;
        let b: *mut Cb = Box::into_raw(Box::new(Box::new(f) as Cb));
        self.kept.push(b);
        let rc = unsafe { lv_defn(self.ctx.raw, c.as_ptr(), arity, tramp, b as *mut c_void) };
        self.ctx.check(rc)
    }
}

impl std::ops::Deref for Lv { type Target = Ctx; fn deref(&self) -> &Ctx { &self.ctx } }
impl std::ops::DerefMut for Lv { fn deref_mut(&mut self) -> &mut Ctx { &mut self.ctx } }

// a panic must not cross the FFI boundary: catch it and answer a scare instead.
extern "C" fn tramp(l: *mut c_void, ud: *mut c_void, n: c_int) -> c_int {
    let r = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        // SAFETY: the runtime is single-threaded and re-entrant only through
        // this call, so the box and the session are unaliased while it runs.
        let cb = unsafe { &mut *(ud as *mut Cb) };
        let mut ctx = Ctx { raw: l, _nosend: PhantomData };
        cb(&mut ctx, n)
    }));
    match r { Ok(Ok(())) => 0, _ => -1 }
}

impl Drop for Lv {
    fn drop(&mut self) {
        unsafe { lv_close(self.ctx.raw) };
        for b in self.kept.drain(..) { drop(unsafe { Box::from_raw(b) }); }
    }
}
