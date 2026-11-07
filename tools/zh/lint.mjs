// Structural check of Swift string literals: an unterminated literal or an
// unbalanced interpolation would break the build even though the code outside
// literals is identical, so both are reported. Nested literals inside
// interpolations (`\(cond ? "a" : "b")`) are legal and handled recursively.
// Usage: node lint.mjs [paths...]
import fs from 'node:fs';
import path from 'node:path';

function walk(dir, acc = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (e.name === '.git' || e.name === 'build' || e.name === 'deps') continue;
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, acc);
    else if (p.endsWith('.swift')) acc.push(p);
  }
  return acc;
}

// Scans one string literal starting at the opening quote; returns the index just
// past the closing quote, or -1 when the literal never closes.
function scanString(src, start, problems, where) {
  if (src.startsWith('"""', start)) {
    const end = src.indexOf('"""', start + 3);
    if (end === -1) { problems.push(`${where}: unterminated multi-line literal`); return -1; }
    return end + 3;
  }
  let i = start + 1;
  while (i < src.length) {
    const c = src[i];
    if (c === '\n') return -1;                       // a plain literal cannot span lines
    if (c === '\\') {
      if (src[i + 1] === '(') {
        const end = scanInterpolation(src, i + 2, problems, where);
        if (end === -1) return -1;
        i = end;
        continue;
      }
      i += 2;
      continue;
    }
    if (c === '"') return i + 1;
    i++;
  }
  return -1;
}

// Scans the code inside `\( ... )`; nested literals are scanned as literals.
function scanInterpolation(src, start, problems, where) {
  let i = start;
  let depth = 1;
  while (i < src.length) {
    const c = src[i];
    if (c === '"') {
      const end = scanString(src, i, problems, where);
      if (end === -1) { problems.push(`${where}: unterminated literal inside interpolation`); return -1; }
      i = end;
      continue;
    }
    if (c === '(') { depth++; i++; continue; }
    if (c === ')') {
      depth--;
      i++;
      if (depth === 0) return i;
      continue;
    }
    if (c === '\n') { problems.push(`${where}: interpolation spans lines`); return -1; }
    i++;
  }
  problems.push(`${where}: interpolation never closes`);
  return -1;
}

const problems = [];
for (const f of process.argv.length > 2 ? process.argv.slice(2) : walk('ios')) {
  const src = fs.readFileSync(f, 'utf8');
  let i = 0;
  while (i < src.length) {
    const c = src[i];
    if (c === '/' && src[i + 1] === '/') { const e = src.indexOf('\n', i); i = e === -1 ? src.length : e; continue; }
    if (c === '/' && src[i + 1] === '*') { const e = src.indexOf('*/', i + 2); i = e === -1 ? src.length : e + 2; continue; }
    if (c !== '"') { i++; continue; }
    const line = src.slice(0, i).split('\n').length;
    const end = scanString(src, i, problems, `${f}:${line}`);
    i = end === -1 ? src.indexOf('\n', i) : end;
    if (i === -1) break;
  }
}
for (const p of problems) console.log(p);
console.log(problems.length === 0 ? 'LITERALS OK' : `${problems.length} problem(s)`);
process.exit(problems.length === 0 ? 0 : 1);
