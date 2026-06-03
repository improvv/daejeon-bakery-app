require('dotenv').config();
const dns = require('dns');
dns.setDefaultResultOrder('ipv4first');
const https = require('https');
const { Pool } = require('pg');
const pool = new Pool({ connectionString: process.env.DATABASE_URL });

const express = require('express');
const cors = require('cors');
const swaggerUi = require('swagger-ui-express');
const swaggerJsdoc = require('swagger-jsdoc');

const app = express();
const PORT = process.env.PORT || 3000;

function decodePolyline(encoded) {
  const points = [];
  let index = 0, lat = 0, lng = 0;
  while (index < encoded.length) {
    let b, shift = 0, result = 0;
    do { b = encoded.charCodeAt(index++) - 63; result |= (b & 0x1f) << shift; shift += 5; } while (b >= 0x20);
    lat += (result & 1) ? ~(result >> 1) : (result >> 1);
    shift = 0; result = 0;
    do { b = encoded.charCodeAt(index++) - 63; result |= (b & 0x1f) << shift; shift += 5; } while (b >= 0x20);
    lng += (result & 1) ? ~(result >> 1) : (result >> 1);
    points.push({ lat: lat / 1e5, lng: lng / 1e5 });
  }
  return points;
}

// Google Places 요일 배열 인덱스: 0=월, 1=화, ..., 6=일
function todayIndex() {
  const day = new Date(new Date().toLocaleString('en-US', { timeZone: 'Asia/Seoul' })).getDay();
  return day === 0 ? 6 : day - 1;
}

app.use(cors());
app.use(express.json());

// 0-1. 공통 응답 포맷 래퍼 함수 [cite: 4-11]
const responseWrapper = (code, message, data = null) => {
  return {
    code: code,
    message: message,
    data: data
  };
};

// Swagger 기본 설정
const options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: '대전 빵집 지도 APP API',
      version: '1.0.0',
      description: '대전 빵집 지도 앱 백엔드 API 명세서입니다.',
    },
    components: {
      schemas: {
        ErrorResponse: {
          type: 'object',
          properties: {
            code: {
              type: 'string',
              description: '에러 식별 코드'
            },
            message: {
              type: 'string',
              description: '에러 상세 메시지'
            },
            data: {
              type: 'object',
              nullable: true,
              example: null
            }
          }
        }
      }
    }
  },
  apis: ['./app.js'],
};

const swaggerSpec = swaggerJsdoc(options);
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

// JSON 스펙 직접 제공
app.get('/swagger.json', (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.send(swaggerSpec);
});


/**
 * @swagger
 * /api/v1/bakeries:
 *   get:
 *     summary: 1-1. 빵집 리스트 조회 (지도/홈/검색)
 *     description: 지도 화면의 핀, 바텀 시트 리스트, 검색 결과에 사용되는 통합 API입니다.
 *     tags: [Bakery]
 *     parameters:
 *       - in: query
 *         name: lat
 *         required: true
 *         schema:
 *           type: number
 *           format: double
 *         description: 사용자 현재 위도
 *         example: 36.3504
 *       - in: query
 *         name: lon
 *         required: true
 *         schema:
 *           type: number
 *           format: double
 *         description: 사용자 현재 경도
 *         example: 127.3845
 *       - in: query
 *         name: radius
 *         schema:
 *           type: number
 *         description: 검색 반경 (km, 기본 2.0)
 *         example: 2.0
 *       - in: query
 *         name: keyword
 *         schema:
 *           type: string
 *         description: 검색어(상호명, 메뉴 등)
 *         example: 성심당
 *       - in: query
 *         name: sort
 *         schema:
 *           type: string
 *           enum: [DISTANCE, RATING, REVIEW, LATEST]
 *         description: 정렬 (DISTANCE: 가까운 순, RATING: 별점 높은 순, REVIEW: 리뷰 많은 순, LATEST: 최신 순)
 *         example: DISTANCE
 *       - in: query
 *         name: filter
 *         schema:
 *           type: string
 *         description: 지역 필터(ALL, DONG GU, SEO GU...)
 *     responses:
 *       200:
 *         description: 성공
 *       400:
 *         description: 잘못된 요청파라미터
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               code: ERROR_MISSING_PARAM
 *               message: 위도(lat)와 경도(lon)는 필수입니다.
 *               data: null
 */
