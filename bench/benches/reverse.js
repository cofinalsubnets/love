// reverse a 20000-element list each iteration; checksum = new head = 19999.
const { bench } = require("../lib/bench");
const data = Array.from({ length: 20000 }, (_, i) => i);
bench("reverse", () => data.slice().reverse()[0]);
