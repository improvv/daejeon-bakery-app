require('dotenv').config();
const dns = require('dns');
dns.setDefaultResultOrder('ipv4first');
const fs = require('fs');
const { Pool } = require('pg');
const pool = new Pool({ connectionString: process.env.DATABASE_URL });

const CSV_PATH = 'C:\\Users\\phjtw\\OneDrive\\Desktop\\bakeries_with_location.csv';

function parseCSVLine(line) {
  const result = [];
  let current = '';
  let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (ch === '"') {
      inQuotes = !inQuotes;
    } else if (ch === ',' && !inQuotes) {
      result.push(current);
      current = '';
    } else {
      current += ch;
    }
  }
  result.push(current);
  return result;
}

function parseCSV(content) {
  // BOM 제거
  const cleaned = content.replace(/^﻿/, '');
  const lines = cleaned.split(/\r?\n/);
  const headers = parseCSVLine(lines[0]).map(h => h.trim());
  return lines.slice(1)
    .filter(l => l.trim())
    .map(line => {
      const values = parseCSVLine(line);
      return Object.fromEntries(headers.map((h, i) => [h, (values[i] ?? '').trim()]));
    });
}

async function run() {
  const content = fs.readFileSync(CSV_PATH, 'utf-8');
  const rows = parseCSV(content);

  let updated = 0;
  const notFound = [];

  for (const row of rows) {
    const name = row.name?.trim();
    if (!name) continue;

    // amenities: "PARKING | PACKING | WIFI" → ['PARKING', 'PACKING', 'WIFI']
    const amenities = row.amenities
      ? row.amenities.split('|').map(a => a.trim()).filter(Boolean)
      : [];

    // opening_hours: 단일 문자열을 배열로 저장
    const openingHours = row.businessHours ? [row.businessHours.trim()] : null;

    // special_menu: 그대로 저장
    const specialMenu = row.representativeMenus?.trim() || null;

    // phone_number
    const phoneNumber = row.phoneNumber?.trim() === '-' ? null : row.phoneNumber?.trim() || null;

    const found = await pool.query(
      'SELECT id FROM bakeries WHERE name = $1',
      [name]
    );

    if (found.rows.length === 0) {
      notFound.push(name);
      continue;
    }

    await pool.query(
      `UPDATE bakeries SET
        special_menu  = $1,
        amenities     = $2,
        opening_hours = $3,
        phone_number  = COALESCE(phone_number, $4),
        updated_at    = NOW()
       WHERE id = $5`,
      [specialMenu, amenities, JSON.stringify(openingHours), phoneNumber, found.rows[0].id]
    );
    updated++;
    console.log(`✅ ${name}`);
  }

  console.log(`\n완료: ${updated}개 업데이트`);
  if (notFound.length > 0) {
    console.log(`\n❌ DB에서 못 찾은 빵집 (${notFound.length}개):`);
    notFound.forEach(n => console.log(`  - ${n}`));
  }

  await pool.end();
}

run().catch(console.error);
