# 실행 계획 (plan.md)

대상 스펙: [`spec.md`](./spec.md)
목표: `hugo-theme-stack` 제거 → 저장소가 직접 소유하는 미니멀 테마로 교체.

## 단계 개요

| # | 단계 | 성격 | 산출물 | 되돌리기 |
|---|---|---|---|---|
| 0 | 베이스라인 확보 | 준비 | 브랜치, 현재 빌드 스냅샷 | — |
| **1** | **디자인 시안 확정** | **게이트** | `design/mockup.html` | 커밋 전 폐기 |
| 2 | 테마 제거 + 설정 재작성 | 파괴적 | config, i18n | git revert |
| 3 | 레이아웃 골격 | 구현 | `layouts/**` | git revert |
| 4 | CSS + 테마 토글 | 구현 | `assets/css/main.css` | git revert |
| 5 | 코드 하이라이팅 | 구현 | `scripts/gen-chroma.sh`, `chroma.css` | git revert |
| 6 | 콘텐츠 이관 + 다국어 | 이관 | `content/**` | git revert |
| 7 | 도메인 + 배포 파이프라인 | 인프라 | `static/CNAME`, `deploy.yml` | git revert |
| 8 | 최종 검수 후 배포 | 검증 | — | `master` 되돌리기 |

**1단계는 게이트다.** 시안이 확정되기 전에는 2단계 이후로 넘어가지 않는다.
2단계부터는 사이트가 일시적으로 깨진 상태가 되므로, 작업 브랜치에서만 진행한다.

---

## 0단계 — 베이스라인 확보

**왜**: 2단계에서 테마와 `public/`을 지우기 때문에, 비교 대상과 복구 지점이 먼저 필요하다.

작업
- `git switch -c feat/custom-theme` — `master`는 건드리지 않는다. 배포는 8단계에서 머지로만 일어난다.
- `hugo --gc` 1회 실행해 현재 테마가 정상 빌드되는지 확인 (이후 회귀 판단 기준).
- 현재 라이브 사이트의 홈 / 글 페이지 스크린샷을 남긴다 (비교용, 커밋하지 않음).

완료 조건
- [ ] 작업 브랜치 생성, `master`는 clean
- [ ] 기존 테마로 빌드 성공 확인

---

## 1단계 — 디자인 시안 확정 ← **게이트, 여기서 멈춤**

**왜**: Hugo 템플릿에 손대기 전에 시각 언어를 먼저 못박는다. 레이아웃·간격·색·폰트 크기 판단을
템플릿 문법과 섞으면 되돌리기 비싸진다. 순수 HTML/CSS면 수정이 몇 초다.

**중요**: 이 단계의 산출물은 Hugo와 무관한 **정적 HTML 한 장**이다. `layouts/`를 만들지 않는다.

### 1.1 시안 제작

`design/mockup.html` — 단일 파일. CSS 인라인, 빌드 도구 없음.

한 파일 안에서 화면을 전환할 수 있게 한다 (상단 미리보기 전환 바, 시안 전용 UI — 실제 사이트에는 없음):

1. **홈** — 날짜 + 제목 목록 8~10줄. 긴 제목, 한글/영문 혼용 제목 포함
2. **글 본문** — h2/h3, 문단, 인용문, 불릿, 링크, 표, 인라인 코드,
   **Go 코드블록**(긴 줄 → 가로 스크롤 확인용), 이미지 1장
3. **소개(about)** — 기존 이력서 마크다운 렌더 결과
4. **태그 목록** — 태그명 + 글 수
5. **404**

시안에서 실제로 동작해야 하는 것 (스펙의 위험 지점을 여기서 미리 검증)
- 테마 토글 3상태 `auto → light → dark → auto` + `localStorage` + FOUC 없음 (spec §4.2 그대로)
- 언어 토글 `KO | EN` 활성/비활성 표시 (이동은 더미)
- Catppuccin Latte/Mocha 코드블록이 테마 전환에 따라 같이 바뀌는지
- Pretendard 실제 렌더 (CDN)
- 800px 고정 폭, 375px에서 가로 스크롤 없음

### 1.2 서빙 + 피드백

```
python3 -m http.server 4321 --directory design
# → http://localhost:4321/mockup.html
```

확인 요청 항목 (이 목록대로 피드백 받는다)
- 본문 폰트 크기 / 행간 / 문단 간격
- 헤더 여백과 구분선 두께, 메뉴 간격
- 홈 목록에서 날짜 컬럼 폭과 정렬
- 라이트/다크 각각의 대비 (특히 `--muted` 가독성)
- 코드블록 배경이 페이지 배경과 분리되는 정도
- 링크 밑줄 유무, 링크 색
- 375px 폭에서의 헤더 줄바꿈 형태

### 1.3 반영

