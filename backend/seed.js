require('dotenv').config();
const dns = require('dns');
dns.setDefaultResultOrder('ipv4first');
const { Pool } = require('pg');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const GOOGLE_API_KEY = process.env.GOOGLE_PLACES_API_KEY;

const FIELD_MASK = [
  'places.id',
  'places.displayName',
  'places.formattedAddress',
  'places.location',
  'places.internationalPhoneNumber',
  'places.rating',
  'places.regularOpeningHours',
  'places.photos',
  'nextPageToken',
].join(',');

async function fetchBakeries(pageToken = null) {
  const body = {
    textQuery: '대전 베이커리 빵집',
    languageCode: 'ko',
    maxResultCount: 20,
    locationBias: {
      circle: {
        center: { latitude: 36.3504, longitude: 127.3845 },
        radius: 15000,
      },
    },
  };
  if (pageToken) body.pageToken = pageToken;

  const res = await fetch('https://places.googleapis.com/v1/places:searchText', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': GOOGLE_API_KEY,
      'X-Goog-FieldMask': FIELD_MASK,
    },
    body: JSON.stringify(body),
  });
  return res.json();
}

async function saveBakery(place) {
  const photoRef = place.photos?.[0]?.name ?? null;
  const hours = place.regularOpeningHours?.weekdayDescriptions ?? null;

  await pool.query(
    `INSERT INTO bakeries
      (google_place_id, name, address, latitude, longitude, phone_number, rating, opening_hours, photo_reference)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
     ON CONFLICT (google_place_id) DO UPDATE SET
       name = EXCLUDED.name,
       address = EXCLUDED.address,
       phone_number = EXCLUDED.phone_number,
       rating = EXCLUDED.rating,
       opening_hours = EXCLUDED.opening_hours,
       photo_reference = EXCLUDED.photo_reference,
       updated_at = NOW()`,
    [
      place.id,
      place.displayName?.text,
      place.formattedAddress,
      place.location.latitude,
      place.location.longitude,
      place.internationalPhoneNumber ?? null,
      place.rating ?? null,
      hours,
      photoRef,
    ]
  );
}

async function run() {
  console.log('대전 빵집 데이터 수집 시작...');
  let pageToken = null;
  let totalSaved = 0;

  do {
    const data = await fetchBakeries(pageToken);

    if (data.error) {
      console.error('Google API 오류:', data.error.message);
      break;
    }

    for (const place of data.places ?? []) {
      try {
        await saveBakery(place);
        console.log(`저장 완료: ${place.displayName?.text}`);
        totalSaved++;
      } catch (err) {
        console.error(`저장 실패: ${place.displayName?.text}`, err.message);
      }
    }

    pageToken = data.nextPageToken ?? null;
    if (pageToken) await new Promise(r => setTimeout(r, 2000));
  } while (pageToken);

  console.log(`\n완료! 총 ${totalSaved}개 빵집 저장됨`);
  await pool.end();
}

run().catch(console.error);