app.get('/api/v1/bakeries', async (req, res) => {
  const { lat, lon, radius = 10.0, keyword, sort = 'DISTANCE', district } = req.query;

  if (!lat || !lon) {
    return res.status(400).json(responseWrapper("ERROR_MISSING_PARAM", "위도(lat)와 경도(lon)는 필수입니다."));
  }

  // 앱 첫 로드 시(검색 아닐 때)만 방문 기록
  if (!keyword) {
    pool.query('INSERT INTO visits (visited_at) VALUES (NOW())').catch(() => {});
  }

  const userLat = parseFloat(lat);
  const userLon = parseFloat(lon);
  const radiusKm = parseFloat(radius);

  const distanceExpr = `(6371 * acos(LEAST(1.0, cos(radians($1)) * cos(radians(latitude)) * cos(radians(longitude) - radians($2)) + sin(radians($1)) * sin(radians(latitude)))))`;

  const params = [userLat, userLon, radiusKm];
  let paramIndex = 4;
  let whereClause = `WHERE ${distanceExpr} <= $3`;

  if (keyword) {
    const kw = `%${keyword}%`;
    whereClause += ` AND (name ILIKE $${paramIndex} OR COALESCE(special_menu, '') ILIKE $${paramIndex + 1})`;
    params.push(kw, kw);
    paramIndex += 2;
  }

  if (district && district !== '전체') {
    whereClause += ` AND address ILIKE $${paramIndex}`;
    params.push(`%${district}%`);
    paramIndex++;
  }

  const orderClause = sort === 'RATING' ? 'ORDER BY rating DESC NULLS LAST'
    : sort === 'LATEST' ? 'ORDER BY created_at DESC'
    : `ORDER BY ${distanceExpr} ASC`;

  try {
    const result = await pool.query(
      `SELECT id, name, address, latitude, longitude, rating, opening_hours, photo_reference, description, amenities, special_menu,
              ${distanceExpr} AS distance
       FROM bakeries ${whereClause} ${orderClause}`,
      params
    );

    const bakeries = result.rows.map(row => ({
      id: row.id,
      name: row.name,
      address: row.address,
      imageUrls: row.photo_reference
        ? [`https://places.googleapis.com/v1/${row.photo_reference}/media?maxWidthPx=800&key=${process.env.GOOGLE_PLACES_API_KEY}`]
        : [],
      latitude: row.latitude,
      longitude: row.longitude,
      distance: Math.round(row.distance * 100) / 100,
      rating: row.rating ? parseFloat(row.rating) : null,
      reviewCount: 0,
      isFavorite: false,
      openingHours: row.opening_hours?.[todayIndex()] ?? row.opening_hours?.[0] ?? null,
      amenities: row.amenities ?? [],
      description: row.description ?? null,
      specialMenu: row.special_menu ?? null,
    }));

    res.json(responseWrapper("SUCCESS", "요청이 성공하였습니다.", { totalCount: bakeries.length, bakeries }));
  } catch (err) {
    console.error(err);
    res.status(500).json(responseWrapper("ERROR_INTERNAL", "서버 오류가 발생했습니다."));
  }
});


/**
 * @swagger
 * /api/v1/bakeries/{bakeryId}:
 *   get:
 *     summary: 1-2. 빵집 상세 정보 조회
 *     description: 지도 핀 클릭 또는 리스트 아이템 클릭 시 진입하는 상세 화면 데이터입니다.
 *     tags: [Bakery]
 *     parameters:
 *       - in: path
 *         name: bakeryId
 *         required: true
 *         schema:
 *           type: integer
 *         description: 빵집 고유 ID
 *         example: 120
 *     responses:
 *       200:
 *         description: 성공
 *       400:
 *         description: 잘못된 파라미터 타입
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               code: ERROR_INVALID_PARAM
 *               message: 유효하지 않은 빵집 ID입니다.
 *               data: null
 *       404:
 *         description: 빵집을 찾을 수 없음
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               code: ERROR_NOT_FOUND
 *               message: 존재하지 않는 빵집입니다.
 *               data: null
 */