피드백 → 시안 수정 → 재확인. **확정될 때까지 반복하고, 그 사이 다른 단계는 시작하지 않는다.**
확정된 수치(px, 색, 간격)는 `spec.md` §4를 덮어써 최종본으로 만든다.

완료 조건
- [ ] 5개 화면 시안 완성, 로컬 서빙
- [ ] 사용자가 "확정" 의사 표시
- [ ] 확정 수치가 `spec.md` §4에 반영됨
- [ ] `design/mockup.html`은 참조용으로 커밋 (또는 폐기 — 확정 시 결정)

---

## 2단계 — 테마 제거 + 설정 재작성

**왜 한 단계로 묶나**: 테마를 지우면 기존 config의 stack 전용 키가 전부 무효가 된다.
따로 하면 중간에 빌드가 깨진 채로 남는다.

작업
1. 제거 (spec §6): `go.mod`, `go.sum`, `config/_default/module.toml`, `resources/_gen/`,
   `assets/scss/`, `assets/icons/`, `assets/jsconfig.json`, `assets/img/{avatar,profile}`,
   `content/page/{archives,search}/`, `.github/workflows/update-theme.yml`
2. `public/` 삭제 + `.gitignore`에 `public/`, `resources/`, `.hugo_build.lock` 추가
3. `config/_default/` 재작성 (spec §5): `config.toml`, `languages.toml`(`_` 제거),
   `markup.toml`, `menu.toml`, `params.toml`. `related.toml` 삭제, `permalinks.toml` 유지
4. `i18n/ko.toml`, `i18n/en.toml` 생성
5. `layouts/index.html`에 최소 스텁 1줄을 넣어 빌드가 통과하게 함

검증
- `hugo --gc` 성공 (경고 없이)
- `public/`에 `ko/`, `en/` 디렉터리가 생기고 루트 `index.html`이 `/ko/`로 리다이렉트

완료 조건
- [ ] 저장소에 외부 모듈 의존성 0
- [ ] 빌드 성공, 다국어 디렉터리 구조 생성 확인

주의: 이 커밋 이후 사이트는 스텁 상태다. `master`에 머지하지 않는다.

---

## 3단계 — 레이아웃 골격

**순서 원칙**: 바깥 → 안. baseof가 잡히기 전에 개별 페이지를 만들면 중복이 생긴다.

작업 순서
1. `_default/baseof.html` + `partials/head.html` (title/desc/canonical/OG/hreflang/RSS)
2. `partials/header.html` + `lang-switch.html` + `theme-toggle.html`(마크업만, JS는 4단계)
3. `partials/footer.html`
4. `index.html` — 홈 = 전체 글 목록 (페이지네이션 없음)
5. `post/single.html` + `partials/post-meta.html`
6. `page/single.html`
7. `_default/{list,terms}.html` — 태그/카테고리
8. `404.html`

이 단계에서는 **스타일 없이 구조만** 본다 (브라우저 기본 스타일).

검증
- `hugo server`로 8개 URL 전부 200: `/`, `/ko/`, `/en/`, `/ko/p/<slug>/`, `/ko/about/`,
  `/ko/tags/`, `/ko/tags/<tag>/`, 없는 URL → 404
- `.Translations`로 언어 토글 링크가 올바른 상대 URL을 뱉는지 (HTML 소스에서 직접 확인)
- `/ko/index.xml`, `/en/index.xml`이 유효한 RSS

완료 조건
- [ ] 모든 페이지 타입 렌더, 링크 전부 유효
- [ ] 내부 링크가 전부 `relURL`/`relLangURL` 기반 (절대 도메인 하드코딩 0)

---

## 4단계 — CSS + 테마 토글

**왜 3단계와 분리**: 마크업이 확정된 뒤 스타일을 얹어야 CSS가 마크업을 따라다니며 재작성되지 않는다.

작업
1. 1단계 시안 CSS를 `assets/css/main.css`로 이식. 시안에서 확정된 수치를 그대로 옮긴다
2. 컬러 토큰 **3중 정의** (spec §4.2) — `:root` / `@media` + `:not([data-theme=light])` / `[data-theme=dark]`
3. `</head>` 직전 FOUC 방지 인라인 스크립트
4. 테마 토글 JS (인라인, `try/catch`)
5. Pretendard CDN `<link>`
6. 반응형: `max-width: 640px` 브레이크포인트 1개
7. Hugo Pipes로 minify + fingerprint

검증 (조합 매트릭스 — 여기가 가장 틀리기 쉽다)
| OS 설정 | 저장값 | 기대 |
|---|---|---|
| light | 없음 | 라이트 |
| dark | 없음 | 다크 |
| dark | `light` | **라이트** |
| light | `dark` | **다크** |
- 다크 선택 후 새로고침 → 흰 화면 번쩍임 없음
- JS 비활성화 → auto로 정상 동작
- 375px에서 가로 스크롤 0

