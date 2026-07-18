from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    HRFlowable,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

OUTPUT = "/home/josepak/riscv-unified-db/tasks/masking_explainer.pdf"

doc = SimpleDocTemplate(
    OUTPUT,
    pagesize=letter,
    leftMargin=0.85 * inch,
    rightMargin=0.85 * inch,
    topMargin=0.85 * inch,
    bottomMargin=0.85 * inch,
)

styles = getSampleStyleSheet()

# Custom styles
title_style = ParagraphStyle(
    "title",
    fontSize=22,
    fontName="Helvetica-Bold",
    textColor=colors.HexColor("#1a1a2e"),
    spaceAfter=6,
    alignment=TA_CENTER,
)
subtitle_style = ParagraphStyle(
    "subtitle",
    fontSize=11,
    fontName="Helvetica",
    textColor=colors.HexColor("#555555"),
    spaceAfter=20,
    alignment=TA_CENTER,
)
h1_style = ParagraphStyle(
    "h1",
    fontSize=15,
    fontName="Helvetica-Bold",
    textColor=colors.HexColor("#16213e"),
    spaceBefore=18,
    spaceAfter=6,
)
h2_style = ParagraphStyle(
    "h2",
    fontSize=12,
    fontName="Helvetica-Bold",
    textColor=colors.HexColor("#0f3460"),
    spaceBefore=12,
    spaceAfter=4,
)
body_style = ParagraphStyle(
    "body",
    fontSize=10,
    fontName="Helvetica",
    textColor=colors.HexColor("#222222"),
    spaceAfter=6,
    leading=15,
)
mono_style = ParagraphStyle(
    "mono",
    fontSize=9,
    fontName="Courier",
    textColor=colors.HexColor("#1a1a1a"),
    backColor=colors.HexColor("#f4f4f4"),
    spaceAfter=8,
    leading=14,
    leftIndent=10,
    rightIndent=10,
    borderPad=6,
)
note_style = ParagraphStyle(
    "note",
    fontSize=9,
    fontName="Helvetica-Oblique",
    textColor=colors.HexColor("#b05000"),
    spaceAfter=6,
    leading=13,
)
red_style = ParagraphStyle(
    "red",
    fontSize=10,
    fontName="Helvetica-Bold",
    textColor=colors.HexColor("#cc0000"),
    spaceAfter=4,
)
green_style = ParagraphStyle(
    "green",
    fontSize=10,
    fontName="Helvetica-Bold",
    textColor=colors.HexColor("#006600"),
    spaceAfter=4,
)


def hr():
    return HRFlowable(
        width="100%", thickness=0.5, color=colors.HexColor("#cccccc"), spaceAfter=8, spaceBefore=4
    )


def h1(text):
    return Paragraph(text, h1_style)


def h2(text):
    return Paragraph(text, h2_style)


def body(text):
    return Paragraph(text, body_style)


def mono(text):
    text = text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    return Paragraph(text, mono_style)


def note(text):
    return Paragraph(text, note_style)


def sp(n=8):
    return Spacer(1, n)


# ── colour palette for element tables ──────────────────────────────────────
ACTIVE = colors.HexColor("#c8f7c5")  # green
INACTIVE = colors.HexColor("#f7c5c5")  # red
HEADER = colors.HexColor("#dde3f0")
ROWBG = colors.HexColor("#f9f9f9")


def element_table(col_headers, rows, col_widths=None):
    data = [col_headers] + rows
    tbl = Table(data, colWidths=col_widths)
    style = [
        ("BACKGROUND", (0, 0), (-1, 0), HEADER),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 9),
        ("ALIGN", (0, 0), (-1, -1), "CENTER"),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#aaaaaa")),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [ROWBG, colors.white]),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ]
    tbl.setStyle(TableStyle(style))
    return tbl


# ── coloured cell helpers ───────────────────────────────────────────────────
def cell(text, bg=None):
    if bg:
        return Paragraph(
            f'<para backColor="{bg.hexval() if hasattr(bg, "hexval") else bg}">{text}</para>',
            ParagraphStyle("cell", fontSize=9, fontName="Helvetica", alignment=1, leading=12),
        )
    return text


# ────────────────────────────────────────────────────────────────────────────
story = []

# ── TITLE PAGE ───────────────────────────────────────────────────────────────
story.append(Spacer(1, 0.4 * inch))
story.append(Paragraph("RISC-V Vector Masking", title_style))
story.append(
    Paragraph(
        "What it is, how it works, and why the IDL compiler can't support it yet", subtitle_style
    )
)
story.append(hr())
story.append(sp(4))

