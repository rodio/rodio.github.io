#!/usr/bin/env fish

pushd posts
for filename in *.md
    set filename $(path basename -E $filename)
    echo processing $filename

    if not pandoc \
            -V homeurl=file:///Users/rodion/src/site/index.html \
            --template post-template.pd \
            -s -c style.css \
            --syntax-highlighting my.theme \
            $filename.md -o $filename.html
        echo "error in pandoc"
        exit 1
    end
end
popd

pushd feed-builder
if not cargo build -r
    echo "error in cargo"
    exit 1
end
popd

if not cp feed-builder/target/release/feed-builder ./feed-builder-exe
    echo "error in cp"
    exit 1
end

if not ./feed-builder-exe --html-dir=posts --base-url=https://rodio.codeberg.page/ --title="Rodion's Blog"
    echo "error in feed-builder-exe"
    exit 1
end