완료 조건
- [ ] 위 4개 조합 전부 통과
- [ ] FOUC 없음, JS off에서도 동작

---

## 5단계 — 코드 하이라이팅

작업
1. `scripts/gen-chroma.sh` 작성: latte는 그대로, mocha는 **두 스코프로 복제** emit (spec §4.3)
   - `@media (prefers-color-scheme:dark) html:not([data-theme=light]) ...`
   - `html[data-theme=dark] ...`
2. 실행 → `assets/css/chroma.css` 생성 후 **커밋** (빌드 시 hugo gen 호출하지 않음)
3. 인라인 코드 / `pre` 가로 스크롤 / 표 스크롤 스타일

검증
- Go, TOML, bash, diff 코드블록을 테스트 글에 넣고 라이트/다크 양쪽 확인
- **수동 토글**로 다크 전환 시 코드블록도 같이 바뀌는지 (`@media`만 있으면 여기서 실패한다)
- 긴 한 줄이 페이지를 밀지 않고 블록 안에서만 스크롤되는지

완료 조건
- [ ] 4개 언어 × 라이트/다크 × (OS전환/수동토글) 정상
- [ ] 페이지 가로 스크롤 0

---

## 6단계 — 콘텐츠 이관 + 다국어

작업
1. `content/post/redis-dist-lock/index.md` → `index.en.md`
   - front matter를 spec §2 규약으로 정리 (`slug` 명시, `author` 제거)
   - **본문 최상단 `# Redis-Based Distributed Locks...` h1 제거** (레이아웃이 title을 h1으로 그림)
2. `index.ko.md` 한글 번역본 작성 — `slug`는 en과 **동일**해야 언어 토글이 이어진다
3. `content/page/about/index.{ko,en}.md` — 기존 이력서 이관, stack 전용 front matter(`outputs`, `menu.params.icon`) 제거
4. `content/_index.{ko,en}.md` 생성 (본문 비움)
5. 번역본 없는 글의 동작 확인용으로 한쪽 언어만 있는 테스트 글 1개를 임시 생성 → 확인 후 삭제

검증
- `/ko/p/redis-dist-lock/` ↔ `/en/p/redis-dist-lock/` 토글 왕복
- 한쪽 언어만 있는 글: 반대 언어 목록에 안 뜨고, 토글은 홈으로 빠지는지
- 태그 페이지가 언어별로 분리되는지

완료 조건
- [ ] 글 1편 + about이 ko/en 양쪽 렌더
- [ ] 언어 토글 왕복 정상, 번역 누락 시 폴백 정상

---

## 7단계 — 도메인 + 배포 파이프라인

작업
1. `static/CNAME` 생성: `blog.engineerd.net` — **현재 저장소에 없어서 재배포 시 커스텀 도메인이
   풀릴 수 있다.** 이번에 반드시 넣는다
2. `deploy.yml` 정리: Go 셋업 제거, Node 셋업 제거, SCSS 미사용 시 Dart Sass 제거,
   `submodules: recursive` 제거. `--baseURL "${{ steps.pages.outputs.base_url }}/"`는 **유지**
3. `hugo --minify --baseURL https://blog.engineerd.net/` 로컬 실행 후 `public/CNAME` 존재 확인
4. 구 URL alias 여부 결정 (spec §10-3): `/p/redis-dist-lock/` → 새 URL

완료 조건
- [ ] `public/CNAME` 산출물에 포함
- [ ] 워크플로에서 불필요 스텝 제거 후에도 빌드 성공

---

## 8단계 — 최종 검수 후 배포

`spec.md` §9 체크리스트 전 항목 확인.

추가 확인
- `master` 머지 → Actions 성공
- 배포 후 `curl -sI https://chaewonkong.github.io/` → 301 → `blog.engineerd.net`
- `curl -sI https://blog.engineerd.net/` → 200, `/ko/`로 리다이렉트
- 실기기(모바일) 1회 확인
- `blog.engineerd.net` 기준 canonical이 모든 페이지에 존재

완료 조건
- [ ] spec §9 전 항목 통과
- [ ] 두 도메인 동작 확인
- [ ] `spec.md`가 최종 구현과 일치 (불일치 시 spec 갱신)

---

## 진행 원칙

- **1단계는 게이트**다. 시안 확정 없이 2단계로 가지 않는다.
- 2단계 이후는 각 단계 끝에서 커밋한다. 단계 중간 상태는 커밋하지 않는다.
- 각 단계의 검증을 통과하지 못하면 다음 단계로 넘어가지 않는다.
- 구현 중 스펙과 어긋나는 결정을 하면 `spec.md`를 먼저 고치고 진행한다. 코드가 스펙을 조용히 앞서가지 않게.
- `master` 머지는 8단계에서 한 번만.
