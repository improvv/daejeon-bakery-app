require('dotenv').config();
const dns = require('dns');
dns.setDefaultResultOrder('ipv4first');
const { Pool } = require('pg');
const pool = new Pool({ connectionString: process.env.DATABASE_URL });

async function run() {
  console.log('마이그레이션 시작...');
  await pool.query(`ALTER TABLE bakeries ADD COLUMN IF NOT EXISTS special_menu TEXT`);
  console.log('완료: special_menu 컬럼 추가됨');
  await pool.end();
}

run().catch(console.error);
