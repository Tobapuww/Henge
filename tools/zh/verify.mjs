// Verifies that a Swift file changed only the *contents* of string literals.
//
// Compares every listed file against the same file in a baseline tree and strips
// string literals from both: what remains must be byte-identical, otherwise the
// edit changed code (identifiers, flags, structure) and is reported as a failure.
//
// Usage: node verify.mjs <baseline-dir> [paths...]
//   baseline-dir  a checkout of the untouched sources (e.g. a `git archive` extract)
import fs from 'node:fs';
import path from 'node:path';

const baseline = process.argv[2];
if (!baseline) {
  console.error('usage: node verify.mjs <baseline-dir> [paths...]');
  process.exit(2);
}

function stripLiterals(src) {
  let out = '';
  let i = 0;
  while (i < src.length) {
    const c = src[i];
    if (c === '"') {
      if (src.startsWith('"""', i)) {
        const end = src.indexOf('"""', i + 3);
        if (end === -1) { out += '"'; i++; continue; }
        out += '""';
        i = end + 3;
        continue;
      }
      let j = i + 1;
      let depth = 0;
      while (j < src.length) {
        const d = src[j];
        if (d === '\\') {
          if (src[j + 1] === '(') { depth++; j += 2; continue; }
          j += 2;
          continue;
        }
        if (depth > 0) {
          if (d === '(') depth++;
          else if (d === ')') depth--;
          j++;
          continue;
        }
        if (d === '"' || d === '\n') break;
        j++;
      }
      out += '""';
      i = j + 1;
      continue;
    }
    if (c === '/' && src[i + 1] === '/') {
      const end = src.indexOf('\n', i);
      if (end === -1) { out += src.slice(i); break; }
      out += src.slice(i, end);
      i = end;
      continue;
    }
    out += c;
    i++;
  }
  return out;
}

function walk(dir, acc = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (e.name === '.git' || e.name === 'build' || e.name === 'deps') continue;
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, acc);
    else if (p.endsWith('.swift')) acc.push(p);
  }
  return acc;
}

const only = process.argv.slice(3);
const files = only.length
  ? only
  : walk('ios').map((p) => p.split(path.sep).join('/'));

let bad = 0;
let checked = 0;
for (const rel of files) {
  if (!rel.endsWith('.swift')) continue;
  const baseFile = path.join(baseline, rel);
  if (!fs.existsSync(rel) || !fs.existsSync(baseFile)) {
    console.log(`SKIP   ${rel} (missing on one side)`);
    continue;
  }
  // A text editor may add a BOM or rewrite CRLF; neither is a code change.
  const norm = (s) => s.replace(/^\uFEFF/, '').replace(/\r\n/g, '\n');
  const before = norm(fs.readFileSync(baseFile, 'utf8'));
  const after = norm(fs.readFileSync(rel, 'utf8'));
  checked++;
  const a = stripLiterals(before);
  const b = stripLiterals(after);
  if (a === b) {
    console.log(`OK     ${rel}`);
    continue;
  }
  bad++;
  const la = a.split('\n');
  const lb = b.split('\n');
  console.log(`BAD    ${rel}: code outside string literals changed`);
  let shown = 0;
  for (let k = 0; k < Math.max(la.length, lb.length) && shown < 8; k++) {
    if (la[k] !== lb[k]) {
      console.log(`   line ${k + 1}`);
      console.log(`   -  ${(la[k] ?? '<none>').trim().slice(0, 170)}`);
      console.log(`   +  ${(lb[k] ?? '<none>').trim().slice(0, 170)}`);
      shown++;
    }
  }
}
console.log(bad === 0 ? `\nALL CLEAN (${checked} files)` : `\n${bad} FILE(S) CHANGED CODE (of ${checked})`);
process.exit(bad === 0 ? 0 : 1);
