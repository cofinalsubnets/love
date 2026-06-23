include!("../lib/bench.rs");

// binary-trees allocation/GC stress (see bench/benches/tree.l). checksum = 2^D-1.
// mk builds a real heap-allocated tree (the allocation is the point); ck counts.
enum Tree {
    Leaf,
    Node(Box<Tree>, Box<Tree>),
}

fn mk(d: i64) -> Tree {
    if d == 0 {
        Tree::Leaf
    } else {
        Tree::Node(Box::new(mk(d - 1)), Box::new(mk(d - 1)))
    }
}

fn ck(t: &Tree) -> i64 {
    match t {
        Tree::Leaf => 0,
        Tree::Node(l, r) => 1 + ck(l) + ck(r),
    }
}

fn main() {
    bench("tree", || ck(&mk(16)));
}