app.get('/api/v1/bakeries/:bakeryId', async (req, res) => {
  const bakeryId = parseInt(req.params.bakeryId, 10);

  if (isNaN(bakeryId)) {
    return res.status(400).json(responseWrapper("ERROR_INVALID_PARAM", "유효하지 않은 빵집 ID입니다."));
  }

  try {
    const result = await pool.query('SELECT * FROM bakeries WHERE id = $1', [bakeryId]);

    if (result.rows.length === 0) {
      return res.status(404).json(responseWrapper("ERROR_NOT_FOUND", "존재하지 않는 빵집입니다."));
    }

    const row = result.rows[0];
    const data = {
      id: row.id,
      name: row.name,
      address: row.address,
      imageUrls: row.photo_reference
        ? [`https://places.googleapis.com/v1/${row.photo_reference}/media?maxWidthPx=800&key=${process.env.GOOGLE_PLACES_API_KEY}`]
        : [],
      latitude: row.latitude,
      longitude: row.longitude,
      phoneNumber: row.phone_number ?? null,
      description: row.description ?? null,
      rating: row.rating ? parseFloat(row.rating) : null,
      reviewCount: 0,
      isFavorite: false,
      openingHours: row.opening_hours?.[todayIndex()] ?? row.opening_hours?.[0] ?? null,
      openingHoursAll: row.opening_hours ?? null,
      amenities: row.amenities ?? [],
      specialMenu: row.special_menu ?? null,
    };

    res.json(responseWrapper("SUCCESS", "상세 정보 조회가 성공하였습니다.", data));
  } catch (err) {
    console.error(err);
    res.status(500).json(responseWrapper("ERROR_INTERNAL", "서버 오류가 발생했습니다."));
  }
});

function fetchJson(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (resp) => {
      let body = '';
      resp.on('data', chunk => body += chunk);
      resp.on('end', () => { try { resolve(JSON.parse(body)); } catch (e) { reject(e); } });
    }).on('error', reject);
  });
}

function fmtDist(meters) {
  return meters < 1000 ? `${Math.round(meters)}m` : `${(meters / 1000).toFixed(1)}km`;
}

function fmtDur(seconds) {
  const mins = Math.round(seconds / 60);
  if (mins < 60) return `${mins}분`;
  const h = Math.floor(mins / 60), m = mins % 60;
  return m > 0 ? `${h}시간 ${m}분` : `${h}시간`;
}

function osrmManeuver(maneuver) {
  const { type, modifier } = maneuver;
  if (type === 'depart' || type === 'arrive') return 'straight';
  if (type === 'roundabout' || type === 'rotary') return modifier?.includes('left') ? 'roundabout-left' : 'roundabout-right';
  if (type === 'merge') return 'merge';
  if (type === 'on ramp') return modifier?.includes('left') ? 'ramp-left' : 'ramp-right';
  if (modifier === 'left') return 'turn-left';
  if (modifier === 'right') return 'turn-right';
  if (modifier === 'slight left') return 'turn-slight-left';
  if (modifier === 'slight right') return 'turn-slight-right';
  if (modifier === 'sharp left') return 'turn-sharp-left';
  if (modifier === 'sharp right') return 'turn-sharp-right';
  if (modifier === 'uturn') return 'uturn-left';
  return 'straight';
}

function osrmInstruction(step) {
  const { type, modifier } = step.maneuver;
  const road = step.name ? ` (${step.name})` : '';
  if (type === 'depart') return `출발${road}`;
  if (type === 'arrive') return '목적지 도착';
  const dir = { left:'좌회전', right:'우회전', 'slight left':'좌측으로', 'slight right':'우측으로',
    'sharp left':'급좌회전', 'sharp right':'급우회전', uturn:'U턴', straight:'직진' }[modifier] || '직진';
  return `${dir}${road}`;
}

app.get('/api/v1/route', async (req, res) => {
  const { originLat, originLon, destLat, destLon, mode = 'walking' } = req.query;
  if (!originLat || !originLon || !destLat || !destLon) {
    return res.status(400).json(responseWrapper('ERROR_MISSING_PARAM', '파라미터가 부족합니다.'));
  }
  const travelMode = ['walking', 'driving', 'transit'].includes(mode) ? mode : 'walking';

  try {
    // 대중교통 → Google Directions API
    if (travelMode === 'transit') {
      const url = `https://maps.googleapis.com/maps/api/directions/json?origin=${originLat},${originLon}&destination=${destLat},${destLon}&mode=transit&language=ko&key=${process.env.GOOGLE_PLACES_API_KEY}`;
      const data = await fetchJson(url);
      if (data.status !== 'OK' || !data.routes?.length) {
        return res.status(404).json(responseWrapper('ERROR_NOT_FOUND', '경로를 찾을 수 없습니다.'));
      }
      const route = data.routes[0];
      const leg = route.legs[0];
      const steps = leg.steps.map(step => {
        const base = {
          instruction: step.html_instructions.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim(),
          distance: step.distance.text,
          duration: step.duration.text,
          maneuver: step.maneuver || null,
        };
        if (step.transit_details) {
          const td = step.transit_details;
          base.transit = {
            departureStop: td.departure_stop.name,
            arrivalStop: td.arrival_stop.name,
            lineName: td.line.short_name || td.line.name,
            numStops: td.num_stops,
            vehicleType: td.line.vehicle.type,
            headsign: td.headsign,
          };
        }
        return base;
      });
      return res.json(responseWrapper('SUCCESS', '경로 조회 성공', {
        points: decodePolyline(route.overview_polyline.points),
        distance: leg.distance.text,
        duration: leg.duration.text,
        steps,
        transfers: Math.max(0, steps.filter(s => s.transit).length - 1),
      }));
    }

    // 도보/차량 → OSRM (한국 지원)
    const osrmMode = travelMode === 'driving' ? 'driving' : 'foot';
    const url = `https://router.project-osrm.org/route/v1/${osrmMode}/${originLon},${originLat};${destLon},${destLat}?overview=full&steps=true&geometries=polyline`;
    const data = await fetchJson(url);
    if (data.code !== 'Ok' || !data.routes?.length) {
      return res.status(404).json(responseWrapper('ERROR_NOT_FOUND', '경로를 찾을 수 없습니다.'));
    }
    const route = data.routes[0];
    const leg = route.legs[0];
    const steps = leg.steps.map(step => ({
      instruction: osrmInstruction(step),
      distance: fmtDist(step.distance),
      duration: fmtDur(step.duration),
      maneuver: osrmManeuver(step.maneuver),
    }));
    return res.json(responseWrapper('SUCCESS', '경로 조회 성공', {
      points: decodePolyline(route.geometry),
      distance: fmtDist(route.distance),
      duration: fmtDur(route.duration),
      steps,
      transfers: null,
    }));
  } catch (err) {
    console.error(err);
    res.status(500).json(responseWrapper('ERROR_INTERNAL', '서버 오류가 발생했습니다.'));
  }
});

