# REVIEW

> 예상 학습 시간: 30~45분

## 1. 학습 목표

* 코드, 오류, 문서에서 반복되는 영어를 단어 단위로 분해한다.
* 일반 의미보다 개발 문맥에서의 역할을 먼저 떠올린다.
* Swift/SwiftUI 예제, 검색어, 면접 답변으로 연결한다.

## 2. 핵심 단어

| 영어 | 발음 참고 | 개발 문맥 의미 | 일반 의미 |
|---|---|---|---|
| add | add | Swift/iOS 문맥에서 add가 가리키는 역할을 파악한다 | 일반 영어의 기본 의미 |
| append | app | Swift/iOS 문맥에서 append가 가리키는 역할을 파악한다 | 일반 영어의 기본 의미 |
| apply | app | Swift/iOS 문맥에서 apply가 가리키는 역할을 파악한다 | 일반 영어의 기본 의미 |
| assign | ass | Swift/iOS 문맥에서 assign가 가리키는 역할을 파악한다 | 일반 영어의 기본 의미 |
| bind | bin | Swift/iOS 문맥에서 bind가 가리키는 역할을 파악한다 | 일반 영어의 기본 의미 |
| build | bui | Swift/iOS 문맥에서 build가 가리키는 역할을 파악한다 | 일반 영어의 기본 의미 |
| cache | cac | Swift/iOS 문맥에서 cache가 가리키는 역할을 파악한다 | 일반 영어의 기본 의미 |
| cancel | can | Swift/iOS 문맥에서 cancel가 가리키는 역할을 파악한다 | 일반 영어의 기본 의미 |
| capture | cap | Swift/iOS 문맥에서 capture가 가리키는 역할을 파악한다 | 일반 영어의 기본 의미 |
| cast | cas | Swift/iOS 문맥에서 cast가 가리키는 역할을 파악한다 | 일반 영어의 기본 의미 |
| argument | arg | Swift/iOS 문맥에서 argument가 가리키는 역할을 파악한다 | 일반 영어의 기본 의미 |
| parameter | par | Swift/iOS 문맥에서 parameter가 가리키는 역할을 파악한다 | 일반 영어의 기본 의미 |

## 3. 단어 구성 분석

```text
configuration = configure + -ation = 설정하는 행위 또는 설정 정보
invalid = in- + valid = 유효하지 않은 상태
asynchronous = a- + synchronous = 동시에 맞춰 기다리지 않는 실행 방식
```

## 4. 실제 코드에서 보기

```swift
struct UserProfileView: View {
    @State private var isLoading = false

    var body: some View {
        VStack {
            Text(isLoading ? "Loading..." : "Profile")
            Button("Refresh") {
                Task { await fetchUserProfile() }
            }
        }
    }

    func fetchUserProfile() async {
        isLoading = true
        defer { isLoading = false }
    }
}
```

* `fetchUserProfile`: fetch + User + Profile, 사용자 프로필을 가져오는 함수
* `isLoading`: 현재 로딩 상태인지 나타내는 Boolean 이름
* `defer`: 함수가 끝날 때 실행할 정리 작업

## 5. Xcode 또는 문서에서 보기

* `Build failed`: 빌드가 실패했다.
* `This property is available in iOS 17.0 and later`: 이 속성은 iOS 17 이상에서 사용할 수 있다.
* `Cannot find 'user' in scope`: 현재 범위에서 `user`를 찾을 수 없다.

## 6. 문장 끊어 읽기

```text
Cannot convert / value of type 'String' / to expected argument type 'Int'
변환할 수 없다 / String 타입의 값을 / 예상되는 Int 인자 타입으로
```

## 7. 자연스러운 한국어 해석

* 직역: String 타입의 값을 예상되는 Int 인자 타입으로 변환할 수 없다.
* 개발자식 해석: Int가 필요한 자리에 String을 넣었다.

## 8. 비슷한 단어 비교

* create: 새로 만든다. `createAccount()`
* generate: 규칙이나 데이터로 만들어 낸다. `generateToken()`
* initialize: 초기값을 넣어 준비한다. `initializeStore()`
* configure: 설정값을 적용한다. `configureCell()`
* update: 이미 있는 값을 바꾼다. `updateProfile()`

## 9. 자주 하는 오해

* `argument`와 `parameter`를 모두 “파라미터”로만 외우면 오류 메시지에서 헷갈린다. 호출하는 쪽 값은 argument, 함수 선언의 자리는 parameter다.
* `state`는 단순한 “상태”가 아니라 화면을 다시 그리게 만드는 데이터일 수 있다.

## 10. 직접 해석 문제

1. `Missing argument for parameter 'title' in call`
2. `The request failed because the token is invalid.`
3. `Update the selected item when the user taps a row.`

## 11. 검색어 만들기

* `SwiftUI state not updating after async request`
* `Swift cannot convert String to Int expected argument type`
* `Xcode build failed provisioning profile does not match`

## 12. AI에게 요청하기

```text
Explain the following Swift error in simple Korean.
Identify the expected type, the actual type, and the smallest fix.
```

## 13. 면접에서 사용하기

* `I validate user input before sending a request.`
* `I handle errors by showing a user-friendly message.`
* `I use state to update the SwiftUI view automatically.`

## 14. 오늘의 복습 카드

* 30개 단어로 함수 이름 10개, 검색어 5개, 면접 문장 3개를 만든다.

## 15. 완료 체크

* [ ] 단어를 보고 의미를 떠올릴 수 있다.
* [ ] 코드 이름을 분해할 수 있다.
* [ ] 오류 메시지 핵심을 찾을 수 있다.
* [ ] 영어 검색어를 만들 수 있다.
