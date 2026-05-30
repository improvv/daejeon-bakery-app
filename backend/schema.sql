-- 빵집 테이블
CREATE TABLE IF NOT EXISTS bakeries (
  id                SERIAL PRIMARY KEY,
  google_place_id   TEXT UNIQUE NOT NULL,
  name              TEXT NOT NULL,
  address           TEXT,
  latitude          DOUBLE PRECISION NOT NULL,
  longitude         DOUBLE PRECISION NOT NULL,
  phone_number      TEXT,
  rating            NUMERIC(2, 1),
  opening_hours     TEXT[],
  photo_reference   TEXT,
  description       TEXT,
  amenities         TEXT[],
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW()
);

-- 유저 테이블
CREATE TABLE IF NOT EXISTS users (
  id                SERIAL PRIMARY KEY,
  nickname          TEXT NOT NULL,
  email             TEXT UNIQUE NOT NULL,
  profile_image_url TEXT,
  created_at        TIMESTAMPTZ DEFAULT NOW()
);

-- 즐겨찾기 테이블
CREATE TABLE IF NOT EXISTS favorites (
  id         SERIAL PRIMARY KEY,
  user_id    INTEGER REFERENCES users(id) ON DELETE CASCADE,
  bakery_id  INTEGER REFERENCES bakeries(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, bakery_id)
);

-- 리뷰 테이블
CREATE TABLE IF NOT EXISTS reviews (
  id          SERIAL PRIMARY KEY,
  bakery_id   INTEGER REFERENCES bakeries(id) ON DELETE CASCADE,
  user_id     INTEGER REFERENCES users(id) ON DELETE CASCADE,
  rating      INTEGER CHECK (rating BETWEEN 1 AND 5),
  content     TEXT,
  image_urls  TEXT[],
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 검색 기록 테이블
CREATE TABLE IF NOT EXISTS search_history (
  id          SERIAL PRIMARY KEY,
  user_id     INTEGER REFERENCES users(id) ON DELETE CASCADE,
  keyword     TEXT NOT NULL,
  searched_at TIMESTAMPTZ DEFAULT NOW()
);

-- 거리 계산용 인덱스 (위도/경도)
CREATE INDEX IF NOT EXISTS idx_bakeries_location ON bakeries (latitude, longitude);