/**
 * @swagger
 * /api/v1/users/search-history:
 *   get:
 *     summary: 2-1. 최근 검색어 조회
 *     description: 검색 화면 진입 시 하단에 노출되는 검색 기록입니다.
 *     tags: [User]
 *     responses:
 *       200:
 *         description: 성공
 */
app.get('/api/v1/users/search-history', (req, res) => {
  const mockData = {
    keywords: [
      {
        id: 55,
        keyword: "케이크",
        searchedAt: "2026-01-26T18:20:00"
      },
      {
        id: 54,
        keyword: "유성구 맛집",
        searchedAt: "2026-01-25T10:00:00"
      }
    ]
  };

  res.json(responseWrapper("SUCCESS", "최근 검색어 조회가 성공하였습니다.", mockData));
});

/**
 * @swagger
 * /api/v1/users/search-history/{historyId}:
 *   delete:
 *     summary: 2-2. 최근 검색어 삭제
 *     description: 검색 기록의 'X' 버튼 클릭 시 특정 기록을 삭제합니다.
 *     tags: [User]
 *     parameters:
 *       - in: path
 *         name: historyId
 *         required: true
 *         schema:
 *           type: integer
 *         description: 검색 기록 고유 ID
 *     responses:
 *       200:
 *         description: 성공
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 code:
 *                   type: string
 *                   example: SUCCESS
 *                 message:
 *                   type: string
 *                   example: 요청이 성공하였습니다.
 *                 data:
 *                   type: object
 *                   nullable: true
 *                   example: null
 *       404:
 *         description: 검색 기록을 찾을 수 없음
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               code: ERROR_NOT_FOUND
 *               message: 존재하지 않는 검색 기록입니다.
 *               data: null
 */
app.delete('/api/v1/users/search-history/:historyId', (req, res) => {
  const historyId = parseInt(req.params.historyId, 10);

  if (isNaN(historyId)) {
    return res.status(400).json(responseWrapper("ERROR_INVALID_PARAM", "유효하지 않은 검색 기록 ID입니다."));
  }

  // 실제 구현에서는 DB에서 해당 historyId 레코드를 삭제

  res.json(responseWrapper("SUCCESS", "최근 검색어 삭제가 성공하였습니다."));
});

/**
 * @swagger
 * /api/v1/bakeries/{bakeryId}/favorite:
 *   post:
 *     summary: 3-1. 즐겨찾기 토글 (추가/취소)
 *     description: 상세 화면 또는 리스트의 '별(하트)' 아이콘 클릭 시 호출합니다. (Auth 필수)
 *     tags: [Bakery]
 *     parameters:
 *       - in: path
 *         name: bakeryId
 *         required: true
 *         schema:
 *           type: integer
 *         description: 빵집 고유 ID
 *         example: 120
 *     responses:
 *       200:
 *         description: 성공
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 code:
 *                   type: string
 *                   example: SUCCESS
 *                 message:
 *                   type: string
 *                   example: 요청이 성공하였습니다.
 *                 data:
 *                   type: object
 *                   properties:
 *                     bakeryId:
 *                       type: integer
 *                       example: 120
 *                     isFavorite:
 *                       type: boolean
 *                       description: true면 찜 등록됨, false면 찜 해제됨
 *                       example: false
 *       400:
 *         description: 잘못된 파라미터 타입
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               code: ERROR_INVALID_PARAM
 *               message: 유효하지 않은 빵집 ID입니다.
 *               data: null
 *       401:
 *         description: 인증되지 않은 사용자
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               code: ERROR_UNAUTHORIZED
 *               message: 로그인이 필요합니다.
 *               data: null
 *       404:
 *         description: 빵집을 찾을 수 없음
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               code: ERROR_NOT_FOUND
 *               message: 존재하지 않는 빵집입니다.
 *               data: null
 */
