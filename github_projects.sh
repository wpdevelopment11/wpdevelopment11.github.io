#!/bin/bash

set -u

#curl -H "Accept: application/vnd.github+json"   https://api.github.com/repos/wpdevelopment11/blocks/readme | jq -r .content | base64 -d | head -n 1

github_api() {
    endpoint=$1
    curl -fH 'Accept: application/vnd.github+json' \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -x 127.0.0.1:9998 \
    "https://api.github.com/$endpoint"
}

output_dir="projects"
hide='
[
    "checknew",
    "community-content",
    "wpdevelopment11",
    "xray-tutorial"
]'

if ! resp=$(github_api users/wpdevelopment11/repos); then
    echo "GitHub error: can't fetch repos" >&2
    echo "$resp" >&2
    exit 1
fi

# shellcheck disable=SC2016
while read -r proj; do
    name=$(jq -r .name <<< "$proj")
    desc=$(jq -r .description <<< "$proj")

    if ! resp=$(github_api "repos/wpdevelopment11/$name/readme"); then
        echo "GitHub error: can't fetch the '$name' project README" >&2
        echo "$resp" >&2
        exit 1
    fi

    title=$(jq -r .content <<< "$resp" | base64 -d | head -n 1)
    title=${title#'# '}

    if ! resp=$(github_api "repos/wpdevelopment11/$name/languages"); then
        echo "GitHub error: can't fetch the '$name' project languages" >&2
        echo "$resp" >&2
        exit 1
    fi

    languages=$(jq -c '. | keys' <<< "$resp")

    frontmatter_toml=$(jq --arg title "$title" --argjson languages "$languages" '.title = ($title | trim) | .languages = $languages' <<< "$proj" | yq -o toml . -)

    mkdir -p "$output_dir/$name"

    output_file="$output_dir/$name/index.md"
    cat <<EOF > "$output_file"
+++
$frontmatter_toml
+++

## $title

$desc

EOF
done < <(jq -c --argjson hide "$hide" '.[] | select(any(.name == $hide[]; .) | not) | {name, title: .name, description, repo_url: .html_url, date: .created_at}' <<< "$resp")
