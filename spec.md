# chaewonkong.github.io — 커스텀 Hugo 테마 스펙

기존 `hugo-theme-stack` 테마를 제거하고, 이 저장소 안에서 직접 관리하는
미니멀 테마(`layouts/` + `assets/`)로 교체한다.

레퍼런스: [antirez.com](https://antirez.com) — 장식 최소화, 텍스트 중심.

---

## 1. 목표 / 비목표

### 목표
- 외부 테마 의존성 0. 모든 레이아웃/스타일을 저장소가 직접 소유.
- 800px 고정 폭, 라이트/다크, Pretendard 단일 서체.
- 한국어/영어 콘텐츠 병행, 헤더에서 언어 토글.
- Chroma 기반 syntax highlighting (Catppuccin).

### 비목표 (이번 범위에서 제외)
- 댓글(utterances), 검색, 아카이브 페이지, 사이드바/아바타, 위젯
- JS 프레임워크, 번들러, npm 의존성
- 이미지 갤러리, 라이트박스, 목차(TOC), reading time, 라이선스 푸터

---

## 2. 정보 구조 / URL

다국어는 Hugo 내장 multilingual 사용. **두 언어 모두 서브패스**를 가진다.

```
config: defaultContentLanguage = "ko"
        defaultContentLanguageInSubdir = true
```

| URL | 내용 |
|---|---|
| `/` | `/ko/`로 리다이렉트 (Hugo가 자동 생성하는 root redirect) |
| `/ko/` | 한글 홈 = 전체 글 목록 |
| `/en/` | 영문 홈 = 전체 글 목록 |
| `/ko/p/<slug>/` | 한글 글 본문 |
| `/en/p/<slug>/` | 영문 글 본문 |
| `/ko/about/`, `/en/about/` | 소개 페이지 |
| `/ko/tags/<tag>/`, `/ko/categories/<cat>/` | 택소노미 목록 (영문도 동일) |
| `/ko/index.xml`, `/en/index.xml` | RSS 피드 |

- permalink: `post = "/p/:slug/"`, `page = "/:slug/"` (기존 유지)
- 헤더의 `posts` 메뉴는 해당 언어 홈(`/ko/`, `/en/`)을 가리킨다. 홈 자체가 글 목록이므로 별도 `/posts/` 페이지는 만들지 않는다.

### 콘텐츠 파일 배치

페이지 번들 + 언어 접미사. 같은 글의 두 언어는 **같은 디렉터리(= 같은 slug)** 를 공유한다.

```
content/
  _index.ko.md            # 한글 홈 (목록 레이아웃, 본문 비움)
  _index.en.md
  post/
    redis-dist-lock/
      index.ko.md
      index.en.md
      cover.png           # 언어 공용 리소스
  page/
    about/
      index.ko.md
      index.en.md
```

- 두 파일의 front matter `slug`는 반드시 동일하게 둔다. 언어 토글이 이 slug로 상대 URL을 찾는다.
- 한쪽 언어만 작성된 글은 그 언어 목록에만 노출된다.

### Front matter 규약

```yaml
---
title: "Redis 기반 분산 락과 Redlock 알고리즘"
slug: "redis-dist-lock"
date: 2025-03-13T23:00:25+09:00
lastmod: 2025-03-13T23:00:25+09:00
description: "한 줄 요약. OG/RSS에 사용."
tags: [redis, go, distributed-systems]
categories: [backend]
draft: false
---
```

`author`는 사이트 전역 설정으로 빼고 글에는 쓰지 않는다.

---

## 3. 레이아웃

### 3.1 공통 (baseof)

```
┌──────────────────────────────────────────────┐  <- 뷰포트
│      ┌────────────────────────────────┐      │
│      │ chaewonkong  posts about KO|EN ◐│     │  header
│      │────────────────────────────────│      │  1px hairline
│      │                                │      │
│      │            main                │      │  max-width 800px
│      │                                │      │
│      │────────────────────────────────│      │
│      │ © 2026 chaewonkong    rss github│     │  footer
│      └────────────────────────────────┘      │
└──────────────────────────────────────────────┘
```

**Header**
- 좌: `chaewonkong` — 현재 언어 홈으로 링크. 소문자 고정, 볼드.
- 우: `posts` · `about` · 언어 토글 `KO / EN` · 테마 토글 `◐`
- 언어 토글은 **항상 노출**. 현재 언어는 강조(진한 색), 다른 언어는 링크.
  - 대응 번역본이 있으면 → 그 글의 대응 URL (`.Translations` 사용)
  - 없으면 → 해당 언어의 홈(`/en/`)으로 이동
- 테마 토글은 맨 오른쪽 `<button>`. 상세는 §4.2
- 구분선: `border-bottom: 1px solid var(--border)` 한 줄. 배경색/그림자 없음.

**Footer**
- 한 줄. `© 2026 chaewonkong` + `rss` `github` 텍스트 링크. 아이콘 없음.

### 3.2 홈 = 글 목록 (`layouts/index.html`)

antirez 스타일. 연도 그룹 없이 최신순 평면 목록, **페이지네이션 없음**(전체 나열).
항목은 `날짜 / 제목 / 요약` 3줄 블록. 날짜는 제목 **위**에 둔다 (좌측 고정 컬럼 안은 폐기 — 요약이
붙으면서 본문 폭 손해 대비 이득이 적고, 모바일과 데스크톱 모양이 갈렸다).

```
30 Aug 2026
Redis 기반 분산 락과 Redlock 알고리즘
SET NX PX 한 줄에서 시작해 Redlock까지, 분산 락이 조용히 정확성을 잃는 지점들.

12 Jul 2026
매치메이킹 큐를 다시 설계하며 배운 것들
대기 시간과 매칭 품질은 같은 노브의 양 끝이다. 세 번의 리라이트에서 남은 기록.
```

| 요소 | 값 |
|---|---|
| 날짜 | `0.8125rem`, `--muted`, `tabular-nums`, `margin-bottom: 3px` |
| 제목 | `1.125rem` / weight 600 / `line-height 1.45` / `letter-spacing -0.012em` / `--fg`, 밑줄 없음(hover 시 밑줄) |
| 요약 | front matter `description`. `0.9rem` / `line-height 1.6` / `--muted` / `margin-top: 5px` |
| 항목 간격 | `padding: 15px 0` (모바일 13px), 첫 항목은 `padding-top: 0`. 구분선 없음 |
| 모바일 | 제목 `1.0625rem`. 구조는 데스크톱과 동일 |

- 썸네일·태그는 목록에 노출하지 않는다.
- `description`이 비어 있으면 요약 줄 자체를 렌더하지 않는다 (`.Description` 존재 여부로 분기).

### 3.3 글 본문 (`layouts/post/single.html`)

```
제목 (h1)
30 Aug 2026 · redis, go, distributed-systems      <- --muted, small

본문 …

──────────────────────────────
← 이전 글 / 다음 글 (선택)
```

- 본문 상단에 `title`을 h1으로 렌더하므로, 마크다운 본문은 `##`부터 시작한다.
  (기존 `redis-dist-lock` 글의 최상단 `# ...` 헤딩은 제거 필요)
- 태그는 메타 줄에 쉼표 구분 텍스트 링크로만.

### 3.4 택소노미 (`layouts/_default/terms.html`, `list.html`)

- terms: 태그 이름 + 글 수를 한 줄씩. 워드클라우드 없음.
- list: 홈과 동일한 `날짜 — 제목` 목록.

### 3.5 소개 (`layouts/page/single.html`)

제목 + 본문만. 기존 이력서 마크다운 내용을 그대로 옮긴다.

### 3.6 그 외
- `404.html`: 한 줄 텍스트 + 홈 링크.
- `head`: title / description / canonical / OG / Twitter card / `alternate` hreflang(ko·en) / RSS `alternate`.

---

## 4. 스타일

`assets/css/main.css` 단일 파일(또는 SCSS 1개). Hugo Pipes로 minify + fingerprint.

### 4.1 레이아웃 / 타이포

| 항목 | 값 |
|---|---|
| 콘텐츠 폭 | `max-width: 800px; margin: 0 auto;` |
| 좌우 여백 | 데스크톱 `padding: 0 24px`, 모바일 `0 16px` |
| 본문 크기 | 16px / `line-height: 1.7` |
| 모바일 본문 | 16px 유지 (iOS 자동 확대 방지) |
| 서체 | Pretendard 단일. `font-family: Pretendard, sans-serif` |
| 코드 서체 | Pretendard에 고정폭이 없으므로 `ui-monospace, SFMono-Regular, Menlo, monospace` 사용 |
| 헤딩 | h1 1.6rem / h2 1.25rem / h3 1.05rem. 굵기 600. 장식선 없음 |
| 사이트 제목(brand) | `1.3125rem` / weight 600 / `letter-spacing -0.02em` / `--fg` |
| 헤더 ↔ 본문 간격 | `main { padding-top: 64px }` (모바일 44px). 헤더 자체는 `padding: 24px 0 16px` |

> **주의**: `.wrap`의 좌우 여백은 반드시 `padding-left` / `padding-right` **longhand**로 쓴다.
> `padding: 0 var(--pad)` 단축 속성을 쓰면 `.wrap`(클래스, 명시도 0-1-0)이 `main`(태그, 0-0-1)의
> `padding-top`을 순서와 무관하게 덮어써서 헤더와 본문이 붙는다. 시안에서 실제로 겪은 버그다.
| 링크 | 밑줄 유지(`text-decoration: underline`), 색은 본문색 또는 `--link`. hover 시 색 변화만 |

**Pretendard 로딩**: jsDelivr의 dynamic-subset CSS를 `<link>`로 로드.
```
https://cdn.jsdelivr.net/gh/orioncactus/pretendard/dist/web/variable/pretendardvariable-dynamic-subset.min.css
```
(CDN 의존이 싫으면 woff2를 `static/fonts/`에 self-host + `@font-face` 직접 선언 — 열린 질문 참조)

### 4.2 컬러 토큰

라이트를 기본으로 `:root`에 정의하고, 다크는 **OS 설정**과 **수동 선택** 두 경로로 적용한다.

| 토큰 | Light | Dark |
|---|---|---|
| `--bg` | `#ffffff` | `#000000` |
| `--fg` | `#111111` | `#e6e6e6` |
| `--muted` | `#6b6b6b` | `#8a8a8a` |
| `--border` | `#e5e5e5` | `#222222` |
| `--link` | `#0b57d0` | `#7aa2f7` |
| `--code-bg` | `#eff1f5` (latte) | `#1e1e2e` (mocha) |

#### 다크모드 전환 (OS 추종 + 수동 토글)

3상태: `auto`(기본) → `light` → `dark` → `auto` 순환. 선택값은 `localStorage.theme`에 저장하며,
`auto`일 때는 키를 지운다. 상태는 `<html data-theme="light|dark">` 속성으로 표현하고, `auto`면 속성 없음.

CSS는 **한 토큰당 세 곳**에 쓴다. 순서가 곧 우선순위다.

```css
:root                       { --bg:#fff; --fg:#111; ... }          /* 라이트 기본 */
@media (prefers-color-scheme: dark) {
  html:not([data-theme="light"]) { --bg:#000; --fg:#e6e6e6; ... }  /* OS 다크 (수동 light가 이김) */
}
html[data-theme="dark"]     { --bg:#000; --fg:#e6e6e6; ... }       /* 수동 dark (OS 라이트여도 이김) */
```

FOUC 방지를 위해 `</head>` 직전에 **인라인·동기 스크립트**를 둔다 (외부 파일 금지):

```html
<script>try{var t=localStorage.theme;if(t==="light"||t==="dark")document.documentElement.dataset.theme=t}catch(e){}</script>
```

토글 버튼 (`partials/theme-toggle.html`):
- 마크업은 `<button id="theme-toggle" type="button" aria-label="...">`, 라벨은 현재 상태에 따라 `◐`(auto) / `☀`(light) / `☾`(dark).
- JS는 헤더 하단의 짧은 인라인 스크립트 한 덩어리. 별도 JS 번들/Hugo Pipes 불필요.
- `localStorage` 접근은 전부 `try/catch` (프라이빗 모드에서 throw 가능).
- 버튼 스타일: `background:none; border:0; color:var(--muted); cursor:pointer` — 다른 헤더 링크와 같은 크기.
- JS가 꺼져 있어도 `auto`(OS 추종)로 정상 동작한다. 버튼만 무반응.

- 인용문(`blockquote`)은 좌측 2px `--border` 라인 + `--muted` 텍스트.
- 이미지: `max-width: 100%; height: auto;`

### 4.3 코드 블록 / 하이라이팅

```toml
[markup.highlight]
  noClasses  = false     # CSS 클래스 방식 (다크모드 전환에 필수)
  codeFences = true
  guessSyntax = false
  lineNos    = false     # 미니멀 유지 위해 줄번호 끔
  tabWidth   = 4
```

- Catppuccin은 Hugo(Chroma)에 내장되어 있음 — 확인 완료:
  - `hugo gen chromastyles --style=catppuccin-latte  > assets/css/chroma-light.css`
  - `hugo gen chromastyles --style=catppuccin-mocha > assets/css/chroma-dark.css`
- 수동 토글이 있으므로 dark 규칙은 §4.2와 **같은 두 스코프로 복제**해야 한다. `scripts/gen-chroma.sh`가
  latte는 그대로, mocha는 각 셀렉터에 prefix를 붙여 두 벌로 emit한다.
  ```css
  .chroma .k { color:#8839ef }                                   /* latte */
  @media (prefers-color-scheme: dark) {
    html:not([data-theme="light"]) .chroma .k { color:#cba6f7 }   /* mocha */
  }
  html[data-theme="dark"] .chroma .k { color:#cba6f7 }            /* mocha */
  ```
  생성 결과 `assets/css/chroma.css`는 **커밋**한다 (빌드 시 hugo gen 호출하지 않음).
- 코드 블록 배경은 페이지 배경(#fff/#000)과 다른 Catppuccin 배경을 그대로 사용해 블록 구분감을 준다.
- 가로 스크롤: `pre { overflow-x: auto; }` — 페이지 자체는 절대 가로 스크롤되지 않는다.
- 인라인 코드: `--code-bg` 배경 + `0.1em 0.35em` 패딩, `font-size: 0.9em`.
- 코드블록: `font-size: 0.9375rem` (15px), `line-height: 1.6`, `padding: 16px 18px`, `border-radius: 4px`.
- **마크업 주의**: Chroma는 줄 개행을 `<span class="cl">` **안쪽**에 넣고 `.line` 스팬을 공백 없이
  이어 붙인다. `.chroma .line { display:flex }`이므로, 개행이 스팬 바깥에 있으면 flex 줄박스와
  개행이 각각 한 줄을 차지해 줄간격이 두 배로 보인다. 손으로 코드블록 HTML을 쓸 일이 있으면 주의.

### 4.4 모바일
- `<meta name="viewport" content="width=device-width, initial-scale=1">`
- 브레이크포인트 1개(`max-width: 640px`)만 사용.
- 헤더: 640px 이하에서 제목 줄 / 메뉴 줄 2단으로 wrap (햄버거 메뉴 없음).
- 테이블은 `overflow-x: auto` 컨테이너로 감싼다.

---

## 5. 설정 변경 (`config/_default/`)

| 파일 | 조치 |
|---|---|
| `module.toml` | **삭제** (테마 모듈 import 제거) |
| `params.toml` | stack 전용 파라미터 전부 삭제. `mainSections`, `rssFullContent`, footer 정보만 남김 |
| `menu.toml` | `[[main]]`에 posts / about 등록. social 링크는 `params.social`로 이동 |
| `markup.toml` | 위 4.3 highlight 설정으로 교체. passthrough(LaTeX) 제거, TOC 설정 제거 |
| `_languages.toml` | → `languages.toml`로 이름 변경, `[ko]`(weight 1) / `[en]`(weight 2) 정의 |
| `config.toml` | `title = "chaewonkong"`, `baseurl = "https://blog.engineerd.net/"`, `defaultContentLanguage = "ko"`, `defaultContentLanguageInSubdir = true`, `hasCJKLanguage = true`, 미사용 항목 정리 |
| `related.toml`, `permalinks.toml` | related는 삭제, permalinks는 유지 |

`i18n/ko.toml`, `i18n/en.toml`에 UI 문자열(`posts`, `about`, `tags`, `no_posts` 등)을 둔다.

### 5.1 도메인 (blog.engineerd.net + chaewonkong.github.io)

현재 상태를 확인한 결과:

```
$ curl -sI https://chaewonkong.github.io/
HTTP/2 301
location: https://blog.engineerd.net/
$ curl -sI https://blog.engineerd.net/
HTTP/2 200
```

GitHub Pages에 커스텀 도메인이 이미 설정되어 있어, `chaewonkong.github.io`는 **301로
`blog.engineerd.net`에 넘긴다.** 저장소 하나로 두 도메인이 동시에 200을 반환하게 만들 수는 없다
(GitHub Pages의 강제 동작이며, SEO 관점에서도 canonical이 하나인 편이 맞다).
따라서 "두 도메인 모두 사용"은 **둘 다 접근 가능 / 정식 주소는 `blog.engineerd.net`** 으로 구현한다.

지켜야 할 것:

- `static/CNAME`에 `blog.engineerd.net` 한 줄을 커밋한다. 현재 저장소에 CNAME 파일이 **없어서**
  Pages 설정에만 의존하고 있는데, 이 상태는 재배포 시 커스텀 도메인이 풀릴 수 있다.
- `deploy.yml`의 `--baseURL "${{ steps.pages.outputs.base_url }}/"`는 그대로 둔다.
  `actions/configure-pages`는 커스텀 도메인이 설정된 경우 그 값(`https://blog.engineerd.net/`)을 반환한다.
- 템플릿 내부 링크는 전부 `relURL` / `relLangURL`로 생성해 도메인에 비종속으로 만든다.
- 절대 URL이 필요한 곳(`canonical`, OG `og:url` / `og:image`, RSS `<link>`, `hreflang`)만
  `absURL` / `.Permalink`를 쓴다 → 자동으로 `blog.engineerd.net` 기준이 된다.
- `<link rel="canonical">`을 모든 페이지에 넣어, 혹시 github.io로 접근된 경우에도 정식 주소를 가리키게 한다.

---

## 6. 제거 대상

```
go.mod, go.sum                 # 테마가 유일한 의존성이므로 삭제
config/_default/module.toml
resources/_gen/                # 테마 SCSS 캐시
assets/scss/custom.scss        # stack 전용
assets/icons/, assets/jsconfig.json
assets/img/avatar.png, profile.jpg   # 사이드바 아바타 (favicon만 유지)
public/                        # 빌드 산출물 — 삭제 후 .gitignore에 추가
.github/workflows/update-theme.yml   # 테마 업데이트 자동화 불필요
content/page/archives/, content/page/search/
```

`.github/workflows/deploy.yml`은 유지하되 Go / Node.js 셋업 스텝을 제거한다
(Hugo extended + Dart Sass만 남김. SCSS를 쓰지 않으면 Dart Sass도 제거 가능).

---

## 7. 최종 파일 트리 (목표)

```
.
├── config/_default/
│   ├── config.toml
│   ├── languages.toml
│   ├── markup.toml
│   ├── menu.toml
│   ├── params.toml
│   └── permalinks.toml
├── i18n/
│   ├── ko.toml
│   └── en.toml
├── layouts/
│   ├── _default/
│   │   ├── baseof.html
│   │   ├── list.html          # 택소노미 목록
│   │   ├── single.html
│   │   └── terms.html
│   ├── partials/
│   │   ├── head.html
│   │   ├── header.html
│   │   ├── footer.html
│   │   ├── lang-switch.html
│   │   ├── theme-toggle.html
│   │   └── post-meta.html
│   ├── post/single.html
│   ├── page/single.html
│   ├── index.html             # 홈 = 글 목록
│   └── 404.html
├── assets/css/
│   ├── main.css
│   └── chroma.css             # 생성물 (light + dark @media)
├── scripts/gen-chroma.sh
├── content/
│   ├── _index.{ko,en}.md
│   ├── post/<slug>/index.{ko,en}.md
│   └── page/about/index.{ko,en}.md
├── static/
│   ├── CNAME                  # blog.engineerd.net
│   └── favicon.png
└── spec.md
```

---

## 8. 작업 순서

1. 테마 모듈 및 잔여 파일 제거 (§6), `public/` gitignore 처리
2. `config/` 재작성 + `i18n/` 추가 → `hugo` 빌드가 에러 없이 도는지 확인
3. `layouts/` 골격 작성 (baseof → header/footer → index)
4. `assets/css/main.css` 작성, 토큰 3중 정의(§4.2) 및 라이트/다크 검증
5. 테마 토글 partial + FOUC 방지 인라인 스크립트 추가
6. `scripts/gen-chroma.sh`로 chroma.css 생성, 코드블럭 확인
7. 기존 글 1편(`redis-dist-lock`)을 `index.en.md`로 이관 + `index.ko.md` 번역본 작성
8. about 페이지 ko/en 이관
9. `static/CNAME` 추가 (§5.1)
10. 모바일(375px) / 데스크톱 확인, 언어 토글·테마 토글 왕복 확인
11. `deploy.yml` 정리 후 배포

---

## 9. 완료 기준

- [ ] `themes/`, `go.mod`, 외부 모듈 의존성이 저장소에 없다
- [ ] `hugo --gc --minify`가 경고 없이 성공한다
- [ ] `/` → `/ko/` 리다이렉트, `/ko/`·`/en/` 모두 글 목록을 보여준다
- [ ] 글 페이지에서 KO↔EN 토글이 같은 글의 반대 언어로 이동한다
- [ ] OS를 다크로 바꾸면 배경이 `#000`, 코드블럭이 Catppuccin Mocha로 바뀐다
- [ ] 테마 토글이 auto → light → dark → auto로 순환하고, 새로고침 후에도 선택이 유지된다
- [ ] OS가 다크여도 수동으로 light를 고르면 라이트가 유지된다 (그 반대도)
- [ ] 다크 선택 상태로 새로고침해도 흰 화면이 번쩍이지 않는다 (FOUC 없음)
- [ ] `static/CNAME`이 배포에 포함되어 `blog.engineerd.net`이 계속 200을 반환한다
- [ ] `chaewonkong.github.io`가 `blog.engineerd.net`으로 301된다
- [ ] 모든 페이지에 `blog.engineerd.net` 기준 `canonical`이 있다
- [ ] 375px 폭에서 가로 스크롤이 발생하지 않는다
- [ ] 전체 페이지 폰트가 Pretendard 하나(코드 제외)로 렌더된다
- [ ] `/ko/index.xml`, `/en/index.xml`이 유효한 RSS를 반환한다

---

## 10. 열린 질문

1. **Pretendard 로딩** — jsDelivr CDN(간편, 외부 의존) vs `static/fonts/` self-host(오프라인·프라이버시, 저장소 ~1MB). 기본안은 CDN.
2. **사이트 제목 표기** — 헤더는 `chaewonkong`으로 확정. `<title>` / OG / RSS의 사이트명도 `chaewonkong`으로 통일할지, `Chae Won Kong`을 유지할지.
3. **기존 URL 호환** — 현재 배포된 글 URL은 `/p/redis-dist-lock/`. 새 구조에서는 `/ko/p/...`, `/en/p/...`가 된다. 구 URL용 alias를 front matter `aliases`로 남길지.
4. **번역본 없는 글의 노출** — 현재 스펙은 "해당 언어 목록에만 노출". 목록에는 띄우되 본문에서 "이 글은 한국어만 있습니다" 안내를 띄우는 방식도 가능.

---

## 11. 결정 로그

| 항목 | 결정 |
|---|---|
| 다국어 URL | `/ko/`, `/en/` 둘 다 서브패스, `/`는 `/ko/`로 리다이렉트 |
| 유지 기능 | RSS, 태그/카테고리 (댓글·검색·아카이브는 제거) |
| 홈 | 전체 글 목록 (antirez 스타일), 페이지네이션 없음 |
| 언어 토글 | 헤더 우측 `KO / EN` 항상 노출 |
| 테마 토글 | 헤더 우측 버튼, auto/light/dark 3상태 + localStorage |
| 도메인 | 정식 `blog.engineerd.net`, `chaewonkong.github.io`는 301 유입 |