app.post('/api/v1/bakeries/:bakeryId/favorite', (req, res) => {
  const bakeryId = parseInt(req.params.bakeryId, 10);

  // 문자열 등 잘못된 입력 시 400 테스트
  if (isNaN(bakeryId)) {
    return res.status(400).json(responseWrapper("ERROR_INVALID_PARAM", "유효하지 않은 빵집 ID입니다."));
  }

  // Swagger 테스트 편의를 위해 특정 ID를 입력하면 에러가 뜨도록 분기 처리
  // (실제 구현에서는 Authorization 헤더를 까서 인증 상태를 체크해야 하지만, 현재 테스트가 막히지 않도록 변경)
  if (bakeryId === 401) {
    return res.status(401).json(responseWrapper("ERROR_UNAUTHORIZED", "로그인이 필요합니다."));
  }

  if (bakeryId === 404) {
    return res.status(404).json(responseWrapper("ERROR_NOT_FOUND", "존재하지 않는 빵집입니다."));
  }

  // 위 에러 조건에 걸리지 않는 정상적인 ID(예: 120 등)는 무조건 성공(200) 처리
  const isFavorite = Math.random() < 0.5;

  const mockData = {
    bakeryId: bakeryId,
    isFavorite: isFavorite
  };

  res.json(responseWrapper("SUCCESS", "즐겨찾기 상태가 변경되었습니다.", mockData));
});

/**
 * @swagger
 * /api/v1/users/favorites:
 *   get:
 *     summary: 3-2. 내 즐겨찾기 목록 조회
 *     description: 즐겨찾기 탭에서 내가 찜한 빵집들을 모아봅니다. (Auth 필수)
 *     tags: [User]
 *     parameters:
 *       - in: query
 *         name: lat
 *         schema:
 *           type: number
 *           format: double
 *         description: 사용자 현재 위도 (옵션)
 *         example: 36.3504
 *       - in: query
 *         name: lon
 *         schema:
 *           type: number
 *           format: double
 *         description: 사용자 현재 경도 (옵션)
 *         example: 127.3845
 *       - in: query
 *         name: test
 *         schema:
 *           type: string
 *         description: (테스트용) '401' 입력 시 인증 에러 테스트
 *         example: ""
 *     responses:
 *       200:
 *         description: 성공
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 code:
 *                   type: string
 *                   example: SUCCESS
 *                 message:
 *                   type: string
 *                   example: 요청이 성공하였습니다.
 *                 data:
 *                   type: object
 *                   properties:
 *                     totalCount:
 *                       type: integer
 *                       example: 5
 *                     favorites:
 *                       type: array
 *                       items:
 *                         type: object
 *                         properties:
 *                           id:
 *                             type: integer
 *                             example: 120
 *                           name:
 *                             type: string
 *                             example: 성심당 본점
 *                           thumbnailUrl:
 *                             type: string
 *                             example: https://cdn.bread.com/img/120_main.jpg
 *                           address:
 *                             type: string
 *                             example: 대전광역시 중구 은행동
 *                           rating:
 *                             type: number
 *                             example: 4.8
 *                           reviewCount:
 *                             type: integer
 *                             example: 15234
 *                           distance:
 *                             type: number
 *                             nullable: true
 *                             example: null
 *       401:
 *         description: 인증되지 않은 사용자
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *             example:
 *               code: ERROR_UNAUTHORIZED
 *               message: 로그인이 필요합니다.
 *               data: null
 */
