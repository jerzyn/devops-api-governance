"""Write the FOST London deck as Slides-artifact files.

Usage: build_deck.py <out-dir>
Writes <out-dir>/project/deck.json and <out-dir>/project/slides/<id>.html.
Content follows presentation/deck-plan.md; asset urls come from
presentation/assets/uploads.json.
"""
import json
import re
import sys
from datetime import datetime, timezone
from html import escape
from pathlib import Path

HERE = Path(__file__).resolve().parent
UPLOADS = json.loads((HERE.parent / "assets" / "uploads.json").read_text())

# Palette (deck-plan.md "Design")
NAVY = "#323a4d"
NAVY_DEEP = "#1b2030"
LIGHT = "#fbfbf8"
BEIGE = "#ede3da"
BEIGE_TEXT = "#e3cdb8"
INK = "#1f2533"
MUTED = "#4a5263"
ACCENT_ON_LIGHT = "#13709a"
ACCENT_ON_DARK = "#7cc8ea"
FADED = "#9aa2b5"
RED = "#c0392b"
GREEN = "#2e8b57"

HEAD = "'Merriweather', Georgia, serif"
BODY = "'Roboto', Arial, sans-serif"
MONO = "'JetBrains Mono', 'Courier New', monospace"

STEPS = ["catalog", "guidelines", "contracts", "gateway", "breaking"]


def asset(name):
    return UPLOADS[name]


def section(sid, bg, body, notes, color=INK, extra_style="", attrs=""):
    # Slide text never ends with a period (titles, subtitles, one-line statements).
    body = re.sub(r"\.(</(?:p|h1|h2|h3|li|b|span)>)", r"\1", body)
    style = (f"background:{bg}; color:{color}; font-family:{BODY}; "
             f"padding:128px; display:flex; flex-direction:column; gap:40px; {extra_style}")
    return (f'<section id="{sid}" data-transition="fade"{attrs} style="{style}">\n'
            f"{body}\n<aside>{escape(notes)}</aside>\n</section>\n")


def eyebrow(text, color):
    return (f'<p style="font-family:{BODY}; font-size:28px; font-weight:700; '
            f'letter-spacing:3px; text-transform:uppercase; color:{color}">{text}</p>')


def h1(text, color, size=88):
    return (f'<h1 style="font-family:{HEAD}; font-size:{size}px; font-weight:700; '
            f'line-height:1.15; color:{color}">{text}</h1>')


def h2(text, color=INK, size=64):
    return (f'<h2 style="font-family:{HEAD}; font-size:{size}px; font-weight:700; '
            f'line-height:1.15; color:{color}">{text}</h2>')


def p(text, size=32, color=INK, extra=""):
    return f'<p style="font-size:{size}px; line-height:1.4; color:{color}; {extra}">{text}</p>'


# Code colors on the navy code card (all >= 4.5:1 on #323a4d)
C_KEY = "#7cc8ea"      # keys, rule ids
C_STR = "#a8e0a0"      # strings, names in backticks
C_LIT = "#f5c27a"      # numbers, booleans, success status
C_ERR = "#f28b82"      # errors, failure status
C_DIM = "#9aa2b5"      # comments, prompts
C_CMD = "#d7b8f3"      # commands, HTTP methods

_TOKENS = {
    "yaml": [
        (r"#.*$", C_DIM),
        (r"^\s*[\w$./-]+(?=:)", C_KEY),
        (r"(?<=[{,]\s)[\w-]+(?=:)", C_KEY),
        (r'"[^"]*"', C_STR),
        (r"\b(?:true|false|\d+)\b", C_LIT),
    ],
    "shell": [
        (r"#.*$", C_DIM),
        (r"^\$", C_DIM),
        (r"\bcurl\b", C_CMD),
        (r"\b404 Not Found\b", C_ERR),
        (r"\b200 OK\b", C_LIT),
        (r'"[\w]+"(?=:)', C_KEY),
        (r'"[^"]*"', C_STR),
        (r"\b(?:true|false)\b", C_LIT),
    ],
    "lint": [
        (r"\berror\b", C_ERR),
        (r"\bexit 1\b|\bPR blocked\b", C_ERR),
        (r"\[[\w-]+\]|api-peak:[\w:-]+", C_KEY),
        (r"`[^`]*`", C_STR),
        (r"\b(?:GET|POST|PUT|DELETE|MUST)\b", C_CMD),
        (r"#[\w-]+|→", C_DIM),
        (r"\bskipped\b", C_DIM),
    ],
}


def highlight(line, lang):
    """One code line as HTML: escaped, spaces kept, tokens wrapped in color spans."""
    rules = [(re.compile(rx), color) for rx, color in _TOKENS.get(lang, [])]

    def text(t):
        return escape(t).replace(" ", "&#160;")

    out, i = [], 0
    while i < len(line):
        best = None
        for rx, color in rules:
            m = rx.search(line, i)
            if m and m.end() > m.start() and (best is None or m.start() < best[0].start()):
                best = (m, color)
        if not best:
            out.append(text(line[i:]))
            break
        m, color = best
        out.append(text(line[i:m.start()]))
        out.append(f'<span style="color:{color}">{text(m.group())}</span>')
        i = m.end()
    return "".join(out)


def code(lines, size=32, width=None, lang=None):
    w = f" width:{width}px;" if width else ""
    body = "<br>".join(highlight(l, lang) for l in lines)
    return (f'<div style="background:{NAVY}; border-radius:16px; padding:36px 44px;{w}">'
            f'<p style="font-family:{MONO}; font-size:{size}px; line-height:1.5; color:#e6e9ef">'
            f"{body}</p></div>")


