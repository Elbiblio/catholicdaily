import os
import pdfplumber

pdf_path = os.path.join(os.path.dirname(__file__), '..', 'catholic-sunday-readings.pdf')
out_path = os.path.join(os.path.dirname(__file__), 'sunday_readings_columns.txt')

with pdfplumber.open(pdf_path) as pdf:
    with open(out_path, 'w', encoding='utf-8') as out:
        for i, page in enumerate(pdf.pages, start=1):
            width = page.width
            height = page.height
            mid = width / 2
            gutter = 12

            left_bbox = (0, 0, max(mid - gutter, 0), height)
            right_bbox = (min(mid + gutter, width), 0, width, height)

            left_text = page.crop(left_bbox).extract_text() or ''
            right_text = page.crop(right_bbox).extract_text() or ''

            out.write(f'--- PAGE {i} LEFT ---\n')
            out.write(left_text)
            out.write('\n\n')
            out.write(f'--- PAGE {i} RIGHT ---\n')
            out.write(right_text)
            out.write('\n\n')

print(f'Extracted {len(pdf.pages)} pages with separate columns to {out_path}')