app.get('/api/v1/users/favorites', (req, res) => {
  const { lat, lon, test } = req.query;

  // 테스트 편의성을 위해: test === '401' 파라미터를 넘길 때만 에러 발생
  if (test === '401') {
    return res.status(401).json(responseWrapper("ERROR_UNAUTHORIZED", "로그인이 필요합니다."));
  }

  // 좌표가 넘어오면(lat & lon) 거리(distance)를 계산해주고, 아니면 null 반환
  const hasLocation = lat && lon;

  const mockData = {
    totalCount: 2,
    favorites: [
      {
        id: 120,
        name: "성심당 본점",
        address: "대전광역시 중구 은행동",
        imageUrls: ["https://cdn.bread.com/img/120_main.jpg"],
        latitude: 36.3276,
        longitude: 127.4273,
        rating: 4.8,
        reviewCount: 15234,
        isFavorite: true,
        distance: hasLocation ? 0.35 : null
      },
      {
        id: 121,
        name: "하레하레 갤러리아점",
        address: "대전광역시 서구 둔산동",
        imageUrls: ["https://cdn.bread.com/img/121_main.jpg"],
        latitude: 36.3504,
        longitude: 127.3845,
        rating: 4.6,
        reviewCount: 890,
        isFavorite: true,
        distance: hasLocation ? 0.8 : null
      }
    ]
  };

  res.json(responseWrapper("SUCCESS", "내 즐겨찾기 목록 조회가 성공하였습니다.", mockData));
});

