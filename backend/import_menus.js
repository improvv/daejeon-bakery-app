require('dotenv').config();
const dns = require('dns');
dns.setDefaultResultOrder('ipv4first');
const fs = require('fs');
const { Pool } = require('pg');
const pool = new Pool({ connectionString: process.env.DATABASE_URL });

const CSV_PATH = 'C:\\Users\\phjtw\\OneDrive\\Desktop\\bakery_menus.csv';

function parseCSVLine(line) {
  const result = [];
  let current = '';
  let inQuotes = false;
  for (const ch of line) {
    if (ch === '"') { inQuotes = !inQuotes; }
    else if (ch === ',' && !inQuotes) { result.push(current); current = ''; }
    else { current += ch; }
  }
  result.push(current);
  return result;
}

async function run() {
  const content = fs.readFileSync(CSV_PATH, 'utf-8').replace(/^﻿/, '');
  const lines = content.split(/\r?\n/).filter(l => l.trim());
  const headers = parseCSVLine(lines[0]).map(h => h.trim());

  let updated = 0;
  const notFound = [];

  for (const line of lines.slice(1)) {
    const values = parseCSVLine(line);
    const row = Object.fromEntries(headers.map((h, i) => [h, (values[i] ?? '').trim()]));

    const name = row.name?.trim();
    const menus = row.menus?.trim();
    if (!name || !menus) continue;

    const found = await pool.query('SELECT id FROM bakeries WHERE name = $1', [name]);
    if (found.rows.length === 0) {
      notFound.push(name);
      continue;
    }

    await pool.query(
      'UPDATE bakeries SET special_menu = $1, updated_at = NOW() WHERE id = $2',
      [menus, found.rows[0].id]
    );
    updated++;
    console.log(`✅ ${name}: ${menus}`);
  }

  console.log(`\n완료: ${updated}개 업데이트`);
  if (notFound.length > 0) {
    console.log(`\n❌ 못 찾은 빵집 (${notFound.length}개):`);
    notFound.forEach(n => console.log(`  - ${n}`));
  }

  await pool.end();
}

run().catch(console.error);
