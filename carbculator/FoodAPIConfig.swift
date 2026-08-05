//
//  FoodAPIConfig.swift
//  carbculator
//
//  공공데이터포털 식품영양성분DB 서비스키 설정.
//
//  ⚠️ 보안 참고: 이 키는 저장소(비공개)와 앱 바이너리에 포함됩니다.
//     정식 공개 배포 전에는 (1) 키를 재발급하고 (2) 서버 프록시를 통해 호출하는 것을 권장합니다.
//

import Foundation

enum FoodAPIConfig {
    /// 공공데이터포털 식품영양성분DB(FoodNtrCpntDbInfo02) 서비스키.
    /// 포털에서 발급된 "인코딩(Encoding)" 키(%2B, %3D 등이 포함된 값)를 그대로 넣는다.
    static let serviceKeyEncoded =
        "i7xvvVjvduTUNb6gbbaLfQ5PylcH%2BjVgxFK57%2B2z6btCPFnluAbLipP7Q7JV5UwBeh7Nb%2BBtRioPSx9h40KUyg%3D%3D"
}