# ── SECTION 1 ────────────────────────────────────────────────────────────────
story.append(h1("1. What is Masking?"))
story.append(
    body(
        "A vector instruction operates on many elements in parallel. "
        "Masking lets you choose <b>which elements</b> actually get written and which are skipped — "
        "like a stencil laid over the destination register."
    )
)
story.append(
    body(
        "Without masking every element in the loop is written unconditionally. "
        "With masking, each element is only written if the corresponding bit in the mask register <b>v0</b> is 1."
    )
)
story.append(sp())

story.append(h2("The vm Bit"))
story.append(
    body("Every vector instruction has a 1-bit field called <b>vm</b> baked into its encoding:")
)

vm_data = [
    ["vm value", "Meaning"],
    ["vm = 1", "Unmasked — run all elements, ignore v0"],
    ["vm = 0", "Masked   — check v0[i] for each element"],
]
vm_tbl = Table(vm_data, colWidths=[2 * inch, 4 * inch])
vm_tbl.setStyle(
    TableStyle(
        [
            ("BACKGROUND", (0, 0), (-1, 0), HEADER),
            ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
            ("FONTSIZE", (0, 0), (-1, -1), 10),
            ("ALIGN", (0, 0), (-1, -1), "CENTER"),
            ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
            ("BACKGROUND", (0, 1), (-1, 1), ACTIVE),
            ("BACKGROUND", (0, 2), (-1, 2), INACTIVE),
            ("TOPPADDING", (0, 0), (-1, -1), 5),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
        ]
    )
)
story.append(vm_tbl)
story.append(sp())

# ── SECTION 2 ────────────────────────────────────────────────────────────────
story.append(h1("2. How v0 Controls Elements"))
story.append(
    body(
        "v0 is a normal vector register — VLEN bits wide. When used as a mask, each bit maps "
        "to one element position. Bit 0 controls element 0, bit 1 controls element 1, and so on."
    )
)

# v0 register diagram
v0_headers = ["Bit 7", "Bit 6", "Bit 5", "Bit 4", "Bit 3", "Bit 2", "Bit 1", "Bit 0"]
v0_vals = ["0", "0", "1", "0", "1", "1", "0", "1"]
v0_colors = [INACTIVE, INACTIVE, ACTIVE, INACTIVE, ACTIVE, ACTIVE, INACTIVE, ACTIVE]

v0_data = [
    v0_headers,
    v0_vals,
    ["elem 7", "elem 6", "elem 5", "elem 4", "elem 3", "elem 2", "elem 1", "elem 0"],
    ["SKIP", "SKIP", "WRITE", "SKIP", "WRITE", "WRITE", "SKIP", "WRITE"],
]
cw = [0.83 * inch] * 8
v0_tbl = Table(v0_data, colWidths=cw)
cell_styles = [
    ("BACKGROUND", (0, 0), (-1, 0), HEADER),
    ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
    ("FONTSIZE", (0, 0), (-1, -1), 8),
    ("ALIGN", (0, 0), (-1, -1), "CENTER"),
    ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
    ("TOPPADDING", (0, 0), (-1, -1), 4),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
]
for col, bg in enumerate(v0_colors):
    cell_styles.append(("BACKGROUND", (col, 1), (col, 1), bg))
    cell_styles.append(("BACKGROUND", (col, 3), (col, 3), bg))
    if bg == ACTIVE:
        cell_styles.append(("TEXTCOLOR", (col, 3), (col, 3), colors.HexColor("#004400")))
        cell_styles.append(("FONTNAME", (col, 3), (col, 3), "Helvetica-Bold"))
    else:
        cell_styles.append(("TEXTCOLOR", (col, 3), (col, 3), colors.HexColor("#880000")))
v0_tbl.setStyle(TableStyle(cell_styles))
story.append(v0_tbl)
story.append(
    note(
        "Green = mask bit 1 → element written.  Red = mask bit 0 → element skipped (destination unchanged)."
    )
)
story.append(sp())

# ── SECTION 3 ────────────────────────────────────────────────────────────────
story.append(h1("3. The IDL Logic (What It Should Look Like)"))
story.append(body("With masking, the inner loop needs a guard:"))
story.append(
    mono(
        "for (U32 i = CSR[vstart].VALUE; i < CSR[vl].VALUE; i++) {\n"
        "  if (vm == 1'b1 || V[v0][i] == 1'b1) {\n"
        "    V[vd][...] = V[vs2][...] + V[vs1][...];   // only written when mask bit = 1\n"
        "  }\n"
        "  // else: V[vd][...] is untouched  (undisturbed policy)\n"
        "}\n"
        "CSR[vstart].VALUE = 0;"
    )
)
story.append(body("Without masking (current state — all 619 stubs):"))
story.append(
    mono(
        "for (U32 i = CSR[vstart].VALUE; i < CSR[vl].VALUE; i++) {\n"
        "  V[vd][...] = V[vs2][...] + V[vs1][...];   // writes ALL elements, no mask check\n"
        "}\n"
        "CSR[vstart].VALUE = 0;"
    )
)
story.append(sp())

