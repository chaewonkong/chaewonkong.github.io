# chaewonkong.github.io

[blog.engineerd.net](https://blog.engineerd.net) — 매치메이킹과 분산 시스템에 대해 쓰는 블로그.

Hugo로 만들었고, 테마는 외부 의존성 없이 이 저장소가 직접 소유한다.

## 요구사항

Hugo **extended** 0.164.0 이상. 그 외 의존성은 없다 (Go, Node.js, Dart Sass 모두 불필요).

```sh
brew install hugo
```

## 개발

```sh
hugo server            # http://localhost:1313
hugo server -D         # 초안 포함
```

## 글쓰기

글은 페이지 번들이며, 한국어와 영어 두 벌을 같은 디렉터리에 둔다.

```
content/post/<slug>/
├── index.ko.md
├── index.en.md
└── cover.png          # 언어 공용 리소스
```

```yaml
---
title: "제목"
slug: "url-slug"       # 두 언어가 동일해야 언어 토글이 이어진다
date: 2026-08-30T10:00:00+09:00
description: "홈 목록에 요약으로 노출된다."
tags: [go, redis]
categories: [backend]
---
```

- 본문은 `##`부터 시작한다. `title`은 레이아웃이 h1으로 그린다.
- 한쪽 언어만 써도 된다. 반대 언어 목록에는 원문으로 노출되고, 글 상단에 안내 줄이 붙는다.

## 코드 하이라이팅

Catppuccin(Latte/Mocha). 생성물은 커밋되어 있으므로 테마를 바꿀 때만 다시 돌린다.

```sh
./scripts/gen-chroma.sh
```

## 배포

`master`에 푸시하면 GitHub Actions가 빌드해 GitHub Pages로 배포한다.
정식 주소는 `blog.engineerd.net`이며 `chaewonkong.github.io`는 그쪽으로 301된다.
커스텀 도메인은 `static/CNAME`이 유지한다.

## 문서

- [spec.md](spec.md) — 테마 스펙. 레이아웃, 타이포, 색, 다국어 구조와 그 결정 근거
- [plan.md](plan.md) — 교체 작업의 단계별 계획
- [design/mockup.html](design/mockup.html) — 확정된 수치의 근거가 된 디자인 시안
