"""
Extract text from weekday lectionary PDFs to understand structure
before parsing into structured CSV data.
"""
import pdfplumber
import sys
import os

def extract_pdf_text(pdf_path, output_path, max_pages=None):
    """Extract all text from a PDF and save to a text file."""
    print(f"Extracting: {pdf_path}")
    
    if not os.path.exists(pdf_path):
        print(f"ERROR: File not found: {pdf_path}")
        return
    
    with pdfplumber.open(pdf_path) as pdf:
        total_pages = len(pdf.pages)
        print(f"  Total pages: {total_pages}")
        
        with open(output_path, 'w', encoding='utf-8') as f:
            pages_to_process = min(max_pages, total_pages) if max_pages else total_pages
            for i, page in enumerate(pdf.pages[:pages_to_process]):
                text = page.extract_text()
                if text:
                    f.write(f"\n{'='*80}\n")
                    f.write(f"PAGE {i+1}\n")
                    f.write(f"{'='*80}\n")
                    f.write(text)
                    f.write("\n")
                
                if (i + 1) % 50 == 0:
                    print(f"  Processed {i+1}/{pages_to_process} pages...")
        
        print(f"  Saved to: {output_path}")

def extract_sample(pdf_path, output_path, pages=10):
    """Extract just first N pages to understand structure."""
    extract_pdf_text(pdf_path, output_path, max_pages=pages)

if __name__ == '__main__':
    base_dir = r'c:\dev\catholicdaily-flutter'
    
    # First extract samples (first 10 pages) to understand structure
    print("=== Extracting sample pages to understand structure ===\n")
    
    extract_sample(
        os.path.join(base_dir, 'weekday-a-1993.pdf'),
        os.path.join(base_dir, 'scripts', 'weekday_a_sample.txt'),
        pages=15
    )
    
    extract_sample(
        os.path.join(base_dir, 'weekday-b-1993.pdf'),
        os.path.join(base_dir, 'scripts', 'weekday_b_sample.txt'),
        pages=15
    )
    
    print("\n=== Now extracting FULL text from both PDFs ===\n")
    
    extract_pdf_text(
        os.path.join(base_dir, 'weekday-a-1993.pdf'),
        os.path.join(base_dir, 'scripts', 'weekday_a_full.txt')
    )
    
    extract_pdf_text(
        os.path.join(base_dir, 'weekday-b-1993.pdf'),
        os.path.join(base_dir, 'scripts', 'weekday_b_full.txt')
    )
    
    print("\nDone! Check the output files.")
