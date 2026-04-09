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
app.get('/api/v1/bakeries/:bakeryId', (req, res) => {
  const bakeryId = parseInt(req.params.bakeryId, 10);

  if (isNaN(bakeryId)) {
    return res.status(400).json(responseWrapper("ERROR_INVALID_PARAM", "유효하지 않은 빵집 ID입니다."));
  }
  if (bakeryId === 999) { // 404 에러 테스트용 더미 ID
    return res.status(404).json(responseWrapper("ERROR_NOT_FOUND", "존재하지 않는 빵집입니다."));
  }

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

// 서버 실행
app.listen(PORT, () => {
  console.log(`서버가 http://localhost:${PORT} 에서 실행 중입니다.`);
  console.log(`Swagger 문서는 http://localhost:${PORT}/api-docs 에서 확인하세요.`);
});