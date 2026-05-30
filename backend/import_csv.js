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

    // 1차: 이름으로 매칭
    let found = await pool.query(
      'SELECT id FROM bakeries WHERE name = $1',
      [name]
    );

    // 2차: 좌표로 매칭 (반경 50m 이내)
    if (found.rows.length === 0 && row.latitude && row.longitude) {
      const lat = parseFloat(row.latitude);
      const lon = parseFloat(row.longitude);
      found = await pool.query(
        `SELECT id, name FROM bakeries
         WHERE (6371000 * acos(LEAST(1.0,
           cos(radians($1)) * cos(radians(latitude)) * cos(radians(longitude) - radians($2))
           + sin(radians($1)) * sin(radians(latitude))
         ))) < 50
         ORDER BY (6371000 * acos(LEAST(1.0,
           cos(radians($1)) * cos(radians(latitude)) * cos(radians(longitude) - radians($2))
           + sin(radians($1)) * sin(radians(latitude))
         ))) ASC
         LIMIT 1`,
        [lat, lon]
      );
      if (found.rows.length > 0) {
        console.log(`🔍 좌표매칭: "${name}" → "${found.rows[0].name}"`);
      }
    }

    if (found.rows.length === 0) {
      // DB에 없으면 CSV 데이터로 신규 INSERT
      const lat = parseFloat(row.latitude);
      const lon = parseFloat(row.longitude);
      if (!lat || !lon) { notFound.push(name); continue; }

      await pool.query(
        `INSERT INTO bakeries (name, address, latitude, longitude, phone_number, opening_hours, amenities, special_menu, google_place_id)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
        [name, row.address || null, lat, lon, phoneNumber, openingHours, amenities, specialMenu, `csv_${name.replace(/\s/g, '_')}`]
      );
      updated++;
      console.log(`➕ 추가: ${name}`);
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
      [specialMenu, amenities, openingHours, phoneNumber, found.rows[0].id]
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