# ---------------------------------------------------------------- pipeline

PIPE_TEXT = 30  # 25% larger than the 24px minimum, for reading from the back of the room


def _box(name, tool, look, width, dim=False):
    looks = {
        "neutral": ("transparent", f"2px solid {FADED}", "#e6e9ef", "#c4cad8"),
        "future": ("transparent", "2px dashed #5d6679", FADED, FADED),
        "done": ("#465068", "2px solid #aab3c5", LIGHT, "#d0d6e2"),
        "current": (ACCENT_ON_DARK, f"2px solid {ACCENT_ON_DARK}", "#13202b", "#1f3444"),
    }
    bg, border, c1, c2 = looks[look]
    tool_p = (f'<p style="font-size:{PIPE_TEXT}px; line-height:1.2; color:{c2}; text-align:center">{tool}</p>'
              if tool else "")
    extra = ""
    if look == "current":
        # the active gate: thicker light border, glow, slightly larger
        border = f"4px solid {LIGHT}"
        extra = ("; box-shadow:0px 0px 0px 6px rgba(124,200,234,0.35), 0px 0px 36px rgba(124,200,234,0.7)"
                 "; transform:scale(1.08)")
    elif dim:
        extra = "; opacity:0.6"
    return (f'<div style="width:{width}px; background:{bg}; border:{border}; border-radius:14px; '
            f'padding:18px 12px; display:flex; flex-direction:column; align-items:center; gap:6px{extra}">'
            f'<p style="font-size:{PIPE_TEXT}px; font-weight:700; line-height:1.2; color:{c1}; '
            f'text-align:center">{name}</p>{tool_p}</div>')


def _arrow(width=30, dim=False):
    op = "; opacity:0.6" if dim else ""
    return (f'<x-connector style="width:{width}px; color:{FADED}; align-self:center{op}">'
            f"</x-connector>")


def pipeline(state):
    """state: 'empty', one of STEPS (that step current, earlier ones done), or 'all'."""
    def look(key):
        if state == "all":
            return "done"
        if state == "empty":
            return "future"
        i, cur = STEPS.index(key), STEPS.index(state)
        return "current" if i == cur else ("done" if i < cur else "future")

    # Emphasis: on a step slide only the current gate is at full strength, everything
    # else sits at 60%. Before any gate (thread) the bare pipeline is active and the
    # gates are dimmed; on the final slide ("all") nothing is dimmed.
    step = state in STEPS

    def dim(key=None):
        if state == "all":
            return False
        if state == "empty":
            return key is not None
        return key != state

    gates = [("guidelines", "Guidelines", "Spectral"),
             ("breaking", "Breaking changes", "oasdiff"),
             ("contracts", "Contract test + mock", "Microcks"),
             ("gateway", "API gateway", "KrakenD")]
    parts = []
    for i, (k, n, t) in enumerate(gates):
        if i:
            parts.append(_arrow(24, dim=step or state == "empty"))
        parts.append(_box(n, t, look(k), 230, dim=dim(k)))
    label_op = "; opacity:0.6" if (step or state == "empty") else ""
    ci = (f'<div style="border:2px solid #5d6679; border-radius:18px; padding:18px 20px; '
          f'display:flex; flex-direction:column; gap:14px; align-items:center">'
          f'<p style="font-size:{PIPE_TEXT}px; color:{FADED}{label_op}">CI gates on every pull request</p>'
          f'<div style="display:flex; flex-direction:row; align-items:center">{"".join(parts)}</div></div>')
    right = (f'<div style="display:flex; flex-direction:column; gap:18px">'
             f'{_box("Catalog", "Backstage", look("catalog"), 200, dim=dim("catalog"))}'
             f'{_box("Deploy", "", "neutral", 200, dim=dim())}</div>')
    return (f'<div style="display:flex; flex-direction:row; align-items:center">'
            f'{_box("Pull request", "", "neutral", 160, dim=dim())}{_arrow(dim=step)}{ci}{_arrow(dim=step)}'
            f'{_box("Merge", "", "neutral", 130, dim=dim())}{_arrow(dim=step)}{right}</div>')


# ---------------------------------------------------------------- templates

def step_title(sid, n, name, statement, sub, state, notes, backdrop=None):
    bd = ""
    if backdrop:
        bd = (f'<img src="{asset(backdrop)}" alt="" style="position:absolute; left:0; top:0; '
              f'width:1920px; height:1080px; object-fit:cover; opacity:0.08">')
    body = (f"{bd}<div style=\"display:flex; flex-direction:column; gap:24px\">"
            f"{eyebrow(f'Step {n} — {name}', ACCENT_ON_DARK)}{h1(statement, LIGHT)}"
            f"{p(sub, 36, BEIGE_TEXT)}</div>"
            f'<div style="flex:1"></div>{pipeline(state)}')
    return section(sid, NAVY, body, notes, color=LIGHT)


def video(sid, n, name, clip, notes):
    body = (f'<img src="{asset(f"stage{n}-still.jpg")}" data-video="{asset(clip)}" '
            f'data-video-start="click" alt="Recorded demo, step {n}: {name}" '
            f'style="position:absolute; left:0px; top:0px; width:1920px; height:1080px; '
            f'object-fit:contain">')
    return section(sid, NAVY_DEEP, body, notes, color=LIGHT)


