require('dotenv').config();
const dns = require('dns');
dns.setDefaultResultOrder('ipv4first');
const { Pool } = require('pg');
const pool = new Pool({ connectionString: process.env.DATABASE_URL });

async function run() {
  await pool.query(`DROP TABLE IF EXISTS reviews`);
  await pool.query(`
    CREATE TABLE reviews (
      id         SERIAL PRIMARY KEY,
      bakery_id  INTEGER NOT NULL REFERENCES bakeries(id) ON DELETE CASCADE,
      nickname   VARCHAR(50) NOT NULL,
      rating     DECIMAL(2,1) NOT NULL CHECK (rating >= 1 AND rating <= 5),
      content    TEXT NOT NULL,
      image_data TEXT,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    )
  `);
  console.log('완료: reviews 테이블 재생성됨');
  await pool.end();
}

run().catch(console.error);