# ── SECTION 4 — TEST EXAMPLE ─────────────────────────────────────────────────
story.append(h1("4. Worked Example: vadd.vv with Masking"))
story.append(
    body(
        "Instruction: <b>vadd.vv vd, vs2, vs1, v0</b> — add vs1 + vs2 element-wise, masked by v0. "
        "8 elements, SEW=32, vm=0 (masked mode)."
    )
)
story.append(sp(4))

story.append(h2("Register State Before Execution"))

before_data = [
    ["Register", "Elem 0", "Elem 1", "Elem 2", "Elem 3", "Elem 4", "Elem 5", "Elem 6", "Elem 7"],
    ["v0 (mask)", "1", "0", "1", "1", "0", "1", "0", "0"],
    ["vs2", "10", "20", "30", "40", "50", "60", "70", "80"],
    ["vs1", "1", "2", "3", "4", "5", "6", "7", "8"],
    ["vd (before)", "99", "99", "99", "99", "99", "99", "99", "99"],
]
mask_bits = [1, 0, 1, 1, 0, 1, 0, 0]
cw2 = [1.05 * inch] + [0.72 * inch] * 8
before_tbl = Table(before_data, colWidths=cw2)
before_styles = [
    ("BACKGROUND", (0, 0), (-1, 0), HEADER),
    ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
    ("FONTSIZE", (0, 0), (-1, -1), 8),
    ("ALIGN", (0, 0), (-1, -1), "CENTER"),
    ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
    ("TOPPADDING", (0, 0), (-1, -1), 4),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ("FONTNAME", (0, 1), (0, -1), "Helvetica-Bold"),
]
for col, bit in enumerate(mask_bits):
    bg = ACTIVE if bit == 1 else INACTIVE
    before_styles.append(("BACKGROUND", (col + 1, 1), (col + 1, 1), bg))
before_tbl.setStyle(TableStyle(before_styles))
story.append(before_tbl)
story.append(sp(6))

story.append(h2("Element-by-Element Execution"))

exec_data = [["Elem", "v0 bit", "vs2", "vs1", "Operation", "vd result", "Written?"]]
vs2_vals = [10, 20, 30, 40, 50, 60, 70, 80]
vs1_vals = [1, 2, 3, 4, 5, 6, 7, 8]
vd_before = 99
for i in range(8):
    bit = mask_bits[i]
    written = bit == 1
    result = str(vs2_vals[i] + vs1_vals[i]) if written else str(vd_before)
    op = f"{vs2_vals[i]} + {vs1_vals[i]} = {vs2_vals[i] + vs1_vals[i]}" if written else "—"
    write_str = "YES" if written else "NO (skip)"
    exec_data.append([str(i), str(bit), str(vs2_vals[i]), str(vs1_vals[i]), op, result, write_str])

cw3 = [0.45 * inch, 0.6 * inch, 0.6 * inch, 0.6 * inch, 1.6 * inch, 0.8 * inch, 0.85 * inch]
exec_tbl = Table(exec_data, colWidths=cw3)
exec_styles = [
    ("BACKGROUND", (0, 0), (-1, 0), HEADER),
    ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
    ("FONTSIZE", (0, 0), (-1, -1), 8),
    ("ALIGN", (0, 0), (-1, -1), "CENTER"),
    ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
    ("TOPPADDING", (0, 0), (-1, -1), 3),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
]
for i, bit in enumerate(mask_bits):
    row = i + 1
    bg = ACTIVE if bit == 1 else INACTIVE
    exec_styles.append(("BACKGROUND", (0, row), (-1, row), bg))
exec_tbl.setStyle(TableStyle(exec_styles))
story.append(exec_tbl)
story.append(
    note(
        "Green rows: mask bit = 1, element is written.  Red rows: mask bit = 0, vd keeps its original value (99)."
    )
)
story.append(sp(6))

