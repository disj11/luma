# Luma Character Pack Standard

작성일: 2026-05-20

이 앱의 목표는 코드 수정 없이 캐릭터를 추가할 수 있는 구조다. 캐릭터 제작자는 정해진 폴더 구조와 `manifest.json`만 맞추면 된다.

## 폴더 구조

```text
MyCharacter/
├─ manifest.json
└─ poses/
   ├─ idle.png
   ├─ walk.png
   ├─ jump.png
   ├─ fall.png
   ├─ sit.png
   ├─ sleep.png
   ├─ groom.png
   ├─ happy.png
   ├─ alert.png
   ├─ play.png
   └─ peek.png
```

현재 번들 캐릭터는 `Sources/AIPet/Resources/Pets` 아래에 들어 있다. 기본 캐릭터는 `LunaSera`이고, 추가 번들 캐릭터로 `KohakuMori`가 포함된다.

앱에서 캐릭터를 추가하는 방법:

1. `manifest.json`이 들어 있는 캐릭터 폴더를 준비한다.
2. 메뉴바의 `캐릭터`를 연다.
3. `팩 검증...`으로 폴더를 먼저 검사한다.
4. `캐릭터 추가...`를 누르고 캐릭터 폴더를 선택한다.
5. 앱은 해당 폴더를 `~/Library/Application Support/Luma/Characters/<character-id>`로 복사하고 즉시 선택한다.
6. `포즈 미리보기`에서 렌더 박스, 실제 alpha 영역, 하단 기준선을 확인한다.

처음 실행 시 기본 선택 캐릭터는 내장된 `루나 세라`다. 캐릭터 메뉴에서는 함께 제공되는 `모리 코하쿠`도 선택할 수 있다.

## 필수 포즈

최소 필수:
- `idle`
- `walk`
- `jump`
- `fall`
- `sit`
- `sleep`
- `alert`

권장:
- `groom`
- `happy`
- `play`
- `peek`

포즈가 빠지면 앱은 `defaultPose`를 fallback으로 사용할 수 있게 설계한다. 다만 제품 품질을 위해 위 권장 포즈까지 제공하는 것이 좋다.

## 이미지 기준

- 포맷: 투명 배경 PNG
- 권장 캔버스: `512 x 512`
- 캐릭터는 캔버스 안에 완전히 들어와야 한다.
- 네 모서리 alpha는 반드시 `0`이어야 한다.
- 캐릭터 발 또는 바닥 기준점은 포즈 간 최대한 비슷한 y 위치에 맞춘다.
- 한 PNG 안에 다른 포즈 조각, 그림자, 가이드라인, 텍스트가 들어가면 안 된다.
- 외부 그림자는 PNG에 넣지 않는다. 앱이 동적 그림자를 그린다.

## manifest.json 예시

```json
{
  "id": "my-character",
  "displayName": "My Character",
  "version": 1,
  "author": "Creator",
  "persona": "캐릭터의 말투, 성격, 시그니처 포인트를 한국어로 짧고 명확하게 설명한다.",
  "defaultPose": "idle",
  "canvasSize": 512,
  "render": {
    "baseSize": 202,
    "baseYOffset": 9
  },
  "poses": {
    "idle": { "file": "poses/idle.png", "motion": "breathe" },
    "walk": { "file": "poses/walk.png", "motion": "walk", "crossfade": false },
    "jump": { "file": "poses/jump.png", "motion": "jump", "scale": 1.04, "yOffset": 18, "crossfade": false },
    "fall": { "file": "poses/fall.png", "motion": "fall", "scale": 1.04, "yOffset": 6, "crossfade": false },
    "sit": { "file": "poses/sit.png", "motion": "sit" },
    "sleep": { "file": "poses/sleep.png", "motion": "sleep", "scale": 0.94, "yOffset": -3 },
    "alert": { "file": "poses/alert.png", "motion": "alert", "crossfade": false },
    "happy": { "file": "poses/happy.png", "motion": "happy" },
    "play": { "file": "poses/play.png", "motion": "play" },
    "peek": { "file": "poses/peek.png", "motion": "peek" }
  }
}
```

## 지원 motion 이름

- `breathe`: 가벼운 호흡
- `walk`: 한 포즈 기반 보행 바운스
- `jump`: 점프 스쿼시/스트레치
- `fall`: 낙하 포즈
- `sit`: 앉은 상태의 작은 호흡
- `alert`: 마우스 오버/반응용 미세 움직임
- `sleep`: 수면 호흡
- `groom` 또는 `wave`: 손 흔들기/정리 동작
- `happy`: 기쁨 바운스
- `play`: 놀이 바운스
- `peek`: 엿보기

## 제작 체크리스트

1. 모든 포즈 PNG가 `RGBA`인지 확인한다.
2. 네 모서리 alpha가 `0`인지 확인한다.
3. 포즈별 캐릭터 크기가 크게 흔들리지 않는지 확인한다.
4. `walk`는 한 방향으로 안정적인 포즈를 사용한다.
5. 포즈 전환 잔상이 어색한 포즈는 `"crossfade": false`를 지정한다.
6. `baseSize`, `baseYOffset`, pose별 `scale`, `yOffset`으로 발 위치를 맞춘다.
7. 앱의 `팩 검증...`에서 하단 기준점 편차와 누락 포즈를 확인한다.
8. 앱의 `포즈 미리보기`에서 빨간 하단 기준선이 포즈마다 크게 흔들리지 않는지 확인한다.
