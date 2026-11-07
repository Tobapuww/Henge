// Shows, side by side, every string literal of a file before and after the
// Chinese rewrite, so interpolations (`\(...)`) that changed are visible too.
// Usage: node pairs.mjs <baseline-dir> <path> [path...]
import fs from 'node:fs';
import path from 'node:path';

const [baseline, ...files] = process.argv.slice(2);

function literals(src) {
  const out = [];
  let i = 0;
  while (i < src.length) {
    if (src[i] === '"') {
      if (src.startsWith('"""', i)) {
        const end = src.indexOf('"""', i + 3);
        if (end === -1) { i++; continue; }
        out.push(src.slice(i, end + 3));
        i = end + 3;
        continue;
      }
      let j = i + 1;
      let depth = 0;
      while (j < src.length) {
        const d = src[j];
        if (d === '\\') { j += src[j + 1] === '(' ? 1 : 2; continue; }
        if (depth > 0) { if (d === '(') depth++; else if (d === ')') depth--; j++; continue; }
        if (d === '"' || d === '\n') break;
        j++;
      }
      out.push(src.slice(i, j + 1));
      i = j + 1;
      continue;
    }
    i++;
  }
  return out;
}

for (const rel of files) {
  const a = literals(fs.readFileSync(path.join(baseline, rel), 'utf8'));
  const b = literals(fs.readFileSync(rel, 'utf8'));
  console.log(`\n=== ${rel}: ${a.length} -> ${b.length} literals`);
  if (a.length !== b.length) {
    console.log('!! COUNT DIFFERS — inspect by hand');
    continue;
  }
  for (let k = 0; k < a.length; k++) {
    if (a[k] === b[k]) continue;
    // Anything interpolated must keep exactly the same expressions.
    const interp = (s) => (s.match(/\\\([^)]*(?:\([^)]*\)[^)]*)*\)/g) ?? []).join('|');
    const ia = interp(a[k]);
    const ib = interp(b[k]);
    const flag = ia === ib ? '   ' : ' !!';
    console.log(`${flag} ${a[k]}`);
    console.log(`${flag} -> ${b[k]}`);
    if (ia !== ib) {
      console.log(`      interpolations differ:\n        ${ia}\n        ${ib}`);
    }
  }
}