/**
 * @swagger
 * /api/v1/bakeries/{bakeryId}/reviews:
 *   get:
 *     summary: 4-1. 빵집 리뷰 리스트 조회
 *     description: 상세 화면 하단 리뷰 영역 및 리뷰 더보기 화면에서 사용합니다. (Auth 불필요)
 *     tags: [Review]
 *     parameters:
 *       - in: path
 *         name: bakeryId
 *         required: true
 *         schema:
 *           type: integer
 *         description: 빵집 고유 ID
 *         example: 120
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           default: 0
 *         description: 페이지 번호 (0부터 시작, 기본 0)
 *       - in: query
 *         name: size
 *         schema:
 *           type: integer
 *           default: 10
 *         description: 페이지 당 개수 (기본 10)
 *       - in: query
 *         name: sort
 *         schema:
 *           type: string
 *           enum: [LATEST, RATING, REVIEW, DISTANCE]
 *         description: 정렬 (LATEST: 최신순, RATING: 별점 높은 순 등 부록 명세 참고)
 *         example: LATEST
 *     responses:
 *       200:
 *         description: 성공
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *             example:
 *               code: "SUCCESS"
 *               message: "리뷰 목록 조회가 성공하였습니다."
 *               data:
 *                 pagination:
 *                   currentPage: 0
 *                   totalPages: 5
 *                   totalElements: 48
 *                   isLast: false
 *                 reviews:
 *                   - reviewId: 1001
 *                     userInfo:
 *                       userId: 50
 *                       nickname: "빵순이"
 *                       profileImageUrl: "https://cdn.bread.com/face.jpg"
 *                     rating: 5
 *                     content: "대전 오면 무조건 들러야 합니다. 튀소 최고!"
 *                     reviewImages:
 *                       - "https://cdn.bread.com/review1.jpg"
 *                     createdAt: "2026-01-26"
 *                   - reviewId: 1002
 *                     userInfo:
 *                       userId: 33
 *                       nickname: "대전토박이"
 *                       profileImageUrl: null
 *                     rating: 4
 *                     content: "사람이 너무 많아서 별 하나 뺍니다."
 *                     reviewImages: []
 *                     createdAt: "2026-01-25"
 *       400:
 *         description: 잘못된 파라미터 타입
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
app.get('/api/v1/bakeries/:bakeryId/reviews', async (req, res) => {
  const bakeryId = parseInt(req.params.bakeryId, 10);
  if (isNaN(bakeryId)) {
    return res.status(400).json(responseWrapper("ERROR_INVALID_PARAM", "유효하지 않은 빵집 ID입니다."));
  }
  try {
    const result = await pool.query(
      'SELECT * FROM reviews WHERE bakery_id = $1 ORDER BY created_at DESC',
      [bakeryId]
    );
    const reviews = result.rows.map(r => ({
      id: r.id,
      bakeryId: r.bakery_id,
      userName: r.nickname,
      rating: parseFloat(r.rating),
      content: r.content,
      imageUrls: r.image_data ? [r.image_data] : [],
      createdAt: r.created_at.toISOString().slice(0, 10),
    }));
    res.json(responseWrapper("SUCCESS", "리뷰 목록 조회가 성공하였습니다.", { reviews }));
  } catch (err) {
    console.error(err);
    res.status(500).json(responseWrapper("ERROR_INTERNAL", "서버 오류가 발생했습니다."));
  }
});

app.post('/api/v1/bakeries/:bakeryId/reviews', async (req, res) => {
  const bakeryId = parseInt(req.params.bakeryId, 10);
  if (isNaN(bakeryId)) {
    return res.status(400).json(responseWrapper("ERROR_INVALID_PARAM", "유효하지 않은 빵집 ID입니다."));
  }
  const { nickname, rating, content, imageData } = req.body;
  if (!nickname || !rating || !content) {
    return res.status(400).json(responseWrapper("ERROR_MISSING_PARAM", "닉네임, 별점, 후기는 필수입니다."));
  }
  try {
    const result = await pool.query(
      'INSERT INTO reviews (bakery_id, nickname, rating, content, image_data) VALUES ($1,$2,$3,$4,$5) RETURNING id',
      [bakeryId, nickname.trim(), parseFloat(rating), content.trim(), imageData || null]
    );
    // 별점 재계산
    await pool.query(
      'UPDATE bakeries SET rating = (SELECT ROUND(AVG(rating)::numeric, 1) FROM reviews WHERE bakery_id = $1) WHERE id = $1',
      [bakeryId]
    );
    res.json(responseWrapper("SUCCESS", "리뷰가 등록되었습니다.", { id: result.rows[0].id }));
  } catch (err) {
    console.error(err);
    res.status(500).json(responseWrapper("ERROR_INTERNAL", "서버 오류가 발생했습니다."));
  }
});

app.delete('/api/v1/bakeries/:bakeryId/reviews/:reviewId', async (req, res) => {
  const bakeryId = parseInt(req.params.bakeryId, 10);
  const reviewId = parseInt(req.params.reviewId, 10);
  if (isNaN(bakeryId) || isNaN(reviewId)) {
    return res.status(400).json(responseWrapper("ERROR_INVALID_PARAM", "유효하지 않은 ID입니다."));
  }
  try {
    await pool.query('DELETE FROM reviews WHERE id = $1 AND bakery_id = $2', [reviewId, bakeryId]);
    // 별점 재계산 (리뷰 없으면 null)
    await pool.query(
      'UPDATE bakeries SET rating = (SELECT ROUND(AVG(rating)::numeric, 1) FROM reviews WHERE bakery_id = $1) WHERE id = $1',
      [bakeryId]
    );
    res.json(responseWrapper("SUCCESS", "리뷰가 삭제되었습니다.", null));
  } catch (err) {
    console.error(err);
    res.status(500).json(responseWrapper("ERROR_INTERNAL", "서버 오류가 발생했습니다."));
  }
});

// 관리자 - 빵집 전체 목록 조회
app.get('/api/v1/admin/bakeries', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, name, address, description, amenities, special_menu FROM bakeries ORDER BY id'
    );
    const bakeries = result.rows.map(r => ({
      id: r.id,
      name: r.name,
      address: r.address,
      description: r.description ?? null,
      amenities: r.amenities ?? [],
      specialMenu: r.special_menu ?? null,
    }));
    res.json(responseWrapper("SUCCESS", "조회 성공", { bakeries }));
  } catch (err) {
    console.error(err);
    res.status(500).json(responseWrapper("ERROR_INTERNAL", "서버 오류가 발생했습니다."));
  }
});

// 관리자 - 빵집 정보 수정
app.patch('/api/v1/admin/bakeries/:bakeryId', async (req, res) => {
  const bakeryId = parseInt(req.params.bakeryId, 10);
  if (isNaN(bakeryId)) {
    return res.status(400).json(responseWrapper("ERROR_INVALID_PARAM", "유효하지 않은 빵집 ID입니다."));
  }

  const { description, specialMenu, amenities } = req.body;
  const updates = [];
  const params = [];
  let idx = 1;

  if (description !== undefined) { updates.push(`description = $${idx++}`); params.push(description || null); }
  if (specialMenu !== undefined) { updates.push(`special_menu = $${idx++}`); params.push(specialMenu || null); }
  if (amenities !== undefined) { updates.push(`amenities = $${idx++}`); params.push(amenities); }

  if (updates.length === 0) {
    return res.status(400).json(responseWrapper("ERROR_MISSING_PARAM", "수정할 항목이 없습니다."));
  }

  params.push(bakeryId);
  try {
    await pool.query(
      `UPDATE bakeries SET ${updates.join(', ')}, updated_at = NOW() WHERE id = $${idx}`,
      params
    );
    res.json(responseWrapper("SUCCESS", "수정되었습니다.", null));
  } catch (err) {
    console.error(err);
    res.status(500).json(responseWrapper("ERROR_INTERNAL", "서버 오류가 발생했습니다."));
  }
});

app.get('/api/v1/gemini-models', async (req, res) => {
  try {
    const data = await new Promise((resolve, reject) => {
      https.get(`https://generativelanguage.googleapis.com/v1beta/models?key=${process.env.GEMINI_API_KEY}`, (resp) => {
        let body = '';
        resp.on('data', chunk => body += chunk);
        resp.on('end', () => { try { resolve(JSON.parse(body)); } catch (e) { reject(e); } });
      }).on('error', reject);
    });
    const models = (data.models || []).map(m => m.name);
    res.json({ models });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/v1/chat', async (req, res) => {
  const { message, history = [] } = req.body;
  if (!message?.trim()) {
    return res.status(400).json(responseWrapper('ERROR_MISSING_PARAM', '메시지를 입력해주세요.'));
  }

  try {
    const result = await pool.query(
      `SELECT id, name, address, special_menu, rating
       FROM bakeries ORDER BY rating DESC NULLS LAST LIMIT 80`
    );

    const bakeryList = result.rows.map(b => {
      const district = b.address.split(' ').slice(2, 4).join(' ');
      const menu = b.special_menu ? ` | 메뉴: ${b.special_menu}` : ' | 메뉴정보없음';
      const rating = b.rating ? ` | 별점: ${b.rating}` : '';
      return `[ID:${b.id}] ${b.name} (${district})${menu}${rating}`;
    }).join('\n');

    const systemPrompt = `당신은 대전 빵집 추천 전문가 AI입니다. 아래 빵집 목록만을 기반으로 추천하세요.

[빵집 목록]
${bakeryList}

[규칙]
- 사용자 취향과 메뉴가 잘 맞는 빵집 1~3개 추천
- 별점 높은 곳 우선 (단, 메뉴 일치가 더 중요)
- 반드시 아래 JSON 형식으로만 응답 (다른 텍스트 없이)
- 추천할 빵집이 없으면 recommendations를 빈 배열로
{"message":"친근하고 구체적인 추천 설명 (2~3문장)","recommendations":[{"id":숫자,"name":"빵집이름","reason":"메뉴와 취향이 맞는 구체적인 이유"}]}`;

    const contents = [
      ...history.map(h => ({
        role: h.isUser ? 'user' : 'model',
        parts: [{ text: h.text }],
      })),
      { role: 'user', parts: [{ text: message.trim() }] },
    ];

    const body = JSON.stringify({
      systemInstruction: { parts: [{ text: systemPrompt }] },
      contents,
      generationConfig: { temperature: 0.5, maxOutputTokens: 1024 },
    });

    const callGemini = (model) => new Promise((resolve, reject) => {
      const options = {
        hostname: 'generativelanguage.googleapis.com',
        path: `/v1beta/models/${model}:generateContent?key=${process.env.GEMINI_API_KEY}`,
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) },
      };
      const req = https.request(options, (resp) => {
        let data = '';
        resp.on('data', chunk => data += chunk);
        resp.on('end', () => { try { resolve(JSON.parse(data)); } catch (e) { reject(e); } });
      });
      req.on('error', reject);
      req.write(body);
      req.end();
    });

    const models = ['gemini-2.5-flash-lite', 'gemini-2.5-flash'];
    let geminiData = null;
    for (const model of models) {
      let success = false;
      for (let attempt = 1; attempt <= 2; attempt++) {
        const result = await callGemini(model);
        if (!result.error) { geminiData = result; success = true; break; }
        const code = result.error.code;
        if ((code === 429 || code === 503) && attempt < 2) {
          console.log(`${model} 재시도...`);
          await new Promise(r => setTimeout(r, 3000));
        } else {
          console.log(`${model} 실패 (${code}), 다음 모델 시도`);
          break;
        }
      }
      if (success) break;
    }
    if (!geminiData || geminiData.error) {
      throw new Error('모든 모델 시도 실패: ' + (geminiData?.error?.message ?? '알 수 없는 오류'));
    }

    const text = geminiData.candidates?.[0]?.content?.parts?.[0]?.text ?? '';
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (!jsonMatch) throw new Error('JSON 파싱 실패');
    const parsed = JSON.parse(jsonMatch[0]);

    res.json(responseWrapper('SUCCESS', '추천 완료', {
      message: parsed.message,
      recommendations: parsed.recommendations ?? [],
    }));
  } catch (err) {
    console.error('Chat error:', err);
    res.status(500).json(responseWrapper('ERROR_INTERNAL', '추천을 가져오지 못했어요. 잠시 후 다시 시도해주세요.'));
  }
});

// 서버 실행
app.listen(PORT, () => {
  console.log(`서버가 http://localhost:${PORT} 에서 실행 중입니다.`);
  console.log(`Swagger 문서는 http://localhost:${PORT}/api-docs 에서 확인하세요.`);
});