"""Extract text from catholic-sunday-readings.pdf for analysis."""
import pdfplumber
import os

pdf_path = os.path.join(os.path.dirname(__file__), '..', 'catholic-sunday-readings.pdf')
out_path = os.path.join(os.path.dirname(__file__), 'sunday_readings_full.txt')

with pdfplumber.open(pdf_path) as pdf:
    with open(out_path, 'w', encoding='utf-8') as out:
        for i, page in enumerate(pdf.pages):
            text = page.extract_text()
            if text:
                out.write(f"--- PAGE {i+1} ---\n")
                out.write(text + "\n\n")

print(f"Extracted {len(pdf.pages)} pages to {out_path}")