def takeaway(sid, n, title, key_lines, support, agents, notes, lang=None, extra=None, side=None):
    body = (f'<div style="display:flex; flex-direction:column; gap:20px">'
            f"{eyebrow(f'Step {n} — takeaway', ACCENT_ON_LIGHT)}{h2(title)}</div>"
            + (f"{code(key_lines, 30, lang=lang)}{code(extra[0], 26, lang=extra[1])}" if extra
               else f"{code(key_lines, 36, lang=lang)}" + (
                   f'<div style="display:flex; flex-direction:row; gap:48px; align-items:center">'
                   f'<div style="flex:1">{p(support, 32, MUTED)}</div>{side}</div>' if side
                   else p(support, 32, MUTED))) +
            f'<div style="flex:1"></div>'
            f'<div style="display:flex; flex-direction:row; gap:24px; align-items:center">'
            f'<p style="font-size:24px; font-weight:700; letter-spacing:2px; color:{LIGHT}; '
            f'background:{ACCENT_ON_LIGHT}; padding:8px 20px; border-radius:24px; '
            f'white-space:nowrap">FOR AGENTS</p>{p(agents, 32, INK)}</div>')
    return section(sid, LIGHT, body, notes)


# ---------------------------------------------------------------- slides

def slides():
    s = {}

    s["title"] = section(
        "title",
        f"linear-gradient(160deg, {LIGHT} 0%, {LIGHT} 60%, {NAVY} 60%, {NAVY} 100%)",
        f'<div style="display:flex; flex-direction:column; gap:28px">'
        f'{h1("DevOps-Driven API Governance", "#1f2a44", 104)}'
        f'{p("Open Source and Agent-Ready in Hours", 40, MUTED)}</div>'
        f'<p style="position:absolute; left:128px; top:760px; width:720px; font-size:32px; '
        f'font-weight:700; line-height:1.4; color:{ACCENT_ON_LIGHT}">FOST London 2026 · 1 October</p>'
        f'<p style="position:absolute; right:128px; bottom:150px; width:640px; text-align:right; '
        f'font-family:{HEAD}; font-size:48px; font-weight:700; color:{BEIGE}">Andrzej Jarzyna</p>'
        f'<p style="position:absolute; right:128px; bottom:96px; width:640px; text-align:right; '
        f'font-size:32px; color:{BEIGE_TEXT}">API Peak</p>',
        "0:00 → 0:15. Good afternoon. I'm Andrzej, and for the next twenty minutes we'll build "
        "API governance into a delivery pipeline, one gate at a time, in a real, working repo. "
        "Transition: first, who I am, in thirty seconds.")

    track = [
        ("3scale", "API Solution Engineer: API management, gateways, developer portals"),
        ("adidas", "API Evangelist: guidelines, API contract repository, CI quality gates"),
        ("ING", "Lead of Policy as Code in API governance"),
        ("PZU", "Chief API Architect: governance program from zero, 200+ external APIs, "
                "30+ products, APIs ready for AI agents"),
    ]
    rows = "".join(
        f'<div style="display:flex; flex-direction:row; gap:24px; border-top:1px solid #d9dbe0; '
        f'padding:14px 0px">'
        f'<p style="width:250px; font-size:26px; font-weight:700; color:{ACCENT_ON_LIGHT}">{a}</p>'
        f'<p style="flex:1; font-size:26px; line-height:1.35; color:{INK}">{b}</p></div>'
        for a, b in track)
    s["about"] = section(
        "about", LIGHT,
        f'<div style="display:flex; flex-direction:row; gap:64px; flex:1">'
        f'<div style="flex:1; display:flex; flex-direction:column; gap:20px">'
        f'{h2("Andrzej Jarzyna")}'
        f'{p("Founder of <b>API Peak</b>: API strategy and governance services, community products", 32, MUTED)}'
        f'<div style="display:flex; flex-direction:column">{rows}</div></div>'
        f'<img src="{asset("andrzej.jpg")}" alt="Andrzej climbing a snowy gully" '
        f'style="width:600px; height:780px; object-fit:cover; border-radius:16px; align-self:center"></div>',
        "0:15 → 0:35. Founder of API Peak, my own company: API strategy and governance for "
        "companies, plus community work. Before that I built API governance at adidas, ING and "
        "most recently PZU, the largest insurer in Central-Eastern Europe. Co-author of the "
        "RESTful API Design Patterns book. Fun fact: API Peak is also the made-up company in "
        "today's demo repo. Transition: and one line about the book.")

    s["book"] = section(
        "book", LIGHT,
        f'<div style="display:flex; flex-direction:row; gap:96px; flex:1; align-items:center">'
        f'<img src="{asset("book.jpg")}" alt="Book cover: RESTful API Design Patterns and Best Practices" '
        f'style="width:560px; height:690px; object-fit:contain">'
        f'<div style="flex:1; display:flex; flex-direction:column; gap:28px">'
        f'{eyebrow("The book", ACCENT_ON_LIGHT)}'
        f'{h2("RESTful API Design Patterns and Best Practices")}'
        f'{p("Andrzej Jarzyna &amp; Samir Amzani · Packt", 32, MUTED)}'
        f'<div style="display:flex; flex-direction:row; gap:32px; align-items:center">'
        f'<img src="{asset("qr-book-amazon.png")}" alt="QR code: the book on Amazon" '
        f'style="width:300px; height:300px; object-fit:contain">'
        f'{p("Get it on Amazon", 32, INK, "font-weight:700")}</div></div></div>',
        "0:35 → 0:45. Ten seconds: the book covers API design, lifecycle and governance, and "
        "this talk is one chapter of it in practice. The QR code goes to Amazon. "
        "Transition: and here's why governance matters more this year than ever.")

    s["hook"] = section(
        "hook", NAVY,
        f'<div style="flex:1"></div>'
        f'{eyebrow("paradigm shift", ACCENT_ON_DARK)}'
        f'{h1("Your next API consumer is an agent.", LIGHT, 96)}'
        f'{p("It takes your contract as is - completeness and quality are key", 44, BEIGE_TEXT)}'
        f'<div style="flex:1"></div>',
        "0:45 → 1:15. This conference is about agents moving money, not just talking about it. "
        "A human developer reads the docs, pings someone on Slack, works around a gap. An agent "
        "can't. Whatever your contract says, or doesn't say, is what it does. So the quality of "
        "your API contracts is suddenly a business risk. Transition: we measured this at PZU.",
        color=LIGHT)

    def stat(label, old, new, caption):
        return (f'<div style="flex:1; background:#ffffff; border:1px solid #e1e3e8; '
                f'border-radius:16px; padding:40px; display:flex; flex-direction:column; gap:16px">'
                f'<p style="font-size:28px; font-weight:700; color:{MUTED}">{label}</p>'
                f'<div style="display:flex; flex-direction:row; align-items:center; gap:28px">'
                f'<p style="font-family:{HEAD}; font-size:60px; white-space:nowrap; color:#8a91a0">{old}</p>'
                f'<x-shape kind="arrow-right" style="width:56px; height:28px; background:{FADED}"></x-shape>'
                f'<p style="font-family:{HEAD}; font-size:104px; font-weight:700; white-space:nowrap; '
                f'color:{ACCENT_ON_LIGHT}">{new}</p></div>'
                f'{p(caption, 28, MUTED)}</div>')
    s["agents"] = section(
        "agents", LIGHT,
        f'<div style="display:flex; flex-direction:column; gap:20px">'
        f'{eyebrow("PZU · internal test of AI agents on our APIs", ACCENT_ON_LIGHT)}'
        f'{h2("Governed contracts make agents accurate")}</div>'
        f'<div style="display:flex; flex-direction:row; gap:40px">'
        f'{stat("Single API calls", "70–80%", "99.6%", "Bare OpenAPI → plus what governance already requires: descriptions, adherence to standards, examples")}'
        f'{stat("Multi-step workflows", "~60%", "&gt;90%", "Chained calls → plus Arazzo workflow descriptions on top of the same specs, or Hypermedia controls")}'
        f'</div><div style="flex:1"></div>'
        f'{p("AI-ready APIs are not a separate initiative. They are a product of your API governance program", 40, INK, "font-weight:700")}',
        "1:15 → 2:05. At PZU we pointed AI agents at our own OpenAPI files. Bare specs with "
        "minimal descriptions: 70 to 80 percent accuracy. Then the same specs with what our "
        "governance program already required, descriptions everywhere, Problem Details for "
        "errors, examples: 99.6 percent. Multi-step workflows were worse, about 60 percent, and "
        "Arazzo workflow descriptions took them above 90. We didn't start the program for AI. "
        "The accuracy came as a by-product. Transition: so what is governance really about?")

    s["why"] = section(
        "why", LIGHT,
        f'<img src="{asset("api-sprawl.jpg")}" alt="A dense map of hundreds of connected systems" '
        f'style="position:absolute; left:860px; top:0px; width:1060px; height:1080px; object-fit:cover">'
        f'<div style="position:absolute; left:0px; top:0px; width:860px; height:1080px; background:{NAVY}"></div>'
        f'<div style="position:absolute; left:112px; top:112px; width:660px; height:856px; display:flex; '
        f'flex-direction:column; justify-content:space-between">'
        f'<div style="display:flex; flex-direction:column; gap:36px">'
        f'{h2("Why governance?", LIGHT)}'
        f'<ul style="font-size:32px; line-height:1.6; color:{BEIGE_TEXT}">'
        f"<li>API sprawl and zombie endpoints</li><li>Manual checks, late in the lifecycle</li>"
        f"<li>Uneven quality: tools and agents break</li></ul></div>"
        f'<div style="display:flex; flex-direction:column; gap:24px; border-left:4px solid {ACCENT_ON_DARK}; '
        f'padding:4px 0px 4px 32px">'
        f'{p("Governance is the developer experience of creating and using APIs. And the developer can now be an agent", 34, LIGHT, "font-weight:700")}'
        f'{p("It is about making it easy to do things right, and hard to do things wrong", 30, ACCENT_ON_DARK)}'
        f'</div></div>',
        "2:05 → 2:55. This is a real integration map, not a drawing. Nobody has the full picture. "
        "Sprawl, zombie endpoints, checks that happen weeks late in a review board, and uneven "
        "quality that breaks tools and now agents. My definition: governance is about the "
        "developer experience of creating and using APIs, and the developer can now be an "
        "agent. Make it easy to do right and hard to do wrong; when it works, nobody notices it. "
        "Transition: here is how we'll do that today.")

    def card(title, items, dark):
        bg, tc, ic = (NAVY, LIGHT, BEIGE_TEXT) if dark else ("#ffffff", INK, MUTED)
        border = "none" if dark else "1px solid #e1e3e8"
        lis = "".join(f"<li>{i}</li>" for i in items)
        return (f'<div style="flex:1; background:{bg}; border:{border}; border-radius:16px; '
                f'padding:40px; display:flex; flex-direction:column; gap:20px">'
                f'<h3 style="font-family:{HEAD}; font-size:40px; font-weight:700; color:{tc}">{title}</h3>'
                f'<ul style="font-size:28px; line-height:1.45; color:{ic}">{lis}</ul></div>')
    s["premises"] = section(
        "premises", LIGHT,
        f'{h2("Premises")}'
        f'<div style="display:flex; flex-direction:row; gap:40px; flex:1">'
        + card("How we work", [
            "Design-first",
            "The API contract (OpenAPI) is the single source of truth",
            "Configuration as code",
            "Any CI: here Gitea Actions, GitHub-style",
        ], False)
        + card("Open source &amp; sovereign", [
            "No vendor lock-in",
            "The right tool for each task, not months customizing one heavy platform",
            "Data and business residency: you choose where contracts and data are processed, and under which jurisdiction",
            "No access for unwanted actors",
        ], True)
        + f'</div>{p("In the demo: Backstage · Spectral · oasdiff · Microcks · KrakenD · Gitea. Swap any tool, keep the gates.", 26, MUTED)}',
        "2:55 → 3:45. Four premises: design-first, the contract is the single source of truth, "
        "everything is configuration as code, and it runs on any CI. And one choice I care about: "
        "open source and sovereign. No vendor lock-in. The right tool for each task instead of "
        "paying to customize one huge platform. And residency: you decide where your contracts "
        "and data are processed and under which jurisdiction, so no unwanted actor gets access. "
        "Even this repo lives on Codeberg, an EU forge. Transition: let me introduce our API.")

    s["thread"] = section(
        "thread", NAVY,
        f'<div style="display:flex; flex-direction:column; gap:24px">'
        f'{eyebrow("The story", ACCENT_ON_DARK)}{h1("One API, one partner", LIGHT)}'
        f'{p("The <b>Orders API</b>: <span style=\"color:#7cc8ea\">GET /orders/{orderId}</span>. "
             "A fintech partner is building an AI agent on it.", 36, BEIGE_TEXT)}'
        f'{p("Each step adds one gate to this pipeline.", 32, FADED)}</div>'
        f'<div style="flex:1"></div>{pipeline("empty")}',
        "3:45 → 4:30. Meet the Orders API. One endpoint, GET an order by id. And a partner, a "
        "fintech building an AI agent on top of it. Keep them in mind: they'll integrate in step "
        "three, and in step five we'll protect them. Here's the delivery pipeline: pull request, "
        "CI, merge, deploy. No gates yet. The demos are recordings of a real local stack; the "
        "whole repo is open source. Checkpoint 4:30. Behind? Skip slide 10: say the one-file point in one sentence on slide 9. Transition: step one.", color=LIGHT)

    s["catalog"] = step_title(
        "catalog", 1, "API catalog", "You can’t govern what you can’t see",
        "Thousands of APIs across the organization. Who knows they exist?", "catalog",
        "4:30 → 5:10. Behind me: an API dependency graph of an organization. Every dot an API. "
        "Nobody has the full map. Before any rule, you need to see what you have. Transition: "
        "and the cost of that first step has to be almost zero.", backdrop="org-graph-clean.jpg")

    s["catalogfile"] = section(
        "catalogfile", LIGHT,
        f'{h2("One file. That’s the whole cost.")}'
        f'<div style="display:flex; flex-direction:row; gap:56px; align-items:center">'
        + code(["# catalog-info.yaml, next to the code",
                "apiVersion: backstage.io/v1alpha1",
                "kind: API",
                "metadata:",
                "  name: orders-api",
                "spec:",
                "  type: openapi",
                "  lifecycle: experimental",
                "  owner: group:default/platform-team",
                "  definition:",
                "    $text: ./contracts/orders-openapi.yaml"], 30, 960, lang="yaml")
        + f'<div style="flex:1; display:flex; flex-direction:column; gap:28px">'
        f'{p("Name, owner, contract: next to the code", 34, INK, "font-weight:700")}'
        f'{p("Merge it, and the API is discovered, visible org-wide, with its contract and owner in one place", 30, MUTED)}'
        f'{p("The first step has to be almost invisible", 30, ACCENT_ON_LIGHT, "font-weight:700")}'
        f'</div></div>',
        "5:10 → 5:40. This is the entire cost of step one: one small file next to the code. "
        "Name, owner, and a pointer to the contract. Backstage here, but any catalog that reads "
        "files from repos works. Transition: let's watch it.")

    s["v1"] = video(
        "v1", 1, "API catalog", "stage1-talk.mp4",
        "5:40 → 6:15. Click to play (35 s, sped up 1.25x). Cues: 0:00 the branch with "
        "catalog-info.yaml. ~0:10 open the file: that's all of it. ~0:17 PR, no checks yet, "
        "merge. ~0:25 Backstage APIs page, reload: orders-api appears by itself. ~0:30 the "
        "Definition tab: the contract, rendered. Say: commit, merge, done. Move on once the "
        "definition shows (the clip loops). Transition: now the story from adidas.")

    s["guidelines"] = step_title(
        "guidelines", 2, "Guidelines as code", "A guideline nobody enforces is a suggestion",
        "At adidas, the real picture only showed up when the rules ran in CI.", "guidelines",
        "6:15 → 7:15. The adidas story, about 40 seconds. We had API guidelines. They existed, "
        "people knew them. But they were followed closely only when a team came to the API team "
        "for help with the design. Then we built an API contract repository that also checked "
        "how APIs followed the rules. For the first time we saw the real picture, and it was "
        "quite incomplete. That was step one: you can't govern what you can't see. The change "
        "came only when Spectral linting and contract testing moved from the guidelines "
        "document into the CI pipelines. Transition: here's that gate.")

    s["v2"] = video(
        "v2", 2, "Guidelines as code", "stage2-talk.mp4",
        "7:15 → 8:22. Click to play (65 s). Cues: 0:00 the PR that adds the Spectral gate. "
        "~0:03 Backstage, API Guidelines: the rules live in the catalog, as docs. ~0:14 "
        "(fast) a change moves the server URL to http://. ~0:27 red check. ~0:29 the log: one "
        "finding, api-peak:rest17:2025-https-required, with a link. ~0:36 the link opens the "
        "same rule in Backstage: one source of truth for humans and CI. ~0:44 (fast) one-line "
        "fix, push, green, merge. Move on at the merge. Transition: so what does that give you?")

    s["t2"] = takeaway(
        "t2", 2, "Feedback in seconds, not weeks",
        ["error  api-peak:rest17:2025-https-required",
         "       server.url MUST use HTTPS",
         "       → rule in the catalog: #https-api-peakrest172025-https"],
        "Rule, file, line and how to fix it, right on the pull request. The same rules for "
        "humans and CI: one source of truth.",
        "descriptions and examples in the contract are what lifted accuracy to 99.6%.",
        "8:22 → 8:52. The review board used to find this weeks later. Now it's a red check in "
        "seconds, with the rule and the fix. Tip: warnings first, then promote rules to errors "
        "once teams are clean. Checkpoint 8:52. Behind? Talk over the Microcks UI part of clip 3 without pausing. Transition: now, a contract is a promise. "
        "Aside, if asked about the QR code: the Spectral CLI we pin (6.16.x) started sending "
        "install-time analytics through Scarf this summer. The CI image opts out; Spotlight is an "
        "openly governed fork of Spectral with the telemetry removed, a drop-in with the same rulesets.",
        lang="lint",
        side=(f'<div style="width:560px; display:flex; flex-direction:row; gap:24px; align-items:center; '
              f'background:#ffffff; border:1px solid #e1e3e8; border-radius:16px; padding:20px">'
              f'<img src="{asset("qr-spotlight.png")}" alt="QR code: Spotlight, the openly governed Spectral fork, on GitHub" '
              f'style="width:170px; height:170px; object-fit:contain">'
              f'<div style="flex:1; display:flex; flex-direction:column; gap:8px">'
              f'{p("Spotlight", 28, INK, "font-weight:700")}'
              f'{p("Spectral 6.16 sends telemetry. Spotlight fork fixes it (will rename to OpenLint)", 24, MUTED)}'
              f'</div></div>'))

    s["contracts"] = step_title(
        "contracts", 3, "Mocks and contract testing", "A contract is a promise",
        "Can the partner integrate before the API exists? Does the code keep the promise?",
        "contracts",
        "8:52 → 9:27. Two questions for our fintech partner. One: can they start before the "
        "API is built? Two: once it's built, does the code do what the contract says? Microcks "
        "answers both from the same contract. Transition: watch.")

    s["v3"] = video(
        "v3", 3, "Mocks and contract testing", "stage3-talk.mp4",
        "9:27 → 11:12. Click to play (107 s). Cues: 0:00 the PR adds the contract-test gate. "
        "~0:04 curl the mock: a live response from the contract's example; the partner "
        "integrates today. ~0:13 Microcks: the mocked service. ~0:25 (fast) a change promises "
        "a new field, currency. ~0:40 contract-test red. ~0:49 Microcks test detail: "
        "required property currency not found. ~1:14 curl the mock (has currency) vs the "
        "backend (doesn't): the code doesn't keep the promise. ~1:23 (fast) fix: don't promise "
        "currency until the backend returns it; green, merge. Move on at the merge. Transition: one example, many uses.")

    s["t3"] = takeaway(
        "t3", 3, "One example, many uses",
        ["examples:",
         "  order_123:",
         "    value: { orderId: \"123\", isPaid: true }",
         "# → the live mock AND the contract test"],
        "The partner builds against the mock before the code exists; CI proves the code keeps "
        "the promise on every pull request.",
        "build and test the agent against the mock before the API exists.",
        "11:12 → 11:42. One example in the contract pays twice: it's the mock partners use, and "
        "it's the test the code must pass. Transition: now let's expose it for real.", lang="yaml")

    s["gateway"] = step_title(
        "gateway", 4, "Publish through the API gateway", "Publish the API straight from its contract",
        "Publishing is a lifecycle step, not a ticket. Hand-written gateway config drifts from the contract.",
        "gateway",
        "11:42 → 12:17. Putting an API behind the gateway is how it gets published in its lifecycle. In most companies someone types routes into the gateway by hand, and "
        "nobody checks them against the contract. So we generate the gateway config from the "
        "contract, in CI, on every PR, and prove it. Transition: watch.")

    s["v4"] = video(
        "v4", 4, "API gateway", "stage4-talk.mp4",
        "12:17 → 13:27. Click to play (70 s). Cues: 0:00 curl through KrakenD: 404, no routes "
        "yet. ~0:04 (fast) the PR adds the gateway gate. ~0:23 the job: generate krakend.json "
        "from the contract, validate it with krakend check, deploy it, then run the same "
        "contract test through the gateway. ~0:45 green, merge. ~0:52 curl again: 200 through "
        "KrakenD, same body as the backend. Move on after the second curl. Transition: generated, deployed, proven.")

    s["t4"] = takeaway(
        "t4", 4, "Generated, deployed, proven",
        ["$ curl -i localhost:8090/orders/123   # before",
         "HTTP/1.1 404 Not Found",
         "$ curl -i localhost:8090/orders/123   # after the merge",
         "HTTP/1.1 200 OK  {\"orderId\":\"123\",\"isPaid\":true}"],
        "One endpoint per path and method in the contract, nothing else. The same contract "
        "test runs through the gateway: it must not change what the contract promises.",
        "what runs in production is exactly what the agent read.",
        "13:27 → 13:57. Catalog, tests, mock and now the gateway all come from the same "
        "orders-openapi.yaml. One endpoint per path and method in the contract, nothing else, "
        "and the same contract test runs through the gateway. Gateway policy can live in the "
        "contract too: KrakenD Enterprise imports x-krakend-* OpenAPI extensions, such as a "
        "rate limit; the demo's open-source generator doesn't read them yet. "
        "With Kong or Apigee only the generator changes. Checkpoint 13:57. Behind? Keep takeaway 5 to one sentence and go straight to Monday morning after the pipeline slide. Transition: "
        "and now our partner is live.", lang="shell",
        extra=(["# gateway policy in the contract too (KrakenD Enterprise importer)",
                "get:",
                "  x-krakend-extra_config:",
                "    qos/ratelimit/router: { max_rate: 50 }"], "yaml"))

    s["breaking"] = step_title(
        "breaking", 5, "Breaking changes", "Now the partner is integrated",
        "A small, innocent change to the contract. Who finds out first: CI, or the partner?",
        "breaking",
        "13:57 → 14:27. The fintech partner's agent is in production, calling us. Now someone "
        "makes a small change to the contract. Note where this gate sits: right after lint, "
        "before the runtime tests. A change that breaks clients shouldn't even reach them. "
        "Transition: watch.")

    s["v5"] = video(
        "v5", 5, "Breaking changes", "stage5-talk.mp4",
        "14:27 → 15:41. Click to play (74 s). Cues: 0:00 switch to the branch, git diff --stat, push. "
        "~0:09 (fast) open the PR. ~0:13 Files changed: the new breaking-changes job in the middle of the chain, "
        "needs repointed. ~0:25 (very fast) four gates green, merge. ~0:30 the innocent change: a new query "
        "parameter channel, required. ~0:44 breaking-changes red; contract test and gateway Skipped, grey: "
        "the later gates don't even run. ~0:46 (2x) oasdiff: new-required-request-parameter, channel. "
        "~0:54 (2x) fix: make channel optional, push. ~1:05 (very fast) all four green, merge. Move on at the merge. "
        "Transition: blocked before anyone got hurt.")

    s["t5"] = takeaway(
        "t5", 5, "An explicit decision, not an accident",
        ["error [new-required-request-parameter]",
         "  in API GET /orders/{orderId}",
         "  added the new required `query` request parameter `channel`",
         "exit 1 → PR blocked (contract test + gateway: skipped)"],
        "Blocked before merge, before deploy, before the incident. Make it optional, or ship a "
        "new major version on purpose (rule rest40).",
        "a human reads the changelog. An agent just fails, at scale, often silently.",
        "15:41 → 16:16. Clients that don't send channel today would start getting 400s. CI "
        "caught it before the partner did. If you truly need the change, it's a decision: a new "
        "version, run both, deprecate. Never by accident. Transition: let's step back.", lang="lint")

    s["pipeline"] = section(
        "pipeline", NAVY,
        f'<div style="display:flex; flex-direction:column; gap:20px">'
        f'{eyebrow("The whole pipeline", ACCENT_ON_DARK)}'
        f'{h1("You don’t need five gates on day one", LIGHT, 72)}'
        f'{p("Add one at a time, like we just did. Every change is a pull request with recorded gate results: an audit trail for free. Open source, sovereign, one contract.", 32, BEIGE_TEXT)}</div>'
        f'<div style="flex:1"></div>{pipeline("all")}',
        "16:16 → 16:46. Five gates, one contract. And the order we added them is the rollout "
        "plan: start minimal, then nudge. For regulated industries, every contract change is a "
        "PR with recorded gate results, an audit trail you get for free. Transition: so what "
        "can you do on Monday?", color=LIGHT)

    def action(n, text):
        return (f'<div style="flex:1; background:#ffffff; border:1px solid #e1e3e8; '
                f'border-radius:16px; padding:40px; display:flex; flex-direction:column; gap:20px">'
                f'<p style="font-family:{HEAD}; font-size:88px; font-weight:700; '
                f'color:{ACCENT_ON_LIGHT}">{n}</p>{p(text, 34, INK, "font-weight:700")}</div>')
    s["monday"] = section(
        "monday", LIGHT,
        f'{h2("Monday morning")}'
        f'<div style="display:flex; flex-direction:row; gap:40px; flex:1">'
        f'{action(1, "Track all your APIs in one place, even from a monorepo")}'
        f'{action(2, "Turn your top 5 guideline rules into a CI lint, warnings first")}'
        f'{action(3, "Run a breaking-change diff on your most-used API")}</div>'
        f'{p("Your APIs get better for people, and ready for agents, as a by-product.", 32, MUTED)}',
        "16:46 → 17:31. Three things, no big program needed. One: track all your APIs in one "
        "place, even from a monorepo. Two: take your top five guideline rules and make them a "
        "CI lint, as warnings first. Three: run a breaking-change diff on your most-used API "
        "and see what you've been shipping. Transition: thank you.")

    s["thanks"] = section(
        "thanks", BEIGE,
        f'<div style="display:flex; flex-direction:row; gap:64px; flex:1; align-items:center">'
        f'<div style="flex:1; display:flex; flex-direction:column; gap:24px">'
        f'{h1("Thank you!", "#1f2a44", 104)}'
        f'{p("Andrzej Jarzyna · API Peak", 36, INK, "font-weight:700")}'
        f'{p("Run the whole demo yourself: <b>docker compose up</b>", 30, MUTED)}</div>'
        f'<div style="display:flex; flex-direction:column; align-items:center; gap:16px">'
        f'<img src="{asset("qr-codeberg.png")}" alt="QR code: the demo repository on Codeberg" '
        f'style="width:400px; height:400px; object-fit:contain">'
        f'{p("The repo, on Codeberg", 28, INK, "font-weight:700")}'
        f'{p("codeberg.org/pierogi/devops-api-governance", 24, MUTED)}</div></div>',
        "17:31 → 18:01. Thank you. The QR code is the repo: run the whole demo with docker "
        "compose. Transition: one last thing before questions.")

    s["feedback"] = section(
        "feedback", NAVY,
        f'<div style="display:flex; flex-direction:row; gap:96px; flex:1; align-items:center">'
        f'<div style="flex:1; display:flex; flex-direction:column; gap:28px">'
        f'{eyebrow("FOST London 2026", ACCENT_ON_DARK)}'
        f'{h1("How was this session?", LIGHT, 88)}'
        f'{p("Scan to rate it. It takes a minute and it really helps.", 40, BEIGE_TEXT)}'
        f'{p("Questions? I’m here now, and after the session.", 32, FADED)}</div>'
        f'<div style="background:#ffffff; border-radius:24px; padding:32px">'
        f'<img src="{asset("qr-fost-feedback.png")}" alt="QR code: FOST session feedback form" '
        f'style="width:520px; height:520px; object-fit:contain"></div></div>',
        "18:01 → Q&A. Leave this slide up during questions: the FOST feedback form. "
        "Ask people to scan it now.", color=LIGHT)

    qa = [
        ("Backstage is heavy. Anything lighter?",
         "Any catalog that reads files from repos. The point is: track all your APIs."),
        ("A breaking change we truly need?",
         "Rule rest40: new major version or new resource, run both, deprecate the old one."),
        ("Kong, Apigee, Azure APIM?",
         "Yes. The gateway config is generated from the contract; only the generator changes."),
        ("How did 30+ teams adopt it at PZU?",
         "Federated governance team, minimal but mandatory standards, start minimal and nudge."),
        ("Warnings or errors from day one?",
         "Warnings first. Promote a rule to an error once teams are clean."),
        ("AsyncAPI and events?", "Same gates: lint, diff, catalog."),
        ("Where does MCP fit?",
         "Well-governed OpenAPI plus Arazzo gets most of the way. MCP mocks are roadmap here."),
        ("Which guidelines are really enforced?",
         "Completeness Verification: ask an AI which rules could be lint checks, compare with CI."),
    ]
    trs = "".join(f"<tr><td>{a}</td><td>{b}</td></tr>" for a, b in qa)
    s["qa"] = section(
        "qa", LIGHT,
        f'{h2("Q&amp;A prep", INK, 48)}'
        f'<table style="font-size:24px; color:{INK}">'
        f'<tr><th style="width:36%">Question</th><th style="width:64%">Short answer</th></tr>{trs}</table>',
        "Hidden slide: not shown in the talk. Short answers for the Q&A after the talk.",
        attrs=" hidden")
    return s


