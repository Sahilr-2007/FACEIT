import os
import docx
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml import OxmlElement, parse_xml
from docx.oxml.ns import nsdecls, qn

def set_cell_background(cell, fill_hex):
    tcPr = cell._element.get_or_add_tcPr()
    shd = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{fill_hex}"/>')
    tcPr.append(shd)

def set_cell_margins(cell, top=140, bottom=140, left=180, right=180):
    tcPr = cell._element.get_or_add_tcPr()
    tcMar = parse_xml(f'''
        <w:tcMar {nsdecls("w")}>
            <w:top w:w="{top}" w:type="dxa"/>
            <w:bottom w:w="{bottom}" w:type="dxa"/>
            <w:left w:w="{left}" w:type="dxa"/>
            <w:right w:w="{right}" w:type="dxa"/>
        </w:tcMar>
    ''')
    tcPr.append(tcMar)

def set_table_borders(table, color="D1D5DB", sz="4", val="single"):
    tblPr = table._element.xpath('w:tblPr')
    if tblPr:
        borders = parse_xml(f'''
            <w:tblBorders {nsdecls("w")}>
                <w:top w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>
                <w:bottom w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>
                <w:left w:val="none"/>
                <w:right w:val="none"/>
                <w:insideH w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>
                <w:insideV w:val="none"/>
            </w:tblBorders>
        ''')
        tblPr[0].append(borders)

