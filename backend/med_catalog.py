"""
Curated catalog of Indian dermatological medications mapping branded trade names
to Pradhan Mantri Bhartiya Janaushadhi Pariyojana (PMBJP) generic equivalents and
commercial e-pharmacy platforms sorted with transparent price comparison.
"""

from typing import Dict, Any, List, Optional
import re

DERMATOLOGY_MED_CATALOG: List[Dict[str, Any]] = [
    {
        "id": "clindamycin_nicotinamide",
        "salt_name": "Clindamycin Phosphate 1% + Nicotinamide 4%",
        "category": "Acne & Outbreak Antibacterial",
        "form": "Gel (20g)",
        "common_brands": ["Clindac-A", "Faceclin", "Acnesol", "Nilac", "Clinmiskin"],
        "branded_mrp_avg": 260.0,
        "jan_aushadhi": {
            "scheme": "Jan Aushadhi (PMBJP)",
            "item_name": "Clindamycin & Nicotinamide Gel 20g",
            "pmbjp_code": "PMBJP-DERM-0142",
            "gov_price": 35.0,
            "savings_inr": 225.0,
            "savings_percent": 86.5,
            "quality_standard": "IP / WHO-GMP Standard",
            "locator_url": "https://janaushadhi.gov.in/KendraDetails.aspx"
        },
        "e_pharmacies": [
            {"name": "PharmEasy", "price": 208.0, "discount": "20% OFF", "delivery": "1-2 Days", "url": "https://pharmeasy.in"},
            {"name": "Tata 1mg", "price": 215.0, "discount": "17% OFF", "delivery": "1-2 Days", "url": "https://1mg.com"},
            {"name": "Netmeds", "price": 218.0, "discount": "16% OFF", "delivery": "2-3 Days", "url": "https://netmeds.com"},
            {"name": "Apollo 24/7", "price": 220.0, "discount": "15% OFF", "delivery": "2-Hour Express", "url": "https://apollopharmacy.in"},
            {"name": "Truemeds", "price": 125.0, "discount": "52% OFF", "delivery": "2-3 Days", "url": "https://truemeds.in"}
        ],
        "clinical_action": "Targeted topical antibacterial that clears inflammatory acne lesions while Nicotinamide reduces localized post-blemish redness without skin barrier damage.",
        "usage_guide": "Apply thin layer to affected zones once daily at night after gentle cleansing. Always layer with a light moisturizer."
    },
    {
        "id": "tretinoin_004",
        "salt_name": "Tretinoin Microsphere 0.04% / 0.025%",
        "category": "Cellular Turnover & Anti-Acne Retinoid",
        "form": "Gel / Cream (20g)",
        "common_brands": ["Supatret", "Retino-A", "A-Ret", "Revize-Micro", "Tretiheal"],
        "branded_mrp_avg": 380.0,
        "jan_aushadhi": {
            "scheme": "Jan Aushadhi (PMBJP)",
            "item_name": "Tretinoin Cream / Gel 0.025% 20g",
            "pmbjp_code": "PMBJP-DERM-0219",
            "gov_price": 45.0,
            "savings_inr": 335.0,
            "savings_percent": 88.2,
            "quality_standard": "IP / WHO-GMP Standard",
            "locator_url": "https://janaushadhi.gov.in/KendraDetails.aspx"
        },
        "e_pharmacies": [
            {"name": "PharmEasy", "price": 305.0, "discount": "20% OFF", "delivery": "1-2 Days", "url": "https://pharmeasy.in"},
            {"name": "Tata 1mg", "price": 310.0, "discount": "18% OFF", "delivery": "1-2 Days", "url": "https://1mg.com"},
            {"name": "Netmeds", "price": 315.0, "discount": "17% OFF", "delivery": "2 Days", "url": "https://netmeds.com"},
            {"name": "Apollo 24/7", "price": 325.0, "discount": "14% OFF", "delivery": "Same Day", "url": "https://apollopharmacy.in"},
            {"name": "Truemeds", "price": 140.0, "discount": "63% OFF", "delivery": "2-3 Days", "url": "https://truemeds.in"}
        ],
        "clinical_action": "Accelerates epidermal renewal to unblock micro-comedones, refine congested pores, and improve long-term skin smoothness.",
        "usage_guide": "Nighttime use only. Use pea-sized quantity using the sandwich method (moisturizer -> tretinoin -> moisturizer) to avoid irritation. Daily SPF 50 required."
    },
    {
        "id": "adapalene_bpo",
        "salt_name": "Adapalene 0.1% + Benzoyl Peroxide 2.5%",
        "category": "Moderate Inflammatory Acne Combi-Gel",
        "form": "Gel (15g)",
        "common_brands": ["Epiduo", "Adaferin-BP", "Deriva-BPO", "Persol-AC"],
        "branded_mrp_avg": 490.0,
        "jan_aushadhi": {
            "scheme": "Jan Aushadhi (PMBJP)",
            "item_name": "Adapalene & Benzoyl Peroxide Gel 15g",
            "pmbjp_code": "PMBJP-DERM-0304",
            "gov_price": 72.0,
            "savings_inr": 418.0,
            "savings_percent": 85.3,
            "quality_standard": "IP / WHO-GMP Standard",
            "locator_url": "https://janaushadhi.gov.in/KendraDetails.aspx"
        },
        "e_pharmacies": [
            {"name": "PharmEasy", "price": 390.0, "discount": "20% OFF", "delivery": "1-2 Days", "url": "https://pharmeasy.in"},
            {"name": "Tata 1mg", "price": 398.0, "discount": "19% OFF", "delivery": "1-2 Days", "url": "https://1mg.com"},
            {"name": "Netmeds", "price": 405.0, "discount": "17% OFF", "delivery": "2 Days", "url": "https://netmeds.com"},
            {"name": "Apollo 24/7", "price": 415.0, "discount": "15% OFF", "delivery": "2-Hour Express", "url": "https://apollopharmacy.in"},
            {"name": "Truemeds", "price": 180.0, "discount": "63% OFF", "delivery": "2-3 Days", "url": "https://truemeds.in"}
        ],
        "clinical_action": "Dual-action topical combining micro-comedolytic retinoid with fast-acting oxidizing antimicrobial to prevent deep breakouts.",
        "usage_guide": "Apply sparingly once daily at bedtime on dry skin. Avoid eye contours and corners of the mouth."
    },
    {
        "id": "salicylic_acid",
        "salt_name": "Salicylic Acid 2% Ointment / Face Wash",
        "category": "Keratolytic BHA & Sebum Control",
        "form": "Wash / Gel (60ml / 30g)",
        "common_brands": ["Saslic DS", "Sebogel", "Salisia", "Salicylix SF 6%"],
        "branded_mrp_avg": 340.0,
        "jan_aushadhi": {
            "scheme": "Jan Aushadhi (PMBJP)",
            "item_name": "Salicylic Acid Ointment 2% / 6% 30g",
            "pmbjp_code": "PMBJP-DERM-0089",
            "gov_price": 28.0,
            "savings_inr": 312.0,
            "savings_percent": 91.7,
            "quality_standard": "IP / WHO-GMP Standard",
            "locator_url": "https://janaushadhi.gov.in/KendraDetails.aspx"
        },
        "e_pharmacies": [
            {"name": "PharmEasy", "price": 275.0, "discount": "19% OFF", "delivery": "1-2 Days", "url": "https://pharmeasy.in"},
            {"name": "Tata 1mg", "price": 285.0, "discount": "16% OFF", "delivery": "1-2 Days", "url": "https://1mg.com"},
            {"name": "Netmeds", "price": 288.0, "discount": "15% OFF", "delivery": "2-3 Days", "url": "https://netmeds.com"},
            {"name": "Apollo 24/7", "price": 295.0, "discount": "13% OFF", "delivery": "2-Hour Express", "url": "https://apollopharmacy.in"}
        ],
        "clinical_action": "Lipophilic beta-hydroxy acid that penetrates into sebaceous pores, dissolving sebum plugs and gently sloughing off dead surface cells.",
        "usage_guide": "Use 2-3 times weekly for oily, congested skin. Rinse thoroughly after 60 seconds."
    },
    {
        "id": "azelaic_acid",
        "salt_name": "Azelaic Acid 10% / 20%",
        "category": "Hyperpigmentation, PIH & Rosacea",
        "form": "Gel / Cream (15g)",
        "common_brands": ["Aziderm", "Picspot", "Exazel-N", "Azelderm"],
        "branded_mrp_avg": 320.0,
        "jan_aushadhi": {
            "scheme": "Jan Aushadhi (PMBJP)",
            "item_name": "Azelaic Acid Cream 10% 15g",
            "pmbjp_code": "PMBJP-DERM-0412",
            "gov_price": 58.0,
            "savings_inr": 262.0,
            "savings_percent": 81.8,
            "quality_standard": "IP / WHO-GMP Standard",
            "locator_url": "https://janaushadhi.gov.in/KendraDetails.aspx"
        },
        "e_pharmacies": [
            {"name": "PharmEasy", "price": 260.0, "discount": "19% OFF", "delivery": "1-2 Days", "url": "https://pharmeasy.in"},
            {"name": "Tata 1mg", "price": 265.0, "discount": "17% OFF", "delivery": "1-2 Days", "url": "https://1mg.com"},
            {"name": "Netmeds", "price": 270.0, "discount": "16% OFF", "delivery": "2-3 Days", "url": "https://netmeds.com"},
            {"name": "Apollo 24/7", "price": 275.0, "discount": "14% OFF", "delivery": "Same Day", "url": "https://apollopharmacy.in"}
        ],
        "clinical_action": "Directly inhibits abnormal melanocyte activity to fade dark marks (PIH) while soothing vascular redness and barrier sensitivity.",
        "usage_guide": "Can be used morning or night. Non-irritating and suitable for sensitive skin types under regular hydration."
    },
    {
        "id": "ketoconazole",
        "salt_name": "Ketoconazole 2% Topical",
        "category": "Antifungal (Malassezia & Fungal Acne / Dandruff)",
        "form": "Lotion / Cream / Shampoo (60ml / 30g)",
        "common_brands": ["Nizral", "Scalpe Pro", "Danfree", "Keralin", "Fungicide"],
        "branded_mrp_avg": 290.0,
        "jan_aushadhi": {
            "scheme": "Jan Aushadhi (PMBJP)",
            "item_name": "Ketoconazole Lotion / Cream 2% 30g",
            "pmbjp_code": "PMBJP-DERM-0055",
            "gov_price": 38.0,
            "savings_inr": 252.0,
            "savings_percent": 86.9,
            "quality_standard": "IP / WHO-GMP Standard",
            "locator_url": "https://janaushadhi.gov.in/KendraDetails.aspx"
        },
        "e_pharmacies": [
            {"name": "PharmEasy", "price": 235.0, "discount": "19% OFF", "delivery": "1-2 Days", "url": "https://pharmeasy.in"},
            {"name": "Tata 1mg", "price": 240.0, "discount": "17% OFF", "delivery": "1-2 Days", "url": "https://1mg.com"},
            {"name": "Netmeds", "price": 242.0, "discount": "16% OFF", "delivery": "2 Days", "url": "https://netmeds.com"},
            {"name": "Apollo 24/7", "price": 248.0, "discount": "14% OFF", "delivery": "2-Hour Express", "url": "https://apollopharmacy.in"}
        ],
        "clinical_action": "Disrupts fungal cell membranes to resolve stubborn forehead micro-bumps (folliculitis) and flaky epidermal scaling.",
        "usage_guide": "Apply to wet skin/scalp, lather, leave on for 3 to 5 minutes, then rinse cleanly. Use 2-3 times weekly."
    },
    {
        "id": "minoxidil_5",
        "salt_name": "Minoxidil 5% Topical Solution",
        "category": "Hair Follicle Stimulator & Vasodilator",
        "form": "Solution (60ml)",
        "common_brands": ["Mintop", "Tugain", "Morr 5%", "Imxia", "Hair4U"],
        "branded_mrp_avg": 780.0,
        "jan_aushadhi": {
            "scheme": "Jan Aushadhi (PMBJP)",
            "item_name": "Minoxidil Topical Solution 5% 60ml",
            "pmbjp_code": "PMBJP-DERM-0518",
            "gov_price": 165.0,
            "savings_inr": 615.0,
            "savings_percent": 78.8,
            "quality_standard": "IP / WHO-GMP Standard",
            "locator_url": "https://janaushadhi.gov.in/KendraDetails.aspx"
        },
        "e_pharmacies": [
            {"name": "PharmEasy", "price": 610.0, "discount": "22% OFF", "delivery": "1-2 Days", "url": "https://pharmeasy.in"},
            {"name": "Tata 1mg", "price": 620.0, "discount": "20% OFF", "delivery": "1-2 Days", "url": "https://1mg.com"},
            {"name": "Netmeds", "price": 630.0, "discount": "19% OFF", "delivery": "2 Days", "url": "https://netmeds.com"},
            {"name": "Apollo 24/7", "price": 645.0, "discount": "17% OFF", "delivery": "Same Day", "url": "https://apollopharmacy.in"}
        ],
        "clinical_action": "Stimulates microvascular circulation around hair follicles to extend the active anagen growth cycle.",
        "usage_guide": "Apply 1ml with dropper directly to clean, dry scalp areas twice daily. Wash hands with soap immediately after."
    },
    {
        "id": "mupirocin",
        "salt_name": "Mupirocin 2% Ointment",
        "category": "Bacterial Skin Infection / Folliculitis",
        "form": "Ointment (5g)",
        "common_brands": ["T-Bact", "Bactroban", "Mupimet", "Supirocin"],
        "branded_mrp_avg": 185.0,
        "jan_aushadhi": {
            "scheme": "Jan Aushadhi (PMBJP)",
            "item_name": "Mupirocin Ointment 2% 5g",
            "pmbjp_code": "PMBJP-DERM-0082",
            "gov_price": 32.0,
            "savings_inr": 153.0,
            "savings_percent": 82.7,
            "quality_standard": "IP / WHO-GMP Standard",
            "locator_url": "https://janaushadhi.gov.in/KendraDetails.aspx"
        },
        "e_pharmacies": [
            {"name": "PharmEasy", "price": 150.0, "discount": "19% OFF", "delivery": "1-2 Days", "url": "https://pharmeasy.in"},
            {"name": "Tata 1mg", "price": 155.0, "discount": "16% OFF", "delivery": "1-2 Days", "url": "https://1mg.com"},
            {"name": "Netmeds", "price": 156.0, "discount": "15% OFF", "delivery": "2 Days", "url": "https://netmeds.com"},
            {"name": "Apollo 24/7", "price": 160.0, "discount": "13% OFF", "delivery": "2-Hour Express", "url": "https://apollopharmacy.in"}
        ],
        "clinical_action": "High-potency topical antibacterial for superficial bacterial skin infections and inflamed pustular lesions.",
        "usage_guide": "Apply a thin film to the affected skin area 2-3 times daily for 5-7 days under medical guidance."
    },
    {
        "id": "permethrin",
        "salt_name": "Permethrin 5% Cream / Lotion",
        "category": "Antiparasitic / Scabies Treatment",
        "form": "Cream (30g)",
        "common_brands": ["Permite", "Scaboma", "Perlice", "P-Thrin"],
        "branded_mrp_avg": 140.0,
        "jan_aushadhi": {
            "scheme": "Jan Aushadhi (PMBJP)",
            "item_name": "Permethrin Cream 5% 30g",
            "pmbjp_code": "PMBJP-DERM-0097",
            "gov_price": 24.0,
            "savings_inr": 116.0,
            "savings_percent": 82.8,
            "quality_standard": "IP / WHO-GMP Standard",
            "locator_url": "https://janaushadhi.gov.in/KendraDetails.aspx"
        },
        "e_pharmacies": [
            {"name": "PharmEasy", "price": 112.0, "discount": "20% OFF", "delivery": "1-2 Days", "url": "https://pharmeasy.in"},
            {"name": "Tata 1mg", "price": 115.0, "discount": "18% OFF", "delivery": "1-2 Days", "url": "https://1mg.com"},
            {"name": "Netmeds", "price": 118.0, "discount": "16% OFF", "delivery": "2 Days", "url": "https://netmeds.com"},
            {"name": "Apollo 24/7", "price": 120.0, "discount": "14% OFF", "delivery": "Same Day", "url": "https://apollopharmacy.in"}
        ],
        "clinical_action": "Antiparasitic cream specifically targeting microscopic skin mites to eliminate nighttime itching and rashes.",
        "usage_guide": "Apply from neck to soles before sleeping. Leave on for 8 to 12 hours, then wash thoroughly."
    },
    {
        "id": "ceramides_barrier",
        "salt_name": "Ceramide III + Hyaluronic Acid + Niacinamide Barrier Moisturizer",
        "category": "Skin Barrier Recovery & Hydration",
        "form": "Lotion / Cream (50g)",
        "common_brands": ["Acrofy", "Cetaphil DAM", "Moisturizing Cream", "Venusia Max", "Bioderma Atoderm"],
        "branded_mrp_avg": 540.0,
        "jan_aushadhi": {
            "scheme": "Jan Aushadhi (PMBJP)",
            "item_name": "Moisturising Cream with Aloe & Vitamin E 50g",
            "pmbjp_code": "PMBJP-DERM-0601",
            "gov_price": 55.0,
            "savings_inr": 485.0,
            "savings_percent": 89.8,
            "quality_standard": "IP / WHO-GMP Standard",
            "locator_url": "https://janaushadhi.gov.in/KendraDetails.aspx"
        },
        "e_pharmacies": [
            {"name": "PharmEasy", "price": 435.0, "discount": "19% OFF", "delivery": "1-2 Days", "url": "https://pharmeasy.in"},
            {"name": "Tata 1mg", "price": 440.0, "discount": "18% OFF", "delivery": "1-2 Days", "url": "https://1mg.com"},
            {"name": "Netmeds", "price": 450.0, "discount": "16% OFF", "delivery": "2-3 Days", "url": "https://netmeds.com"},
            {"name": "Apollo 24/7", "price": 460.0, "discount": "15% OFF", "delivery": "2-Hour Express", "url": "https://apollopharmacy.in"},
            {"name": "Truemeds", "price": 195.0, "discount": "64% OFF", "delivery": "2-3 Days", "url": "https://truemeds.in"}
        ],
        "clinical_action": "Restores the stratum corneum lipid matrix, locks in epidermal moisture, and calms irritated or sensitized skin.",
        "usage_guide": "Apply evenly morning and evening to clean, slightly damp skin after active serums."
    }
]


