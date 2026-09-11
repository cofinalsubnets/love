use love::Lv;

fn main() -> Result<(), String> {
    let t0 = std::time::Instant::now();
    let mut l = Lv::open()?;
    println!("open        {:?}", t0.elapsed());

    l.eval("+[1 2 3 4]")?;
    println!("net         {}  ({:?})", l.to_int(0), l.type_at(0));
    l.pop(1);

    l.eval("(\"hello \" + \"world\")")?;
    println!("string      {}", l.get_string(0));
    l.pop(1);

    l.eval("(map (+ 1) [1 2 3])")?;
    let n = l.count(0);
    let mut v = Vec::new();
    for i in 0..n { l.at(0, i); v.push(l.to_int(0)); l.pop(1); }
    println!("list        {v:?}");
    l.pop(1);

    // a love closure applied to rust-made arguments
    l.eval("(a \\ b \\ a * a + b)")?;
    l.dup(0);
    l.push_int(7);
    l.push_int(5);
    l.apply(2)?;
    println!("apply       {}", l.to_int(0));
    l.pop(1);

    let t = std::time::Instant::now();
    const N: u32 = 20000;
    for _ in 0..N { l.dup(0); l.push_int(7); l.push_int(5); l.apply(2)?; l.pop(1); }
    println!("apply cost  {:.2} us/call", t.elapsed().as_secs_f64() * 1e6 / N as f64);
    l.pop(1);

    // rust called from love
    l.defn("hypot", 2, |c, _| { let (a, b) = (c.to_flo(0), c.to_flo(1));
                                c.push_flo((a * a + b * b).sqrt()); Ok(()) })?;
    l.eval("(hypot 3.0 4.0)")?;
    println!("callback    {}", l.to_flo(0));
    l.pop(1);

    match l.eval("(scare 'boom 42)") {
        Err(e) => println!("scare       {e}"),
        Ok(()) => println!("scare       (none?)"),
    }
    println!("after scare depth {}, ok={}", l.top(), l.ok());
    Ok(())
}
