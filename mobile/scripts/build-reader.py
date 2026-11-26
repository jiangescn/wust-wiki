"""Package Wiki's generated article components and assets for Android's local renderer."""
import json
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

mobile = Path(__file__).resolve().parents[1]
site = mobile.parent / ".output/public"
catalog = json.loads((mobile / "assets/native.json").read_text(encoding="utf-8"))["articles"]
native = {"/study/clubs", "/navigation", "/study/status", "/study/curriculum", "/study/grades", "/study/contest", "/life/nearby"}
routes = sorted(set(catalog) - native | {"/previews/example"})
output = mobile / "android/app/src/main/assets/wiki-reader.zip"
with ZipFile(output.with_suffix(".partial"), "w", compression=ZIP_DEFLATED) as bundle:
    for name in ("_nuxt", "_fonts", "fonts", "images", "__nuxt_content", "raw"):
        for file in sorted((site / name).rglob("*")):
            if file.is_file() and file.suffix not in (".map", ".apk"):
                bundle.write(file, file.relative_to(site).as_posix())
    for name in ("favicon.svg", "xiyou-channel-qr.svg"):
        bundle.write(site / name, name)
    for route in routes:
        folder = site / route.lstrip("/")
        html = (folder / "index.html").read_text(encoding="utf-8")
        target = ("main.blog-showcase" if route in ("/blog-components", "/previews/example")
                  else "main.xupt-coder-page" if route in ("/coder", "/coder/blog")
                  else "article.md-tech")
        style = f"""<style id="app-article">
        #__nuxt:has({target}) > :not(:has({target})):not({target}),
        #__nuxt :has({target}) > :not(:has({target})):not({target}) {{display:none!important}}
        #__nuxt :has({target}) {{margin:0!important;padding:0!important;min-height:0!important;display:block!important}}
        article.md-tech {{padding:8px 16px 32px}}
        .dormitory-lookup,.bed-demo {{display:none!important}}
        .blog-showcase article.md-tech {{padding:0}} .showcase-header,.xupt-coder-page .wiki-breadcrumbs {{display:none!important}}
        html {{scroll-padding-top:8px;background:#fafafa;color-scheme:light}}
        html.dark {{background:#1b1b1f;color-scheme:dark}}
        body {{background:inherit}}
        .blog-showcase .showcase-layout {{min-width:0}}
        .blog-showcase :is(.showcase-main,.showcase-aside) {{max-width:100%}}
        .app-component-tools {{display:flex;justify-content:flex-end;margin:.25rem 0}}
        button.app-component-action {{
          box-sizing:border-box;min-height:44px;padding:.25rem .75rem;border:1px solid var(--c-border);
          border-radius:.75rem;background:var(--c-bg-1);color:var(--c-primary);font:inherit;font-size:.875rem
        }}
        button.app-component-action:active {{background:var(--c-primary-soft)}}
        @media (prefers-reduced-motion:reduce) {{
          .blog-components * {{animation-duration:0s!important;transition-duration:0s!important}}
        }}
        </style>"""
        # Nuxt restores its own interactive Vue tree. Keep both its SSR markup and route payload.
        html = html.replace("</head>", style + '<script src="/app-reader.js"></script></head>', 1)
        bundle.writestr(route.lstrip("/") + "/index.html", html)
        bundle.write(folder / "_payload.json", route.lstrip("/") + "/_payload.json")
    bundle.write(mobile / "scripts/reader-links.js", "app-reader.js")
output.with_suffix(".partial").replace(output)
print(f"{len(routes)} article routes in {output.name}, {output.stat().st_size:,} bytes")
