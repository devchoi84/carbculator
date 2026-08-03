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
    let id: String            // FOOD_CD
    let name: String          // FOOD_NM_KR
    let carbsPer100g: Double   // 탄수화물(g) / 100g
    let kcalPer100g: Double?   // 열량(kcal) / 100g (참고용)
}

// MARK: - 검색 서비스

enum FoodSearchService {
    private static let base =
        "https://apis.data.go.kr/1471000/FoodNtrCpntDbInfo02/getFoodNtrCpntDbInq02"

    /// 음식명으로 검색한다. 결과는 정확일치·접두어 우선으로 정렬된다.
    /// - Note: 취소된 경우 `CancellationError`를 던진다(호출부에서 무시하면 됨).
    static func search(_ query: String, numOfRows: Int = 25) async throws -> [FoodItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              let encodedName = trimmed.addingPercentEncoding(withAllowedCharacters: .foodQueryAllowed)
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

        let mapped = (decoded.body?.items ?? []).compactMap { $0.toFoodItem() }
        // FOOD_CD 중복 제거(제공량 변형 등) + 관련도 정렬
        var seen = Set<String>()
        let unique = mapped.filter { seen.insert($0.id).inserted }
        return unique.sorted { rank($0.name, trimmed) < rank($1.name, trimmed) }
    }

    private static func rank(_ name: String, _ q: String) -> Int {
        if name == q { return 0 }
        if name.hasPrefix(q) { return 1 }
        return 2
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
    let SERVING_SIZE: String?
    let AMT_NUM1: String?   // 열량(kcal)
    let AMT_NUM6: String?   // 탄수화물(g)

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
