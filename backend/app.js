const express = require('express');
const cors = require('cors');
const swaggerUi = require('swagger-ui-express');
const swaggerJsdoc = require('swagger-jsdoc');

const app = express();
const PORT = 3000;

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
 *         description: 정렬(DISTANCE, RATING, REVIEW)
 *         example: DISTANCE
 *       - in: query
 *         name: filter
 *         schema:
 *           type: string
 *         description: 지역 필터(ALL, DONG GU, SEO GU...)
 *     responses:
 *       200:
 *         description: 성공
 */
app.get('/api/v1/bakeries', (req, res) => {
  const { lat, lon } = req.query;

  if (!lat || !lon) {
    return res.status(400).json(responseWrapper("ERROR_MISSING_PARAM", "위도(lat)와 경도(lon)는 필수입니다."));
  }

  // 명세서 기반 더미 데이터 [cite: 26-59]
  const mockData = {
    totalCount: 15,
    bakeries: [
      {
        id: 120,
        name: "성심당 본점",
        thumbnailUrl: "https://cdn.bread.com/img/120_main.jpg",
        latitude: 36.3276,
        longitude: 127.4273,
        distance: 350,
        rating: 4.8,
        reviewCount: 15234,
        tags: ["대전 대표", "튀김소보로", "웨이팅필수"],
        isOpen: true
      }
    ]
  };

  res.json(responseWrapper("SUCCESS", "요청이 성공하였습니다.", mockData));
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
 */
app.get('/api/v1/bakeries/:bakeryId', (req, res) => {
  const bakeryId = parseInt(req.params.bakeryId, 10);

  // 명세서 기반 1-2 더미 데이터 [cite: 60-100]
  const mockData = {
    bakeryInfo: {
      id: bakeryId,
      name: "성심당 본점",
      imageUrls: [
        "https://cdn.bread.com/img/120_1.jpg",
        "https://cdn.bread.com/img/120_2.jpg",
        "https://cdn.bread.com/img/120_3.jpg"
      ],
      address: "대전광역시 중구 대종로 480번길 15",
      roadAddress: "대전광역시 중구 은행동 145",
      phoneNumber: "042-256-7720",
      homepageUrl: "https://sungsimdang.co.kr",
      businessHours: "08:00 22:00",
      description: "1956년 대전역 앞 작은 찐빵집에서 시작된 대전의 문화입니다.",
      amenities: ["PARKING", "PACKING", "WIFI", "RESTROOM"],
      representativeMenus: ["튀김소보로", "판타롱부추빵", "명란바게트"],
      stats: {
        rating: 4.8,
        reviewCount: 15234,
        favoriteCount: 4500
      },
      userAction: {
        isFavorite: true
      }
    }
  };

  res.json(responseWrapper("SUCCESS", "상세 정보 조회가 성공하였습니다.", mockData));
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

// 서버 실행
app.listen(PORT, () => {
  console.log(`서버가 http://localhost:${PORT} 에서 실행 중입니다.`);
  console.log(`Swagger 문서는 http://localhost:${PORT}/api-docs 에서 확인하세요.`);
});