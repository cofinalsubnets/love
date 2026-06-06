// list pipeline: square every element, keep the even results, sum them.
const { bench } = require("../lib/bench");
const data = Array.from({ length: 10000 }, (_, i) => i);
bench("mapfilter", () => data.map(x => x * x).filter(x => x % 2 === 0).reduce((a, b) => a + b, 0));
