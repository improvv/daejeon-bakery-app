require('dotenv').config();
const dns = require('dns');
dns.setDefaultResultOrder('ipv4first');
const fs = require('fs');
const iconv = require('iconv-lite');
const { Pool } = require('pg');
const pool = new Pool({ connectionString: process.env.DATABASE_URL });

// 실행: node import_final_csv.js [CSV_파일_경로] [인코딩]
// 예)  node import_final_csv.js "C:\Users\phjtw\OneDrive\Desktop\bakeries_final.csv" EUC-KR
//      node import_final_csv.js "C:\Users\phjtw\OneDrive\Desktop\bakeries_final.csv" utf8
const CSV_PATH = process.argv[2] || 'C:\\Users\\phjtw\\OneDrive\\Desktop\\bakeries_final.csv';
const ENCODING  = process.argv[3] || 'auto'; // auto: UTF-8 BOM이면 UTF-8, 아니면 EUC-KR

function parseCSVLine(line) {
  const result = [];
  let current = '';
  let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (ch === '"') {
      if (inQuotes && line[i + 1] === '"') {
        current += '"';
        i++;
      } else {
        inQuotes = !inQuotes;
      }
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

function parseJsonArray(value) {
  if (!value) return null;
  try {
    const parsed = JSON.parse(value);
    return Array.isArray(parsed) ? parsed : null;
  } catch {
    return null;
  }
}

async function run() {
  if (!fs.existsSync(CSV_PATH)) {
    console.error(`❌ 파일을 찾을 수 없습니다: ${CSV_PATH}`);
    console.error('사용법: node import_final_csv.js "파일경로"');
    process.exit(1);
  }

  const rawBuffer = fs.readFileSync(CSV_PATH);
  let encoding = ENCODING;
  if (encoding === 'auto') {
    // UTF-8 BOM(EF BB BF)이 있으면 UTF-8, 없으면 EUC-KR로 처리
    encoding = (rawBuffer[0] === 0xEF && rawBuffer[1] === 0xBB && rawBuffer[2] === 0xBF)
      ? 'utf-8'
      : 'EUC-KR';
  }
  console.log(`🔤 인코딩: ${encoding}`);
  const content = iconv.decode(rawBuffer, encoding);
  const rows = parseCSV(content);
  console.log(`📄 CSV 행 수: ${rows.length}`);

  let upserted = 0;
  let skipped = 0;

  for (const row of rows) {
    const id = parseInt(row.id);
    if (isNaN(id)) { skipped++; continue; }

    const lat = parseFloat(row.latitude);
    const lon = parseFloat(row.longitude);
    if (isNaN(lat) || isNaN(lon)) {
      console.log(`⚠️  [${id}] ${row.name}: 좌표 없음 — 건너뜀`);
      skipped++;
      continue;
    }

    const rating = row.rating !== '' ? parseFloat(row.rating) : null;
    const openingHours = parseJsonArray(row.opening_hours);
    const amenities = parseJsonArray(row.amenities);
    const photoRef = row.photo_reference || null;
    const description = row.description || null;
    const specialMenu = row.special_menu || null;
    const phoneNumber = row.phone_number || null;
    const googlePlaceId = row.google_place_id || null;

    await pool.query(
      `INSERT INTO bakeries
         (id, google_place_id, name, address, latitude, longitude,
          phone_number, rating, opening_hours, photo_reference,
          description, amenities, special_menu, created_at, updated_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,
               COALESCE($14::timestamptz, NOW()), NOW())
       ON CONFLICT (id) DO UPDATE SET
         google_place_id = EXCLUDED.google_place_id,
         name            = EXCLUDED.name,
         address         = EXCLUDED.address,
         latitude        = EXCLUDED.latitude,
         longitude       = EXCLUDED.longitude,
         phone_number    = EXCLUDED.phone_number,
         rating          = EXCLUDED.rating,
         opening_hours   = EXCLUDED.opening_hours,
         photo_reference = EXCLUDED.photo_reference,
         description     = EXCLUDED.description,
         amenities       = EXCLUDED.amenities,
         special_menu    = EXCLUDED.special_menu,
         updated_at      = NOW()`,
      [
        id, googlePlaceId, row.name, row.address, lat, lon,
        phoneNumber, rating, openingHours, photoRef,
        description, amenities, specialMenu,
        row.created_at || null,
      ]
    );

    upserted++;
    console.log(`✅ [${id}] ${row.name}`);
  }

  console.log(`\n완료: ${upserted}개 처리, ${skipped}개 건너뜀`);
  await pool.end();
}

run().catch(err => {
  console.error('오류:', err.message);
  pool.end();
  process.exit(1);
});