def search_med_catalog(query: str) -> Optional[Dict[str, Any]]:
    """
    Searches the dermatology medication catalog by brand name or active salt keywords.
    """
    if not query:
        return None

    clean_q = query.strip().lower()
    
    # 1. Exact or partial brand match
    for med in DERMATOLOGY_MED_CATALOG:
        for brand in med["common_brands"]:
            if brand.lower() in clean_q or clean_q in brand.lower():
                return med
                
    # 2. Salt name or active keyword match
    for med in DERMATOLOGY_MED_CATALOG:
        if med["salt_name"].lower() in clean_q or clean_q in med["salt_name"].lower():
            return med
        salt_words = re.findall(r'[a-zA-Z]{4,}', med["salt_name"].lower())
        for sw in salt_words:
            if sw in clean_q:
                return med

    return None


def get_all_popular_salts() -> List[Dict[str, str]]:
    """
    Returns list of clean, non-cluttered search chips.
    """
    return [
        {"name": "Clindamycin 1%", "salt": "Clindamycin Phosphate 1% + Nicotinamide 4%"},
        {"name": "Tretinoin 0.04%", "salt": "Tretinoin Microsphere 0.04% / 0.025%"},
        {"name": "Adapalene + BPO", "salt": "Adapalene 0.1% + Benzoyl Peroxide 2.5%"},
        {"name": "Salicylic Acid 2%", "salt": "Salicylic Acid 2% Ointment / Face Wash"},
        {"name": "Azelaic Acid 10%", "salt": "Azelaic Acid 10% / 20%"},
        {"name": "Ketoconazole 2%", "salt": "Ketoconazole 2% Topical"},
        {"name": "Minoxidil 5%", "salt": "Minoxidil 5% Topical Solution"},
        {"name": "Ceramide Barrier", "salt": "Ceramide III + Hyaluronic Acid + Niacinamide Barrier Moisturizer"}
    ]
