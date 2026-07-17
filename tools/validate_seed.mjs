import fs from 'node:fs/promises';

const source = JSON.parse(
  await fs.readFile(new URL('../assets/data/mmr_cabinets.json', import.meta.url)),
);
const cabinets = source.cabinets ?? [];
const seenCabinets = new Set();
let boxes = 0;
let confirmed = 0;
let pending = 0;

for (const cabinet of cabinets) {
  if (seenCabinets.has(cabinet.id)) {
    throw new Error('Duplicate cabinet id: ' + cabinet.id);
  }
  seenCabinets.add(cabinet.id);
  const seenBoxes = new Set();
  for (const box of cabinet.boxes ?? []) {
    if (seenBoxes.has(box.id)) {
      throw new Error('Duplicate box id in ' + cabinet.code + ': ' + box.id);
    }
    seenBoxes.add(box.id);
    if (!['pending', 'confirmed'].includes(box.status)) {
      throw new Error('Invalid status for ' + cabinet.code + '/' + box.id);
    }
    if (!['internal', 'external'].includes(box.location)) {
      throw new Error('Invalid location for ' + cabinet.code + '/' + box.id);
    }
    boxes += 1;
    if (box.status === 'confirmed') confirmed += 1;
    else pending += 1;
  }
}

const expected = {
  cabinets: 17,
  boxes: 1046,
  confirmed: 711,
  pending: 335,
};
const actual = {
  cabinets: cabinets.length,
  boxes,
  confirmed,
  pending,
};

if (JSON.stringify(actual) !== JSON.stringify(expected)) {
  throw new Error(
    'Seed totals changed. Expected ' +
      JSON.stringify(expected) +
      ', got ' +
      JSON.stringify(actual),
  );
}

console.log(JSON.stringify(actual, null, 2));
