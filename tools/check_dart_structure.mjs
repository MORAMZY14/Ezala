import fs from 'node:fs/promises';
import path from 'node:path';

const roots = ['lib', 'test'];
const files = [];

async function walk(directory) {
  for (const entry of await fs.readdir(directory, { withFileTypes: true })) {
    const target = path.join(directory, entry.name);
    if (entry.isDirectory()) await walk(target);
    else if (entry.isFile() && target.endsWith('.dart')) files.push(target);
  }
}

for (const root of roots) await walk(root);

const pairs = { '(': ')', '[': ']', '{': '}' };
for (const file of files) {
  const source = await fs.readFile(file, 'utf8');
  const stack = [];
  let state = 'code';
  let quote = '';
  let triple = false;
  let raw = false;
  let blockDepth = 0;

  for (let index = 0; index < source.length; index += 1) {
    const char = source[index];
    const next = source[index + 1];
    const nextTwo = source.slice(index, index + 3);

    if (state === 'line-comment') {
      if (char === '\n') state = 'code';
      continue;
    }
    if (state === 'block-comment') {
      if (char === '/' && next === '*') {
        blockDepth += 1;
        index += 1;
      } else if (char === '*' && next === '/') {
        blockDepth -= 1;
        index += 1;
        if (blockDepth === 0) state = 'code';
      }
      continue;
    }
    if (state === 'string') {
      if (!raw && char === '\\') {
        index += 1;
        continue;
      }
      if (triple && nextTwo === quote.repeat(3)) {
        index += 2;
        state = 'code';
      } else if (!triple && char === quote) {
        state = 'code';
      }
      continue;
    }

    if (char === '/' && next === '/') {
      state = 'line-comment';
      index += 1;
      continue;
    }
    if (char === '/' && next === '*') {
      state = 'block-comment';
      blockDepth = 1;
      index += 1;
      continue;
    }
    if (char === "'" || char === '"') {
      raw = index > 0 && source[index - 1] === 'r';
      quote = char;
      triple = nextTwo === char.repeat(3);
      if (triple) index += 2;
      state = 'string';
      continue;
    }

    if (pairs[char]) {
      stack.push({ char, index });
    } else if (Object.values(pairs).includes(char)) {
      const opening = stack.pop();
      if (!opening || pairs[opening.char] !== char) {
        throw new Error('Unmatched ' + char + ' in ' + file);
      }
    }
  }

  if (state === 'string' || state === 'block-comment' || stack.length > 0) {
    throw new Error('Unclosed syntax structure in ' + file);
  }

  const imports = [...source.matchAll(/import\s+'([^']+)'\s*;/g)];
  for (const match of imports) {
    const target = match[1];
    if (!target.startsWith('.')) continue;
    const resolved = path.normalize(path.join(path.dirname(file), target));
    try {
      await fs.access(resolved);
    } catch {
      throw new Error('Missing import ' + target + ' from ' + file);
    }
  }
}

console.log('Checked ' + files.length + ' Dart files.');
