// app.js
const express = require('express');
const cors = require('cors');
const swaggerUi = require('swagger-ui-express');
const swaggerJsdoc = require('swagger-jsdoc');

const app = express();
const PORT = 3000;

app.use(cors());
app.use(express.json());

// 0-1. 공통 응답 포맷 래퍼 함수 [cite: 4]
// 성공 시 SUCCESS, 에러 시 ERROR_CODE 반환 [cite: 7]
const responseWrapper = (code, message, data = null) => {
    return {
        code: code,
        message: message, // 클라이언트 노출용 메세지 [cite: 8]
        data: data        // 실제 데이터 (없는 경우 null) [cite: 10]
    };
};

// Swagger 기본 설정
const options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: '대전 빵집 지도 APP API', // [cite: 2]
      version: '1.0.0',
      description: '대전 빵집 지도 앱 백엔드 API 명세서입니다.',
    },
  },
  apis: ['./app.js'], // Swagger 주석을 읽어올 파일 경로
};

const swaggerSpec = swaggerJsdoc(options);
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

/**
 * @swagger
 * /api/v1/bakeries:
 *   get:
 *     summary: 1-1. 빵집 리스트 조회 (지도/홈/검색)
 *     description: 지도 화면의 핀, 바텀 시트 리스트, 검색 결과에 사용되는 통합 API입니다.
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
// GET /api/v1/bakeries
app.get('/api/v1/bakeries', (req, res) => {
    // 1. Query Parameters 추출
    const { lat, lon, radius, keyword, sort, filter } = req.query;

    // 필수 파라미터 검증 (lat, lon)
    if (!lat || !lon) {
        return res.status(400).json(
            responseWrapper("ERROR_MISSING_PARAM", "위도(lat)와 경도(lon)는 필수입니다.")
        );
    }

    // 2. 명세서에 기반한 더미(Mock) 데이터 구성
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
            },
            {
                id: 125,
                name: "하레하레 둔산점",
                thumbnailUrl: "https://cdn.bread.com/img/125_main.jpg",
                latitude: 36.3512,
                longitude: 127.3789,
                distance: 1200,
                rating: 4.5,
                reviewCount: 540,
                tags: ["쌀빵", "디저트"],
                isOpen: false
            }
        ]
    };

    // 3. 공통 포맷으로 응답 반환
    res.json(responseWrapper("SUCCESS", "요청이 성공하였습니다.", mockData));
});

app.listen(PORT, () => {
    console.log(`서버가 http://localhost:${PORT} 에서 실행 중입니다.`);
    console.log(`Swagger 문서는 http://localhost:${PORT}/api-docs 에서 확인하세요.`);
});