def build_feasibility_viability_report():
    doc = docx.Document()

    # Page setup - 0.8 inch margins
    for s in doc.sections:
        s.top_margin = Inches(0.8)
        s.bottom_margin = Inches(0.8)
        s.left_margin = Inches(0.8)
        s.right_margin = Inches(0.8)

    # Styles & Fonts
    normal_style = doc.styles['Normal']
    normal_style.font.name = 'Calibri'
    normal_style.font.size = Pt(11)
    normal_style.font.color.rgb = RGBColor(0x2D, 0x37, 0x48)

    # ---------------- HEADER TITLE BLOCK ----------------
    title_p = doc.add_paragraph()
    title_p.paragraph_format.space_before = Pt(0)
    title_p.paragraph_format.space_after = Pt(4)
    run_badge = title_p.add_run("SMART INDIA HACKATHON (SIH) — BUSINESS & TECHNICAL FEASIBILITY DOSSIER\n")
    run_badge.font.name = 'Calibri'
    run_badge.font.size = Pt(10)
    run_badge.font.bold = True
    run_badge.font.color.rgb = RGBColor(0x02, 0x84, 0xC7) # Cerulean

    run_title = title_p.add_run("Project FaceIT: Comprehensive Feasibility & Viability Analysis Report")
    run_title.font.name = 'Calibri Light'
    run_title.font.size = Pt(22)
    run_title.font.bold = True
    run_title.font.color.rgb = RGBColor(0x0F, 0x17, 0x2A) # Slate

    sub_p = doc.add_paragraph()
    sub_p.paragraph_format.space_before = Pt(2)
    sub_p.paragraph_format.space_after = Pt(14)
    sub_run = sub_p.add_run("Evaluation of Technical Feasibility, Commercial Viability, Macro Market Sizing (TAM/SAM/SOM), Competitive Landscape, Deployment Risks & Strategic Mitigation Frameworks")
    sub_run.font.size = Pt(11)
    sub_run.font.italic = True
    sub_run.font.color.rgb = RGBColor(0x47, 0x55, 0x69)

    # Divider line
    div_table = doc.add_table(rows=1, cols=1)
    div_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    div_cell = div_table.rows[0].cells[0]
    set_cell_background(div_cell, "0284C7")
    div_cell.width = Inches(6.9)
    set_cell_margins(div_cell, top=20, bottom=20, left=0, right=0)
    p_empty = div_cell.paragraphs[0]
    p_empty.paragraph_format.space_before = Pt(0)
    p_empty.paragraph_format.space_after = Pt(0)

    doc.add_paragraph().paragraph_format.space_after = Pt(8)

    # ---------------- 1. EXECUTIVE SUMMARY: FEASIBILITY VS. VIABILITY ----------------
    h1 = doc.add_paragraph()
    h1.paragraph_format.space_before = Pt(12)
    h1.paragraph_format.space_after = Pt(4)
    r1 = h1.add_run("1. Executive Summary: Defining Feasibility vs. Viability")
    r1.font.name = 'Calibri'
    r1.font.size = Pt(15)
    r1.font.bold = True
    r1.font.color.rgb = RGBColor(0x0F, 0x17, 0x2A)

    p_exec = doc.add_paragraph()
    p_exec.paragraph_format.space_after = Pt(6)
    p_exec.add_run(
        "In technological innovation and startup evaluation (particularly in national forums like SIH), "
        "evaluators distinguish strictly between Feasibility ('Can this solution actually be engineered and deployed reliably with available tools?') "
        "and Viability ('Does this solution possess long-term economic sustainability, market demand, regulatory survivability, and scalable adoption?'). "
        "Project FaceIT demonstrates a unique convergence: it is both technically feasible today on standard consumer mobile hardware and commercially viable by addressing India's multi-billion dollar out-of-pocket health expenditure crisis."
    )

    # Comparative Definition Table
    t_fv = doc.add_table(rows=6, cols=3)
    t_fv.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_borders(t_fv)

    fv_headers = ["Evaluation Dimension", "Feasibility Pillar ('Can We Build & Run It?')", "Viability Pillar ('Can It Scale & Survive Long-Term?')"]
    for i, title in enumerate(fv_headers):
        cell = t_fv.rows[0].cells[i]
        set_cell_background(cell, "0F172A")
        set_cell_margins(cell, top=140, bottom=140, left=140, right=140)
        p = cell.paragraphs[0]
        r = p.add_run(title)
        r.bold = True
        r.font.size = Pt(9.5)
        r.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)

    fv_data = [
        ("Core Engineering & Science", "Deployable on standard smartphone cameras; hybrid PyTorch edge ML + Gemini LLM vision cascade running at sub-second response times.", "Addresses the acute 1:130,000 dermatologist shortage; fulfills real demand across 1.4B underserved citizens."),
        ("Financial & Cost Dynamics", "Negligible on-device inference compute; lightweight FastAPI server hosting on scalable cloud nodes costing < ₹0.04 per consultation.", "Freemium B2C model + B2B dermatologist telehealth referrals + verified PMBJP generic drug discovery commissions."),
        ("Operational Scalability", "Serverless horizontal container scaling; handles traffic surges using automated multi-model cascade with zero 503 capacity downtime.", "Zero physical clinic asset overhead; purely software-driven delivery reaching Tier-2, Tier-3, and rural pin codes without logistics friction."),
        ("Data & Knowledge Grounding", "Integration with National Drug Databases (PMBJP / NLEM) and OpenFoodFacts 2.5M+ global barcode repositories.", "Strong public policy synergy with Ministry of Chemicals & Fertilizers, boosting public health credibility and rapid institutional adoption."),
        ("Regulatory & Compliance", "Enforces non-diagnostic clinical triage disclaimers; fully compliant with India's Digital Personal Data Protection (DPDP) Act 2023.", "High clinical ethics and anti-dysmorphia safeguards guarantee strong brand longevity, user trust, and medical advisory board backing.")
    ]

    for row_idx, row_vals in enumerate(fv_data):
        for col_idx, text in enumerate(row_vals):
            cell = t_fv.rows[row_idx + 1].cells[col_idx]
            bg_col = "F8FAFC" if row_idx % 2 == 1 else "FFFFFF"
            set_cell_background(cell, bg_col)
            set_cell_margins(cell, top=120, bottom=120, left=140, right=140)
            p = cell.paragraphs[0]
            r = p.add_run(text)
            r.font.size = Pt(9)
            if col_idx == 0:
                r.bold = True
                r.font.color.rgb = RGBColor(0x0F, 0x17, 0x2A)
            elif col_idx == 1:
                r.font.color.rgb = RGBColor(0x03, 0x69, 0xA1)
            else:
                r.font.color.rgb = RGBColor(0x0F, 0x76, 0x6E)

    doc.add_paragraph().paragraph_format.space_after = Pt(8)

    # ---------------- 2. MARKET SIZING & OPPORTUNITY REPORT ----------------
    h2 = doc.add_paragraph()
    h2.paragraph_format.space_before = Pt(14)
    h2.paragraph_format.space_after = Pt(4)
    r2 = h2.add_run("2. Comprehensive Market Sizing & Opportunity Analysis")
    r2.font.name = 'Calibri'
    r2.font.size = Pt(15)
    r2.font.bold = True
    r2.font.color.rgb = RGBColor(0x0F, 0x17, 0x2A)

    p_mkt_desc = doc.add_paragraph()
    p_mkt_desc.paragraph_format.space_after = Pt(6)
    p_mkt_desc.add_run(
        "The convergence of rising cosmetic awareness, toxic chemical anxiety, and smartphone penetration has created an unprecedented economic opportunity. India's youth demographic (472M Gen-Z and Millennials under 25) represents the world's largest consumer base actively demanding ingredient transparency and accessible skincare."
    )

    # Market Growth Projections Table
    t_mkt = doc.add_table(rows=5, cols=4)
    t_mkt.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_borders(t_mkt)

    mkt_headers = ["Market Sector", "Current Valuation (2024)", "Projected Size (2030)", "Compound Annual Growth (CAGR)"]
    for i, title in enumerate(mkt_headers):
        cell = t_mkt.rows[0].cells[i]
        set_cell_background(cell, "0F172A")
        set_cell_margins(cell, top=140, bottom=140, left=120, right=120)
        p = cell.paragraphs[0]
        r = p.add_run(title)
        r.bold = True
        r.font.size = Pt(9.5)
        r.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)

    mkt_data = [
        ("India Beauty & Personal Care (BPC)", "$15.6 Billion", "$28.1 Billion", "+9.3% CAGR"),
        ("Global AI Beauty-Tech & Dermatology AI", "$3.9 Billion", "$13.3 Billion", "+22.4% CAGR"),
        ("India HealthTech & Telemedicine Apps", "$6.1 Billion", "$17.4 Billion", "+19.1% CAGR"),
        ("Global Food & Cosmetic Ingredient Intelligence", "$1.2 Billion", "$4.8 Billion", "+26.1% CAGR")
    ]

    for row_idx, row_vals in enumerate(mkt_data):
        for col_idx, text in enumerate(row_vals):
            cell = t_mkt.rows[row_idx + 1].cells[col_idx]
            bg_col = "F8FAFC" if row_idx % 2 == 1 else "FFFFFF"
            set_cell_background(cell, bg_col)
            set_cell_margins(cell, top=120, bottom=120, left=120, right=120)
            p = cell.paragraphs[0]
            r = p.add_run(text)
            r.font.size = Pt(9)
            if col_idx == 0:
                r.bold = True
                r.font.color.rgb = RGBColor(0x0F, 0x17, 0x2A)
            elif col_idx == 3:
                r.bold = True
                r.font.color.rgb = RGBColor(0x15, 0x80, 0x3D) # Green
            else:
                r.font.color.rgb = RGBColor(0x33, 0x41, 0x55)

    doc.add_paragraph().paragraph_format.space_after = Pt(6)

    # TAM / SAM / SOM Breakdown Box
    t_tam = doc.add_table(rows=4, cols=3)
    t_tam.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_borders(t_tam)

    tam_headers = ["Market Horizon", "Target Metric & Valuation", "Strategic Definition & Scope"]
    for i, title in enumerate(tam_headers):
        cell = t_tam.rows[0].cells[i]
        set_cell_background(cell, "1E293B")
        set_cell_margins(cell, top=140, bottom=140, left=140, right=140)
        p = cell.paragraphs[0]
        r = p.add_run(title)
        r.bold = True
        r.font.size = Pt(9.5)
        r.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)

    tam_data = [
        ("TAM (Total Addressable Market)", "₹1,30,000+ Crore ($15.6B)", "The total Indian personal care, OTC dermatological formulations, and mobile health consultation expenditure."),
        ("SAM (Serviceable Available Market)", "₹28,000 Crore ($3.4B)", "Smartphone-owning Indian consumers (aged 16-45) actively seeking clinical acne care, anti-pigmentation solutions, and clean beauty items."),
        ("SOM (Serviceable Obtainable Market)", "₹620 Crore ($75M)", "Capturing 2.2% market share over 36 months across Tier-1/Tier-2 college students, young professionals, and cost-conscious chronic skin patients.")
    ]

    for row_idx, row_vals in enumerate(tam_data):
        for col_idx, text in enumerate(row_vals):
            cell = t_tam.rows[row_idx + 1].cells[col_idx]
            bg_col = "F0F9FF" if col_idx == 1 else ("F8FAFC" if row_idx % 2 == 1 else "FFFFFF")
            set_cell_background(cell, bg_col)
            set_cell_margins(cell, top=120, bottom=120, left=140, right=140)
            p = cell.paragraphs[0]
            r = p.add_run(text)
            r.font.size = Pt(9)
            if col_idx == 0:
                r.bold = True
                r.font.color.rgb = RGBColor(0x0F, 0x17, 0x2A)
            elif col_idx == 1:
                r.bold = True
                r.font.color.rgb = RGBColor(0x02, 0x84, 0xC7)
            else:
                r.font.color.rgb = RGBColor(0x33, 0x41, 0x55)

    doc.add_paragraph().paragraph_format.space_after = Pt(8)

    # ---------------- 3. COMPETITIVE LANDSCAPE & MATRIX ----------------
    h3 = doc.add_paragraph()
    h3.paragraph_format.space_before = Pt(14)
    h3.paragraph_format.space_after = Pt(4)
    r3 = h3.add_run("3. Competitive Landscape: Direct & Indirect Competitor Analysis")
    r3.font.name = 'Calibri'
    r3.font.size = Pt(15)
    r3.font.bold = True
    r3.font.color.rgb = RGBColor(0x0F, 0x17, 0x2A)

    p_comp = doc.add_paragraph()
    p_comp.paragraph_format.space_after = Pt(6)
    p_comp.add_run(
        "FaceIT operates at the intersection of three established multi-billion dollar verticals: AI Dermatology Apps, Ingredient Analyzers, and E-Pharmacy Aggregators. While each vertical possesses incumbents, all suffer from critical operational deficiencies that FaceIT solves:"
    )

    # Competitor Breakdown Bullets
    comps = [
        ("CureSkin (Direct HealthTech Competitor):", "Provides photo-based facial consultations but forces users into expensive, proprietary in-house skincare bundles costing ₹1,200 to ₹2,500/month. Offers zero generic medicine price transparency, zero ingredient label scanning, and zero food/hair multi-domain support."),
        ("Yuka / Think Dirty (International Ingredient Apps):", "Pioneered barcode ingredient grading but completely disconnected from the Indian market. Over 75% of Indian FMCG cosmetic products fail to scan due to unindexed databases. Lacks clinical facial photo diagnostics, medicine price tracking, and doctor escalation."),
        ("Tata 1mg / PharmEasy (E-Pharmacy Aggregators):", "Serve as commercial medicine marketplaces but operate on affiliate commissions. Their search algorithms prioritize high-margin branded pharmaceuticals over government generic Jan Aushadhi alternatives and lack AI facial diagnostics."),
        ("Looksmaxxing AI Apps (Youth Trend Competitors):", "Gamified facial scoring apps (e.g. Umax) that assign toxic aesthetic ratings ('attractiveness scores'), triggering body dysmorphia among teens. They lack certified clinical utility, zero biochemical ingredient analysis, and zero healthcare linkage.")
    ]

    for c_title, c_desc in comps:
        p_c = doc.add_paragraph(style='List Bullet')
        p_c.paragraph_format.space_after = Pt(4)
        rc_t = p_c.add_run(c_title + " ")
        rc_t.bold = True
        rc_t.font.color.rgb = RGBColor(0x02, 0x84, 0xC7)
        p_c.add_run(c_desc)

    doc.add_paragraph().paragraph_format.space_after = Pt(8)

    # ---------------- 4. CHALLENGES & MITIGATION STRATEGIES ----------------
    h4 = doc.add_paragraph()
    h4.paragraph_format.space_before = Pt(14)
    h4.paragraph_format.space_after = Pt(4)
    r4 = h4.add_run("4. Key Operational Challenges & Strategic Mitigation Frameworks")
    r4.font.name = 'Calibri'
    r4.font.size = Pt(15)
    r4.font.bold = True
    r4.font.color.rgb = RGBColor(0x0F, 0x17, 0x2A)

    p_chal_intro = doc.add_paragraph()
    p_chal_intro.paragraph_format.space_after = Pt(6)
    p_chal_intro.add_run(
        "Deploying an AI-based clinical health application in India introduces specific technical, medical, regulatory, and commercial friction points. FaceIT incorporates proactive architectural and organizational mitigations for each challenge:"
    )

    # Table of Challenges and Mitigations
    t_chal = doc.add_table(rows=6, cols=3)
    t_chal.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_borders(t_chal)

    chal_headers = ["Key Operational Challenge", "Risk Impact & Vulnerability", "FaceIT Engineering & Strategic Mitigation"]
    for i, title in enumerate(chal_headers):
        cell = t_chal.rows[0].cells[i]
        set_cell_background(cell, "0F172A")
        set_cell_margins(cell, top=140, bottom=140, left=140, right=140)
        p = cell.paragraphs[0]
        r = p.add_run(title)
        r.bold = True
        r.font.size = Pt(9.5)
        r.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)

    chal_data = [
        ("1. Uncontrolled Camera Lighting & Skewed Selfies", "Variable smartphone cameras, poor indoor lighting, and blurry angles can lead to inaccurate skin barrier score calculations.", "Automated Pre-Processing Gate: Built-in OpenCV/PIL image validation inspects luminance histogram and facial symmetry before dispatching to API. Rejects sub-optimal photos with real-time feedback guidance."),
        ("2. Public Trust & Medical-Legal Liability", "Providing automated health advice risks regulatory backlash if misinterpreted as an official clinical doctor prescription.", "Strict Clinical Triage Disclaimer & Doctor Escalation: App explicitly states 'Non-Diagnostic Triage Assistant'. Detects high-severity conditions (Grade 3/4 acne, infections) and automatically forces in-person doctor mapping via Google Places."),
        ("3. High Cloud AI Inference Costs at Scale", "Processing high-resolution images via LLM APIs across millions of users can create unsustainable API cost burn.", "Edge Pre-Filtering & Hybrid Multi-Tier AI: Compresses images to 600x600 thumbnails on device; runs PyTorch edge models for local classification; caches common product barcodes locally; queries low-cost Gemini Flash-Lite tiers costing < ₹0.04/scan."),
        ("4. Low Awareness of Jan Aushadhi (PMBJP) Kendras", "Patients may not know where their nearest government generic pharmacy is located or doubt generic drug efficacy.", "Integrated Geo-Locator & WHO-GMP Quality Verification: Maps live distances to nearest PMBJP Kendras with official store codes and highlights that Jan Aushadhi formulations meet identical IP / WHO-GMP pharmacopeia standards."),
        ("5. User Dropout & Treatment Abandonment (65% Rate)", "Patients routinely abandon topical skin routines within 7 to 10 days before the biological 28-day turnover cycle completes.", "Duolingo-Inspired Loss-Aversion Psychology: Embeds animated Mascot mood physics (Zen, Hyped, Anxious, Heartbroken), AM/PM routine checklists, and Glow XP streaks that turn medical adherence into a daily game.")
    ]

    for row_idx, row_vals in enumerate(chal_data):
        for col_idx, text in enumerate(row_vals):
            cell = t_chal.rows[row_idx + 1].cells[col_idx]
            bg_col = "F8FAFC" if row_idx % 2 == 1 else "FFFFFF"
            set_cell_background(cell, bg_col)
            set_cell_margins(cell, top=120, bottom=120, left=140, right=140)
            p = cell.paragraphs[0]
            r = p.add_run(text)
            r.font.size = Pt(9)
            if col_idx == 0:
                r.bold = True
                r.font.color.rgb = RGBColor(0x0F, 0x17, 0x2A)
            elif col_idx == 1:
                r.font.color.rgb = RGBColor(0xDC, 0x26, 0x26) # Danger Red
            else:
                r.font.color.rgb = RGBColor(0x15, 0x80, 0x3D) # Solution Green

    doc.add_paragraph().paragraph_format.space_after = Pt(8)

    # ---------------- 5. FINANCIAL MODEL & REVENUE VIABILITY ----------------
    h5 = doc.add_paragraph()
    h5.paragraph_format.space_before = Pt(14)
    h5.paragraph_format.space_after = Pt(4)
    r5 = h5.add_run("5. Sustainable Financial Model & Commercial Viability")
    r5.font.name = 'Calibri'
    r5.font.size = Pt(15)
    r5.font.bold = True
    r5.font.color.rgb = RGBColor(0x0F, 0x17, 0x2A)

    p_rev = doc.add_paragraph()
    p_rev.paragraph_format.space_after = Pt(6)
    p_rev.add_run(
        "FaceIT avoids predatory medicine markups by establishing a diversified, ethical multi-stream revenue model that sustains free tier accessibility for underprivileged citizens while monetizing high-value clinical features:"
    )

    rev_streams = [
        ("Stream 1: B2C Freemium Pro Subscription (₹149/month or ₹999/year)", "Core facial scans, Jan Aushadhi generic lookups, and basic routines remain 100% free forever. Premium 'FaceIT Gold' unlocks unlimited 3-domain barcode scans, 90-Day generative future self skin projections, advanced ingredient interaction deep-dives, and priority 24/7 AI Coach access."),
        ("Stream 2: B2B Telehealth Doctor Referral Marketplace (₹100-₹150 per qualified lead)", "When users with severe skin anomalies require professional clinical intervention, FaceIT facilitates seamless telehealth or in-clinic booking with verified local dermatologists, earning a compliant platform referral fee."),
        ("Stream 3: Ethical E-Pharmacy Commercial Affiliate Integration (2-5% commission)", "When patients opt for branded medications (if a Jan Aushadhi Kendra is unavailable locally), FaceIT earns standard affiliate commissions from integrated delivery partners (Truemeds, Tata 1mg, Apollo) without compromising price transparency."),
        ("Stream 4: Anonymized Epidemiological Skin Health Insights (B2B SaaS)", "Aggregated, non-PII dermatological trend analytics (e.g. regional prevalence of fungal breakouts or barrier damage across climatic zones) licensed to research universities, public health agencies, and pharmaceutical developers.")
    ]

    for st, sd in rev_streams:
        p_s = doc.add_paragraph(style='List Bullet')
        p_s.paragraph_format.space_after = Pt(4)
        rst = p_s.add_run(st + " — ")
        rst.bold = True
        rst.font.color.rgb = RGBColor(0x02, 0x84, 0xC7)
        p_s.add_run(sd)

    doc.add_paragraph().paragraph_format.space_after = Pt(8)

    # ---------------- 6. SUMMARY FOR SIH PRESENTATION SLIDES ----------------
    h6 = doc.add_paragraph()
    h6.paragraph_format.space_before = Pt(14)
    h6.paragraph_format.space_after = Pt(4)
    r6 = h6.add_run("6. Executive Pitch Deck Summary: Feasibility & Viability")
    r6.font.name = 'Calibri'
    r6.font.size = Pt(13.5)
    r6.font.bold = True
    r6.font.color.rgb = RGBColor(0x0F, 0x17, 0x2A)

    p_pitch = doc.add_paragraph()
    p_pitch.paragraph_format.space_after = Pt(6)
    p_pitch.add_run(
        "“Judges, innovation without viability is merely a science project. Project FaceIT is engineered for immediate real-world deployment. Technically, it runs on standard mobile hardware with sub-second hybrid AI and local fallback engines. Financially, it taps into India's $15.6B personal care market and directly lowers out-of-pocket medical expenditure by up to 88% through Jan Aushadhi integration. By tackling doctor shortages, regulatory safety, and patient dropout psychology simultaneously, FaceIT represents the most viable, scalable, and socially impactful healthcare solution at SIH.”"
    )
    p_pitch.runs[0].font.italic = True
    p_pitch.runs[0].font.size = Pt(11)
    p_pitch.runs[0].font.color.rgb = RGBColor(0x1E, 0x29, 0x3B)

    # Output file path
    out_dir = r"c:\Users\sahil\Desktop\skin care app"
    out_path = os.path.join(out_dir, "FaceIT_SIH_Feasibility_and_Viability_Report.docx")
    doc.save(out_path)
    print(f"[SUCCESS] Feasibility & Viability Report saved to: {out_path}")

if __name__ == "__main__":
    build_feasibility_viability_report()
