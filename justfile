# 레시피 목록
default:
    @just --list --unsorted

# 새 글 (예: just new redis-cluster-lua)
new SLUG:
    @hugo new content post/{{SLUG}}
    @echo ""
    @echo "  content/post/{{SLUG}}/index.ko.md"
    @echo "  content/post/{{SLUG}}/index.en.md"
    @echo ""
    @echo "  slug와 date는 채워져 있다. title/description을 쓰고 draft를 지우면 발행된다."
    @echo "  한 언어만 쓸 거면 나머지 파일은 지워도 되고, draft로 남겨둬도 배포되지 않는다."

# 개발 서버 (초안 포함)
serve:
    hugo server -D

# 프로덕션과 동일한 빌드
build:
    hugo --gc --minify --baseURL "https://blog.engineerd.net/"

# Catppuccin 코드 하이라이팅 CSS 재생성 (테마를 바꿀 때만)
chroma:
    ./scripts/gen-chroma.sh

# 빌드 산출물 제거
clean:
    rm -rf public resources .hugo_build.lock
