// Finds English prose still inside Swift string literals: anything that looks
// like a sentence or a UI label (two or more lower-case English words in a row),
// so translations can be checked for stragglers. Log tags, identifiers, keys,
// URLs, file names and SF Symbols do not match.
// Usage: node english.mjs [paths...]
import fs from 'node:fs';
import path from 'node:path';

function literals(src) {
  const out = [];
  let line = 1;
  let i = 0;
  while (i < src.length) {
    const c = src[i];
    if (c === '\n') { line++; i++; continue; }
    if (c === '/' && src[i + 1] === '/') {
      const end = src.indexOf('\n', i);
      if (end === -1) break;
      i = end;
      continue;
    }
    if (c !== '"') { i++; continue; }
    const startLine = line;
    if (src.startsWith('"""', i)) {
      const end = src.indexOf('"""', i + 3);
      if (end === -1) { i++; continue; }
      out.push({ line: startLine, text: src.slice(i + 3, end) });
      line += (src.slice(i, end).match(/\n/g) ?? []).length;
      i = end + 3;
      continue;
    }
    let j = i + 1;
    let depth = 0;
    while (j < src.length) {
      const d = src[j];
      if (d === '\\') { j += 2; continue; }
      if (depth > 0) {
        if (d === '(') depth++;
        else if (d === ')') depth--;
        else if (d === '\n') line++;
        j++;
        continue;
      }
      if (d === '\\') { j += 2; continue; }
      if (d === '(' && src[j - 1] === '\\') { depth++; j++; continue; }
      if (d === '"' || d === '\n') break;
      j++;
    }
    out.push({ line: startLine, text: src.slice(i + 1, j) });
    i = j + 1;
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

const files = process.argv.length > 2 ? process.argv.slice(2) : walk('ios');
let total = 0;
for (const f of files) {
  const rel = f.split(path.sep).join('/');
  const hits = [];
  for (const { line, text } of literals(fs.readFileSync(f, 'utf8'))) {
    // two or more plain English words in a row
    if (!/[A-Za-z]{3,}\s+[a-z]{2,}/.test(text)) continue;
    if (/^(https?|\/|_|[a-z0-9.]+\.(swift|js|plist|png|jpg|json|bin|img|gz|log))/.test(text.trim())) continue;
    if (/^(com|org)\.[a-z]/.test(text.trim())) continue;
    hits.push(`${String(line).padStart(4)}  ${text}`);
  }
  if (!hits.length) continue;
  total += hits.length;
  console.log(`\n-- ${rel}: ${hits.length}`);
  for (const h of hits) console.log('   ' + h);
}
console.log(`\n${total} candidate string(s)`);
