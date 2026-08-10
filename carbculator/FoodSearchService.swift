//
//  FoodSearchService.swift
//  carbculator
//
//  식약처 식품영양성분 DB(공공데이터포털 FoodNtrCpntDbInfo02)를 검색해
//  음식명과 100g당 탄수화물을 가져오는 서비스.
//

import Foundation

// MARK: - 검색 결과 모델

/// 검색 결과 한 건. 값은 모두 100g 기준으로 정규화되어 있다.
struct FoodItem: Identifiable, Equatable {
    let id: String            // FOOD_CD (또는 로컬 DB id)
    let name: String          // FOOD_NM_KR
    let carbsPer100g: Double   // 탄수화물(g) / 100g
    let kcalPer100g: Double?   // 열량(kcal) / 100g (참고용)
    var servingGrams: Double? = nil   // 1회 제공량(g) — 로컬 DB에만 존재
}

// MARK: - 로컬 음식 DB (번들 포함, API보다 우선 조회)

/// korean_food_db_1000.json 의 한 항목
private struct LocalFood: Decodable {
    let id: String
    let foodName: String
    let category: String
    let servingSizeG: Double
    let carbsPer100g: Double
    let carbsPerServing: Double
    let caloriesKcal: Double
    let proteinG: Double
    let fatG: Double
}

enum LocalFoodStore {
    /// 앱 번들의 JSON을 한 번만 로드 (없으면 빈 배열 → API 폴백)
    private static let all: [LocalFood] = {
        guard let url = Bundle.main.url(forResource: "korean_food_db_1000", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([LocalFood].self, from: data) else {
            return []
        }
        return list
    }()

    /// 부분일치 검색 → 관련도 정렬 → FoodItem 매핑 (servingSizeG를 1회 제공량으로 전달)
    static func search(_ query: String) -> [FoodItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        return all
            .filter { $0.foodName.contains(q) }
            .sorted { sortKey($0.foodName, q) < sortKey($1.foodName, q) }
            .map {
                FoodItem(
                    id: $0.id,
                    name: $0.foodName,
                    carbsPer100g: $0.carbsPer100g,
                    kcalPer100g: $0.caloriesKcal,
                    servingGrams: $0.servingSizeG
                )
            }
    }

    private static func sortKey(_ name: String, _ q: String) -> (Int, Int, String) {
        let tier: Int
        if name == q { tier = 0 }
        else if name.hasPrefix(q) { tier = 1 }
        else { tier = 2 }
        return (tier, name.count, name)
    }
}

// MARK: - 검색 서비스

enum FoodSearchService {
    private static let base =
        "https://apis.data.go.kr/1471000/FoodNtrCpntDbInfo02/getFoodNtrCpntDbInq02"

    /// 음식명으로 검색한다. 결과는 정확일치·접두어 우선으로 정렬된다.
    /// - Note: 취소된 경우 `CancellationError`를 던진다(호출부에서 무시하면 됨).
    static func search(_ query: String, numOfRows: Int = 100) async throws -> [FoodItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        // 1) 로컬 DB 우선 조회 (즉시·오프라인). 결과가 있으면 그대로 사용.
        let local = LocalFoodStore.search(trimmed)
        if !local.isEmpty { return local }

        // 2) 로컬에 없으면 식약처 API 폴백
        guard let encodedName = trimmed.addingPercentEncoding(withAllowedCharacters: .foodQueryAllowed)
        else { return [] }

        // serviceKey는 이미 URL 인코딩된 값이므로 URLComponents로 재인코딩하지 않고
        // 문자열에 직접 붙인다. (data.go.kr의 '+' 재인코딩 문제 회피)
        let urlString = "\(base)?serviceKey=\(FoodAPIConfig.serviceKeyEncoded)"
            + "&pageNo=1&numOfRows=\(numOfRows)&type=json&FOOD_NM_KR=\(encodedName)"
        guard let url = URL(string: urlString) else { return [] }

        let (data, response) = try await URLSession.shared.data(from: url)
        try Task.checkCancellation()

        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw FoodSearchError.network
        }

        let decoded: FoodAPIResponse
        do {
            decoded = try JSONDecoder().decode(FoodAPIResponse.self, from: data)
        } catch {
            // 인증 오류 등은 JSON이 아닌 XML로 오기도 한다.
            throw FoodSearchError.decoding
        }
        guard decoded.header?.resultCode == "00" else {
            throw FoodSearchError.server(decoded.header?.resultMsg ?? "")
        }