ORDER = ["title", "about", "book", "hook", "agents", "why", "premises", "thread",
         "catalog", "catalogfile", "v1",
         "guidelines", "v2", "t2",
         "contracts", "v3", "t3",
         "gateway", "v4", "t4",
         "breaking", "v5", "t5",
         "pipeline", "monday", "thanks", "feedback", "qa"]

SECTIONS = {
    "s1": ("Open: agents are the new API consumers, and governance is their developer experience", "title"),
    "s2": ("Setup: premises and the Orders API story", "premises"),
    "s3": ("Step 1: the API catalog", "catalog"),
    "s4": ("Step 2: guidelines as code", "guidelines"),
    "s5": ("Step 3: mocks and contract testing", "contracts"),
    "s6": ("Step 4: the API gateway, generated from the contract", "gateway"),
    "s7": ("Step 5: breaking changes", "breaking"),
    "s8": ("Close: the whole pipeline, Monday morning actions, thank you, feedback", "pipeline"),
}

FACES = {
    "merriweather": {"family": "Merriweather",
                     "href": "https://fonts.googleapis.com/css2?family=Merriweather:wght@400;700&display=swap"},
    "roboto": {"family": "Roboto",
               "href": "https://fonts.googleapis.com/css2?family=Roboto:wght@400;700&display=swap"},
    "jetbrains-mono": {"family": "JetBrains Mono",
                       "href": "https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;700&display=swap"},
}


def deck_index(created_at):
    return {
        "v": 4,
        "createdOnFiles": {"v": 1, "at": created_at},
        "title": "DevOps-Driven API Governance — FOST London 2026",
        "cover": "title",
        "order": ORDER,
        "sections": {k: {"description": d, "start": st} for k, (d, st) in SECTIONS.items()},
        "faces": FACES,
        "designSystems": [],
    }


def build(out_dir, created_at=None):
    created_at = created_at or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    root = Path(out_dir) / "project"
    (root / "slides").mkdir(parents=True, exist_ok=True)
    s = slides()
    for sid, html in s.items():
        (root / "slides" / f"{sid}.html").write_text(html)
    (root / "deck.json").write_text(json.dumps(deck_index(created_at), indent=2, ensure_ascii=False))
    return s


if __name__ == "__main__":
    build(sys.argv[1])
