#!/usr/bin/env python3
"""
render_readme_896px.py - Render README.md at GitHub's exact 896px container width
using Playwright and take a full-page Retina screenshot.
"""

from pathlib import Path
import base64
import markdown
from playwright.sync_api import sync_playwright

REPO_ROOT = Path(__file__).resolve().parent.parent
README_PATH = REPO_ROOT / "README.md"
OUTPUT_PATH = REPO_ROOT / "assets" / "readme_rendered_896px.png"

# Read markdown
md_text = README_PATH.read_text(encoding="utf-8")

# Embed local images as base64 data URIs so Playwright renders them reliably offline
md_text_patched = md_text
for img_file in (REPO_ROOT / "assets").glob("*.png"):
    data_b64 = base64.b64encode(img_file.read_bytes()).decode("utf-8")
    md_text_patched = md_text_patched.replace(f'src="assets/{img_file.name}"', f'src="data:image/png;base64,{data_b64}"')

# Convert markdown to HTML
html_body = markdown.markdown(
    md_text_patched,
    extensions=["tables", "fenced_code", "attr_list"]
)

full_html = f"""<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  * {{ box-sizing: border-box; }}
  body {{
    background: #0d1117;
    color: #e6edf3;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Noto Sans", Helvetica, Arial, sans-serif;
    font-size: 16px;
    line-height: 1.5;
    word-wrap: break-word;
    margin: 0;
    padding: 32px 16px;
    display: flex;
    justify-content: center;
  }}
  .markdown-body {{
    width: 896px;
    max-width: 896px;
    background: #0d1117;
    padding: 0 16px;
  }}
  h1, h2, h3, h4, h5, h6 {{
    margin-top: 24px;
    margin-bottom: 16px;
    font-weight: 600;
    line-height: 1.25;
    color: #f0f6fc;
  }}
  h1 {{ font-size: 2em; padding-bottom: 0.3em; border-bottom: 1px solid #21262d; }}
  h2 {{ font-size: 1.5em; padding-bottom: 0.3em; border-bottom: 1px solid #21262d; }}
  h3 {{ font-size: 1.25em; }}
  p {{ margin-top: 0; margin-bottom: 16px; }}
  hr {{
    height: 0.25em;
    padding: 0;
    margin: 24px 0;
    background-color: #30363d;
    border: 0;
  }}
  table {{
    border-spacing: 0;
    border-collapse: collapse;
    display: block;
    width: max-content;
    max-width: 100%;
    overflow: auto;
    margin-top: 0;
    margin-bottom: 16px;
  }}
  table th {{
    font-weight: 600;
    padding: 6px 13px;
    border: 1px solid #30363d;
    background-color: #161b22;
  }}
  table td {{
    padding: 6px 13px;
    border: 1px solid #30363d;
  }}
  table tr:nth-child(2n) {{
    background-color: #161b22;
  }}
  code {{
    padding: 0.2em 0.4em;
    margin: 0;
    font-size: 85%;
    white-space: break-spaces;
    background-color: rgba(110,118,129,0.4);
    border-radius: 6px;
    font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace;
  }}
  pre {{
    padding: 16px;
    overflow: auto;
    font-size: 85%;
    line-height: 1.45;
    color: #e6edf3;
    background-color: #161b22;
    border-radius: 6px;
    margin-bottom: 16px;
  }}
  pre code {{
    background-color: transparent;
    padding: 0;
  }}
  img {{
    max-width: 100%;
    box-sizing: content-box;
    border-radius: 6px;
  }}
  ul, ol {{
    padding-left: 2em;
    margin-top: 0;
    margin-bottom: 16px;
  }}
  li {{ margin-top: 0.25em; }}
  a {{ color: #4493f8; text-decoration: none; }}
  a:hover {{ text-decoration: underline; }}
</style>
</head>
<body>
  <div class="markdown-body">
    {html_body}
  </div>
</body>
</html>
"""

def render():
    print("=== Rendering README.md at 896px GitHub Column Width ===")
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page(
            viewport={"width": 896, "height": 1200},
            device_scale_factor=2
        )
        page.set_content(full_html, wait_until="networkidle")
        # Give images a moment to decode
        page.wait_for_timeout(500)
        page.screenshot(path=str(OUTPUT_PATH), full_page=True)
        browser.close()
    
    size_mb = OUTPUT_PATH.stat().st_size / (1024 * 1024)
    print(f"[SUCCESS] Rendered full-page README -> {OUTPUT_PATH} ({size_mb:.2f} MB)")

if __name__ == "__main__":
    render()
