#!/usr/bin/env bash
# Build extra targets for make.  This includes targets that are a little tricky
# to build.  This includes all versions of the draft other than the latest: all
# tagged versions and the next version for submission.  As a result, it also
# includes diffs.

# Usage: $0 <tagfile> <outputfile> [drafts ...]

drafts=("$@")
candidates=$((${#drafts[@]} * 5))
versioned="${VERSIONED:-versioned}"
txt_html_warning="$(mktemp)"
today="$(date -u -I)"
trap 'rm -f "$txt_html_warning"' EXIT

next() {
    printf "${1%-*}-%2.2d" $((1${1##*-} - 99))
}

print_sed() {
    noop_cmd="$1"
    sed_cmd="$2"
    shift 2
    if [ $# -gt 0 ]; then
        printf "$sed_cmd"
    else
        printf "$noop_cmd"
    fi
    for s in "$@"; do
        printf " -e '$s'"
    done
}

# This builds a make target for a specific tag.
build_target() {
    tag="$1"
    target_name="$2"
    source_file=
    subst=()
    for file in $(git ls-tree --name-only "$tag" | grep '^draft-'); do
        if [ "${file##*.}" = "txt" -o "${file##*.}" = "html" ]; then
            echo "warning: $file is checked in at revision $tag" 1>&2
            rm -f "$txt_html_warning"
            continue
        fi
        if [ "${file%.*}" = "${target_name%-*}" ]; then
            source_file="$file"
            file_tag="$target_name"
        else
            # This is the last tag for the identified file at the tag we're
            # interested in.
            prev_file_tag=$(git describe --candidates="$candidates" --tags \
                                --match "${file%.*}-*" --abbrev=0 "$tag" 2>/dev/null)

            # No previous: -00, building for HEAD: next, otherwise use tag.
            if [ -z "$prev_file_tag" ]; then
                file_tag="${file%.*}-00"
            elif [ "$tag" = HEAD ]; then
                file_tag=$(next "$prev_file_tag")
            else
                file_tag="$prev_file_tag"
            fi
        fi
        tag_date=
        for k in tagger committer author; do
            [[ -n "$tag_date" ]] || \
                tag_date="$(TZ=UTC0 git tag --list --format '%('"$k"'date:short-local)' "$file_tag")"
        done
        subst+=("s/${file%.*}-date/${tag_date:-$today}/g")
        subst+=("s/${file%.*}-latest/${file_tag}/g")
    done

    if [ -z "$source_file" ]; then
        echo "warning: No file found at revision $tag for $target_name" 1>&2
        return
    fi

    # Rewrite includes in markdown.
    if [ "${source_file##*.}" = "md" ]; then
        subst+=('/^{::include [^\/]/{ s/^{::include /{::include '"$target_name"'\//; }')
    fi
    target="${target_name}.${source_file##*.}"
    if [ "${source_file##.*}" != "xml" ] || [ "$tag" = HEAD ]; then
        # Don't keep the temporary file (unless it is XML from a tag).
        printf ".INTERMEDIATE: ${versioned}/${target}\n"
    fi
    if [ "$tag" = HEAD ]; then
        printf "${versioned}/${target}: ${source_file} | ${versioned}\n"
        printf "\t"
        print_sed cat sed "${subst[@]}"
        printf " \$< >\$@\n"
    else
        # Keep the XML around for tagged builds (not HEAD).
        printf ".SECONDARY: ${versioned}/${target%.*}.xml\n"
        printf "${versioned}/${target}: | ${versioned}\n"
        printf "\tgit show \"$tag:$source_file\""
        print_sed '' ' | sed' "${subst[@]}"
        printf " >\$@\n"
    fi
    # Copy any includes into the versioned directory.
    # This is sloppy, because it doesn't set up proper dependencies.
    # To do that would require traversing all the files in this script.
    # This script already takes too long to run on larger repositories.
    # So just make a script that hacks.
    if [ "${source_file##*.}" = "md" ]; then
        printf '\tfor inc in $$(sed -ne '"'"'/^{::include [^\/]/{ s/^{::include '"$target_name"'\///;s/}$$//; p; }'"'"' $@); do \\\n'
        printf '\t  target='"$target_name"'/$$inc; \\\n'
        printf '\t  mkdir -p $$(dirname "$$target"); \\\n'
        printf '\t  git show "$$tag:$$inc" >"$$target" || \\\n'
        printf '\t    (echo "Attempting to make a copy of $$inc"; \\\n'
        if [ "$tag" = HEAD ]; then
            printf '\t     tmp=.; \\\n'
        else
            printf '\t     tmp=$$(mktemp -d); git clone . -b "$$tag" "$$tmp"; \\\n'
            printf '\t     ln -s "$(LIBDIR)" "$$tmp/$(LIBDIR)"; \\\n'
        fi
        printf '\t     make -C "$$tmp" "$$inc" && cp "$$tmp/$$inc" "$$target"; \\\n'
        if [ "$tag" != HEAD ]; then
            printf '\t     rm -rf "$$tmp"; \\\n'
        fi
        printf '\t  ); \\\n'
        printf '\tdone\n'
    fi
}

printf "${versioned}:\n"
printf "\t@mkdir -p \$@\n"

for draft in "${drafts[@]%.*}"; do
    if [ "${draft#draft-}" != "$draft" ]; then
        tags=($(git tag --list "${draft}-[0-9][0-9]"))
    else
        tags=($(git tag --list "$draft"))
    fi
    for i in "${tags[@]}"; do
        build_target "$i" "$i"
    done

    if [ "${#tags[@]}" -gt 0 ]; then
        next_draft=$(next "${tags[$((${#tags[@]}-1))]}")
    elif [ "${draft#draft-}" != "$draft" ]; then
        next_draft="${draft}-00"
    else
        next_draft=""
    fi
    if [ -n "$next_draft" ]; then
        build_target HEAD "$next_draft"

        if [ "${#tags[@]}" -gt 0 ]; then
            # Write out a diff target
            printf "diff-${draft}.html: ${versioned}/${tags[$((${#tags[@]}-1))]}.txt ${versioned}/${next_draft}.txt\n"
            printf "\t-\$(iddiff) \$^ > \$@\n"
        fi
    fi
done

if [ ! -e "$txt_html_warning" ]; then
    echo "warning: checked in txt or html files can cause issues" 1>&2
    echo "warning: remove these files with \`git rm\`" 1>&2
fi
