# iOS Study Roadmap

Swift 기초 문법부터 SwiftUI 앱 개발, MVVM, 네트워크, 데이터 저장, 테스트, 성능 최적화, 포트폴리오와 기술 면접까지 순서대로 학습하는 개인 학습 저장소입니다.

## 전체 학습 목표

* Swift 기본 문법을 실제 앱 코드와 연결한다.
* SwiftUI 화면을 컴포넌트 단위로 만들고 상태를 관리한다.
* MVVM, Service, Repository, 의존성 주입을 이해한다.
* REST API, async/await, JSON, 로딩/에러/빈 상태를 구현한다.
* SwiftData 또는 Core Data로 데이터를 유지한다.
* XCTest로 ViewModel과 비즈니스 로직을 검증한다.
* 성능 문제와 메모리 누수를 분석한다.
* 포트폴리오 프로젝트를 면접에서 설명할 수 있다.

## 권장 학습 순서

1단계: Swift 기초  
2단계: Swift 핵심 문법  
3단계: Swift 고급 문법  
4단계: SwiftUI 화면 구현  
5단계: 상태 관리  
6단계: 앱 아키텍처  
7단계: 네트워크와 동시성  
8단계: 데이터 저장  
9단계: 테스트와 성능  
10단계: 알고리즘과 면접  
11단계: 포트폴리오 완성

## 단계 구분

| 단계 | 폴더 | 목적 |
|---|---|---|
| 초급 | 00, 01 | 개발 환경, Swift 기초, 앱 코드 연결 |
| 중급 | 02, 03, 04, 05 | 핵심 문법, SwiftUI, 상태 관리 |
| 실무 | 06~12 | 아키텍처, 네트워크, 저장소, 테스트, 성능 |
| 협업/면접 | 13~16 | Git, 알고리즘, 면접, 포트폴리오 |
| 완성 | 17, 18 | 최종 프로젝트와 장기 복습 |

## 각 폴더의 역할

* `00_Getting_Started`: iOS, Xcode, SwiftUI 프로젝트 구조를 익힌다.
* `01_Swift_Basics`: 변수, 타입, 조건, 반복, 함수, 컬렉션, Optional을 앱 예제로 학습한다.
* `02_Swift_Core`: Struct, Class, Protocol, Extension 등 설계의 기초를 다룬다.
* `03_Swift_Advanced`: Closure, Generic, Error Handling, ARC를 실무 코드와 연결한다.
* `04_SwiftUI_Basics`: 화면 구성 요소와 컴포넌트 분리를 학습한다.
* `05_SwiftUI_State`: `@State`, `@Binding`, `@Observable`, Environment를 선택하는 기준을 만든다.
* `06_App_Architecture`: MVVM과 계층 분리를 배운다.
* `07_Networking`: REST API, URLSession, Codable, 페이지네이션을 구현한다.
* `08_Concurrency`: async/await, Task, MainActor, Actor를 이해한다.
* `09_Data_Persistence`: UserDefaults, Keychain, FileManager, SwiftData/Core Data를 비교한다.
* `10_Practical_iOS`: 앱 생명주기, 권한, 접근성, 배포를 다룬다.
* `11_Testing`: XCTest와 Mock 기반 테스트를 작성한다.
* `12_Performance`: ARC, retain cycle, Instruments, 렌더링 최적화를 학습한다.
* `13_Git_Collaboration`: 협업에 필요한 Git, PR, 리뷰 문화를 익힌다.
* `14_Algorithms`: Swift로 코딩 테스트 기본기를 준비한다.
* `15_Interview`: 기술 면접 답변과 꼬리 질문을 연습한다.
* `16_Portfolio`: 프로젝트 README, 트러블슈팅, 성과 정리를 만든다.
* `17_Final_Projects`: Todo, Network, Portfolio, Interview 프로젝트를 완성한다.
* `18_Review`: 30일 복습 루틴으로 장기 기억을 만든다.

## 예상 결과물

* Swift 기초 콘솔 프로그램
* SwiftUI Todo 앱
* REST API 기반 네트워크 앱
* SwiftData CRUD 앱
* MVVM 기반 포트폴리오 앱
* 면접 답변 노트와 프로젝트 기술 설명서

## 주간 학습 방법

1. 월~목: 하루 1개 Markdown 파일을 읽고 예제를 직접 입력한다.
2. 금: 해당 주제의 실습 문제를 앱 화면으로 구현한다.
3. 토: 면접 질문을 소리 내어 답하고 녹음한다.
4. 일: `REVIEW.md`로 복습하고 체크리스트를 갱신한다.

## 실습 코드 실행 방법

* 단독 Swift 코드는 Xcode Playground 또는 Swift Package의 `main.swift`에서 실행한다.
* SwiftUI 코드는 Xcode에서 iOS App 프로젝트를 만든 뒤 `ContentView.swift`에 붙여 실행한다.
* `Examples` 폴더의 `.swift` 파일은 각 장의 코드를 모아 실험하는 용도다.

## 체크리스트 사용법

`STUDY_CHECKLIST.md`는 읽기, 따라 쓰기, 암기 없이 구현, 앱 적용, 면접 설명까지 5단계로 관리합니다. `INTERVIEW_CHECKLIST.md`는 키워드, 30초 답변, 1분 답변, 코드 예제, 꼬리 질문 대응 여부를 표시합니다.

## 최종 프로젝트 설명

최종 프로젝트는 Todo, Network, Portfolio, Interview Project 순서로 진행합니다. 처음에는 단순한 구조로 만들고, 이후 MVVM, Protocol, Dependency Injection, 테스트, 접근성, 다크 모드, 다국어 확장 구조를 추가하며 리팩터링합니다.

## 면접 준비 방법

각 문법 파일의 면접 질문을 먼저 30초로 답하고, 이후 프로젝트 경험과 연결해 1분 답변으로 확장합니다. 모르는 경험은 만들지 말고 `[프로젝트명]`, `[문제 상황]`, `[해결 방법]` 템플릿에 자신의 실제 경험을 채웁니다.