        // 소스·가루 등 제외 후 매핑
        let mapped = (decoded.body?.items ?? [])
            .filter { !$0.isExcludedItem }
            .compactMap { $0.toFoodItem() }
        // 같은 이름은 하나만 남긴다. (같은 음식인데 탄수화물만 다른 중복 제거)
        // API가 먼저 반환한(대표) 값을 남기도록 정렬 전에 이름 기준으로 중복을 거른다.
        var seenNames = Set<String>()
        let unique = mapped.filter { seenNames.insert($0.name).inserted }
        // 정렬: (관련도 단계, 이름 길이, 이름) 순 → 동점이면 짧은 이름(대표 음식)을 우선
        return unique.sorted { sortKey($0.name, trimmed) < sortKey($1.name, trimmed) }
    }

    private static func sortKey(_ name: String, _ q: String) -> (Int, Int, String) {
        (matchTier(name, q), name.count, name)
    }

    /// 검색어 관련도 단계 (작을수록 상위). 이름은 '_', 공백, 괄호 등으로 토큰 분리해 판정한다.
    private static func matchTier(_ name: String, _ q: String) -> Int {
        if name == q { return 0 }                      // 완전일치
        if name.hasPrefix(q) { return 1 }              // 이름이 검색어로 시작
        let separators = CharacterSet(charactersIn: "_ /()-,·[]{}")
        let tokens = name.components(separatedBy: separators).filter { !$0.isEmpty }
        if tokens.contains(where: { $0 == q }) { return 2 }        // 토큰 완전일치
        if tokens.contains(where: { $0.hasPrefix(q) }) { return 3 } // 토큰이 검색어로 시작
        if name.contains(q) { return 4 }               // 부분 포함
        return 5
    }
}

enum FoodSearchError: Error {
    case network
    case decoding
    case server(String)
}

// MARK: - API 응답 디코딩 (필요한 필드만)

private struct FoodAPIResponse: Decodable {
    let header: Header?
    let body: Body?

    struct Header: Decodable {
        let resultCode: String?
        let resultMsg: String?
    }
    struct Body: Decodable {
        let items: [RawItem]?
    }
}

private struct RawItem: Decodable {
    let FOOD_CD: String?
    let FOOD_NM_KR: String?
    let FOOD_CAT1_NM: String?   // 대분류 (예: "밥류", "장류, 양념류")
    let SERVING_SIZE: String?
    let AMT_NUM1: String?   // 열량(kcal)
    let AMT_NUM6: String?   // 탄수화물(g)

    /// 소스·가루 등 한 끼로 먹지 않는 조미료/원재료성 항목이면 true.
    /// (대분류 카테고리 + 이름 첫 토큰 키워드 병행 판정. 필요에 따라 목록을 조정)
    var isExcludedItem: Bool {
        let name = FOOD_NM_KR ?? ""
        // 1) 카테고리 기준 제외
        let blockedCategories: Set<String> = ["장류, 양념류"]
        if let cat = FOOD_CAT1_NM, blockedCategories.contains(cat) { return true }
        // 2) 이름 첫 토큰(_ 앞 = 음식 종류) 기준 제외.
        //    "스파게티_까르보나라소스"처럼 변형 부분에만 키워드가 있는 실제 요리는 남긴다.
        let head = name.split(separator: "_").first.map(String.init) ?? name
        let blockedKeywords = ["소스", "드레싱", "가루", "분말", "시즈닝", "양념장",
                               "향신료", "조미료", "페이스트", "액젓", "젓갈"]
        return blockedKeywords.contains { head.contains($0) }
    }

    /// 제공량 기준 값을 100g 기준으로 정규화해 FoodItem으로 변환한다.
    func toFoodItem() -> FoodItem? {
        guard let id = FOOD_CD, let name = FOOD_NM_KR,
              let carbStr = AMT_NUM6, let carb = Double(carbStr) else { return nil }

        let serving = Self.servingGrams(SERVING_SIZE)
        let factor = serving > 0 ? 100 / serving : 1
        let kcal = AMT_NUM1.flatMap(Double.init).map { $0 * factor }

        return FoodItem(
            id: id,
            name: name,
            carbsPer100g: carb * factor,
            kcalPer100g: kcal
        )
    }

    /// "100g", "100mL", "200 g" 등에서 앞의 숫자를 그램으로 추출. (mL은 g로 근사)
    private static func servingGrams(_ s: String?) -> Double {
        guard let s = s else { return 0 }
        let num = s.prefix { $0.isNumber || $0 == "." }
        return Double(num) ?? 0
    }
}

// MARK: - 쿼리 인코딩

private extension CharacterSet {
    /// 한글·공백·기호를 모두 퍼센트 인코딩하도록 영숫자만 허용한다.
    static let foodQueryAllowed = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    )
}