story.append(h2("Register State After Execution"))
after_data = [
    ["Register", "Elem 0", "Elem 1", "Elem 2", "Elem 3", "Elem 4", "Elem 5", "Elem 6", "Elem 7"],
    ["vd (CORRECT — masked)", "11", "99", "33", "44", "99", "66", "99", "99"],
    ["vd (CURRENT — unmasked)", "11", "22", "33", "44", "55", "66", "77", "88"],
]
after_tbl = Table(after_data, colWidths=cw2)
after_styles = [
    ("BACKGROUND", (0, 0), (-1, 0), HEADER),
    ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
    ("FONTSIZE", (0, 0), (-1, -1), 8),
    ("ALIGN", (0, 0), (-1, -1), "CENTER"),
    ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
    ("TOPPADDING", (0, 0), (-1, -1), 4),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ("FONTNAME", (0, 1), (0, -1), "Helvetica-Bold"),
    ("BACKGROUND", (0, 1), (-1, 1), ACTIVE),
    ("BACKGROUND", (0, 2), (-1, 2), INACTIVE),
]
after_tbl.setStyle(TableStyle(after_styles))
story.append(after_tbl)
story.append(
    note(
        "Elements 1, 4, 6, 7 have mask bit = 0. Correct behavior: vd keeps 99. "
        "Current behavior: vd gets overwritten with the sum anyway — this is the bug masking would fix."
    )
)

# ── SECTION 5 — COMPILER GAP ─────────────────────────────────────────────────
story.append(h1("5. Why the IDL Compiler Cannot Support Masking Today"))
story.append(
    body(
        "The IDL compiler has a type system that assigns a type to every expression. "
        "The problem is that <b>V[v0][i]</b> — accessing a single bit of the mask register — "
        "is typed as <b>Bits&lt;1&gt;</b>, a generic 1-bit integer. "
        "That type cannot be used as a boolean condition in an <b>if</b> statement."
    )
)
story.append(sp(4))

story.append(h2("The Exact Type Error"))
story.append(
    mono(
        "if (vm == 1'b1 || V[v0][i] == 1'b1) { ... }\n"
        "                   ^^^^^^^^\n"
        "                   V[v0][i] → typed as Bits<1>\n"
        "                   Bits<1> is NOT convertible to boolean\n"
        "                   → TYPE ERROR: left-hand side of || must be boolean"
    )
)
story.append(sp(4))

story.append(h2("What Is Missing"))
gap_data = [
    ["Gap", "What's needed", "Status"],
    [
        "MaskBitType",
        "A new type in type.rb that knows it's a mask bit\nand is boolean-convertible",
        "Missing",
    ],
    [
        "Mask register detection",
        "Logic in ast.rb to recognise V[0][i] specifically\nand return MaskBitType instead of Bits<1>",
        "Missing",
    ],
]
gap_tbl = Table(gap_data, colWidths=[1.5 * inch, 3.5 * inch, 1.1 * inch])
gap_tbl.setStyle(
    TableStyle(
        [
            ("BACKGROUND", (0, 0), (-1, 0), HEADER),
            ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
            ("FONTSIZE", (0, 0), (-1, -1), 9),
            ("ALIGN", (0, 0), (0, -1), "LEFT"),
            ("ALIGN", (1, 0), (1, -1), "LEFT"),
            ("ALIGN", (2, 0), (-1, -1), "CENTER"),
            ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
            ("BACKGROUND", (2, 1), (2, -1), INACTIVE),
            ("FONTNAME", (2, 1), (2, -1), "Helvetica-Bold"),
            ("TOPPADDING", (0, 0), (-1, -1), 5),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ]
    )
)
story.append(gap_tbl)
story.append(sp(4))

story.append(h2("Current Workaround — Undisturbed Policy"))
story.append(
    body(
        "All 619 stubs and the 8 existing implementations use the <b>unmasked path</b>: "
        "the loop writes every element unconditionally. This is correct only when vm=1 "
        "(unmasked instruction). For masked instructions (vm=0) this silently ignores the "
        "mask — a spec violation. Fixing it requires the two compiler changes above."
    )
)
story.append(sp(4))

story.append(h2("Fix Scope (Compiler Changes Required)"))
story.append(
    mono(
        "# File: tools/ruby-gems/idlc/lib/idlc/type.rb\n"
        "# Add: MaskBitType class + boolean-convertible flag   (~70 lines)\n\n"
        "# File: tools/ruby-gems/idlc/lib/idlc/ast.rb\n"
        "# Add: V[0][i] detection → return MaskBitType          (~20 lines)\n\n"
        "# Estimated effort: ~2-3 days including tests"
    )
)

story.append(sp(10))
story.append(hr())
story.append(
    Paragraph(
        "Generated for Joseph Pak — RISC-V Vector IDL Implementation — 2026-07-07",
        ParagraphStyle(
            "footer", fontSize=8, fontName="Helvetica", textColor=colors.grey, alignment=TA_CENTER
        ),
    )
)

doc.build(story)
print(f"PDF written to {OUTPUT}")
