// Lists the string literals left in a Swift file, with the line they sit on, so a
// reviewer can see what still reads as English.
// Usage: node report.mjs [paths...]
import fs from 'node:fs';
import path from 'node:path';

const roots = process.argv.slice(2);
const files = [];
function walk(p) {
  const st = fs.statSync(p);
  if (st.isDirectory()) {
    for (const e of fs.readdirSync(p)) {
      if (e === '.git' || e === 'build' || e === 'deps') continue;
      walk(path.join(p, e));
    }
  } else if (p.endsWith('.swift')) {
    files.push(p);
  }
}
for (const r of roots.length ? roots : ['ios']) walk(r);

const HAN = /[\u4e00-\u9fff]/;
const ASCII_WORD = /[A-Za-z]{3,}/;

for (const f of files) {
  const lines = fs.readFileSync(f, 'utf8').split('\n');
  const hits = [];
  lines.forEach((line, idx) => {
    const re = /"((?:[^"\\\n]|\\.)*)"/g;
    let m;
    while ((m = re.exec(line))) {
      const text = m[1];
      if (!text || HAN.test(text)) continue;
      if (!ASCII_WORD.test(text)) continue;
      hits.push({ line: idx + 1, text, src: line.trim() });
    }
  });
  if (hits.length === 0) {
    console.log(`-- ${f}: none`);
    continue;
  }
  console.log(`-- ${f}: ${hits.length}`);
  for (const h of hits) console.log(`   ${h.line}\t${h.text}`);
}
