#!/usr/bin/env python3
"""
Resolve responsorial psalm references using existing offline data.

This script uses the app's existing ResponsorialPsalmMapper and liturgical
calendar data to determine correct psalm references for problematic entries.
"""

import sqlite3
import json
import re
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass

@dataclass
class PsalmResolution:
    """Represents a resolved psalm reference."""
    rowid: int
    date: str
    old_reference: str
    new_reference: str
    response: str
    confidence: float
    method: str
    notes: str

class PsalmReferenceResolver:
    """Resolves psalm references using offline data sources."""
    
    def __init__(self, mapper_file: Optional[str] = None):
        self.mapper_data = self._load_mapper_data(mapper_file)
        self.liturgical_data = self._load_liturgical_data()
        self.patterns = self._load_resolution_patterns()
        
    def _load_mapper_data(self, mapper_file: Optional[str]) -> Dict:
        """Load psalm mapper data from the app."""
        if mapper_file and Path(mapper_file).exists():
            with open(mapper_file, 'r') as f:
                return json.load(f)
        
        # Default mapper data extracted from ResponsorialPsalmMapper
        return {
            "fixed_dates": {
                "03-19": {"reference": "Ps 89:2-3, 4-5, 27 and 29", "response": "The son of David will live for ever"},
                "03-25": {"reference": "Ps 33:4-5, 6-7, 12-13, 20 and 22", "response": "Blessed the people the Lord has chosen to be his own"},
                "11-01": {"reference": "Ps 24:1-2, 3-4ab, 5-6", "response": "The Lord's are the earth and its fullness"},
                "12-25": {"reference": "Ps 98:1, 3-6", "response": "All the ends of the earth have seen the saving power of God"},
            },
            "sunday_cycles": {
                "A": {
                    "advent": [
                        {"week": 1, "reference": "Ps 25:4-5ab, 8-9, 10, 14", "response": "To you, O Lord, I lift my soul"},
                        {"week": 2, "reference": "Ps 72:1-2, 7-8, 12-13, 17", "response": "Lord, every nation on earth will adore you"},
                        {"week": 3, "reference": "Ps 146:6-7, 8-9a, 9bc-10", "response": "Come, Lord, and save us"},
                        {"week": 4, "reference": "Ps 89:4-5, 16-17, 19, 20", "response": "Lord, make us turn to you"},
                    ],
                    "lent": [
                        {"week": 1, "reference": "Ps 51:3-4, 5-6ab, 12-13, 17", "response": "Be merciful, O Lord, for we have sinned"},
                        {"week": 2, "reference": "Ps 51:3-4, 5-6a, 12-13, 19-20", "response": "Create a clean heart in me, O God"},
                        {"week": 3, "reference": "Ps 51:3-4, 5-6ab, 12-13, 19-20", "response": "A clean heart create for me, O God"},
                        {"week": 4, "reference": "Ps 51:3-4, 5-6ab, 12-13, 19-20", "response": "A clean heart create for me, O God"},
                        {"week": 5, "reference": "Ps 51:3-4, 5-6ab, 12-13, 19-20", "response": "A clean heart create for me, O God"},
                    ],
                },
                "B": {
                    "advent": [
                        {"week": 1, "reference": "Ps 85:9-10, 11-12, 13-14", "response": "Lord, show us your mercy and love"},
                        {"week": 2, "reference": "Ps 85:9-10, 11-12, 13-14", "response": "Lord, show us your mercy and love"},
                        {"week": 3, "reference": "Ps 85:9-10, 11-12, 13-14", "response": "Lord, show us your mercy and love"},
                        {"week": 4, "reference": "Ps 85:9-10, 11-12, 13-14", "response": "Lord, show us your mercy and love"},
                    ],
                    "lent": [
                        {"week": 1, "reference": "Ps 51:3-4, 5-6a, 12-13, 19-20", "response": "Create a clean heart in me, O God"},
                        {"week": 2, "reference": "Ps 51:3-4, 5-6a, 12-13, 19-20", "response": "Create a clean heart in me, O God"},
                        {"week": 3, "reference": "Ps 51:3-4, 5-6a, 12-13, 19-20", "response": "Create a clean heart in me, O God"},
                        {"week": 4, "reference": "Ps 51:3-4, 5-6a, 12-13, 19-20", "response": "Create a clean heart in me, O God"},
                        {"week": 5, "reference": "Ps 51:3-4, 5-6a, 12-13, 19-20", "response": "Create a clean heart in me, O God"},
                    ],
                },
                "C": {
                    "advent": [
                        {"week": 1, "reference": "Ps 85:9-10, 11-12, 13-14", "response": "Lord, show us your mercy and love"},
                        {"week": 2, "reference": "Ps 85:9-10, 11-12, 13-14", "response": "Lord, show us your mercy and love"},
                        {"week": 3, "reference": "Ps 85:9-10, 11-12, 13-14", "response": "Lord, show us your mercy and love"},
                        {"week": 4, "reference": "Ps 85:9-10, 11-12, 13-14", "response": "Lord, show us your mercy and love"},
                    ],
                    "lent": [
                        {"week": 1, "reference": "Ps 51:3-4, 5-6ab, 12-13, 19-20", "response": "Create a clean heart in me, O God"},
                        {"week": 2, "reference": "Ps 51:3-4, 5-6ab, 12-13, 19-20", "response": "Create a clean heart in me, O God"},
                        {"week": 3, "reference": "Ps 51:3-4, 5-6ab, 12-13, 19-20", "response": "Create a clean heart in me, O God"},
                        {"week": 4, "reference": "Ps 51:3-4, 5-6ab, 12-13, 19-20", "response": "Create a clean heart in me, O God"},
                        {"week": 5, "reference": "Ps 51:3-4, 5-6ab, 12-13, 19-20", "response": "Create a clean heart in me, O God"},
                    ],
                }
            }
        }
    
    def _load_liturgical_data(self) -> Dict:
        """Load liturgical calendar data."""
        return {
            "feasts": {
                "03-19": "St. Joseph",
                "03-25": "Annunciation",
                "06-24": "St. John the Baptist",
                "06-29": "Sts. Peter and Paul",
                "08-15": "Assumption",
                "11-01": "All Saints",
                "12-08": "Immaculate Conception",
                "12-25": "Christmas",
            },
            "seasons": {
                "advent": {"start": "12-02", "end": "12-24"},
                "christmas": {"start": "12-25", "end": "01-07"},
                "lent": {"start": "02-13", "end": "03-27"},  # Varies, approximate
                "easter": {"start": "03-28", "end": "05-15"},     # Varies, approximate
                "ordinary": {"start": "05-16", "end": "12-01"},
            }
        }
    
    def _load_resolution_patterns(self) -> Dict:
        """Load pattern-based resolution rules."""
        return {
            "long_ranges": {
                "1-29": "2-3, 4-5, 27 and 29",  # Common pattern for Psalm 89
                "1-25": "2-3, 4-5, 15-16",     # Common pattern for Psalm 33
                "1-20": "2-3, 4-5, 12-13",     # Common pattern for Psalm 25
                "1-15": "2-3, 4-5, 8-9",       # Common pattern for shorter psalms
                "1-10": "2-3, 4-5, 6-7",       # Common pattern for very short psalms
            },
            "chapter_specific": {
                "89": {"default": "2-3, 4-5, 27 and 29", "response": "The son of David will live for ever"},
                "25": {"default": "4bc-5ab, 6 and 7bc, 8-9", "response": "Remember your mercies, O Lord"},
                "33": {"default": "4-5, 6-7, 12-13, 20 and 22", "response": "Blessed the people the Lord has chosen to be his own"},
                "95": {"default": "1-2, 6-7, 8-9", "response": "If today you hear his voice, harden not your hearts"},
                "100": {"default": "1-2, 3, 5", "response": "We are his people, the sheep of his flock"},
                "145": {"default": "8-9, 10-11, 17-18", "response": "The Lord is near to all who call upon him"},
            }
        }
    
    def resolve_reference(self, rowid: int, date: str, old_reference: str) -> Optional[PsalmResolution]:
        """Resolve a psalm reference using multiple data sources."""
        
        # Extract chapter from old reference
        chapter_match = re.match(r'Ps\s+(\d+):', old_reference, re.IGNORECASE)
        if not chapter_match:
            return None
        
        chapter = int(chapter_match.group(1))
        month_day = date[5:]  # Extract MM-DD from YYYY-MM-DD
        
        # Method 1: Fixed date mapping (highest confidence)
        if month_day in self.mapper_data["fixed_dates"]:
            mapping = self.mapper_data["fixed_dates"][month_day]
            return PsalmResolution(
                rowid=rowid,
                date=date,
                old_reference=old_reference,
                new_reference=mapping["reference"],
                response=mapping["response"],
                confidence=0.95,
                method="fixed_date",
                notes=f"Fixed date mapping for {month_day}"
            )
        
        # Method 2: Feast-specific mapping
        if month_day in self.liturgical_data["feasts"]:
            feast = self.liturgical_data["feasts"][month_day]
            if feast == "St. Joseph" and chapter == 89:
                mapping = self.mapper_data["fixed_dates"]["03-19"]
                return PsalmResolution(
                    rowid=rowid,
                    date=date,
                    old_reference=old_reference,
                    new_reference=mapping["reference"],
                    response=mapping["response"],
                    confidence=0.90,
                    method="feast_specific",
                    notes=f"Feast mapping for {feast}"
                )
        
        # Method 3: Chapter-specific patterns
        chapter_str = str(chapter)
        if chapter_str in self.patterns["chapter_specific"]:
            pattern = self.patterns["chapter_specific"][chapter_str]
            return PsalmResolution(
                rowid=rowid,
                date=date,
                old_reference=old_reference,
                new_reference=pattern["default"],
                response=pattern["response"],
                confidence=0.75,
                method="chapter_pattern",
                notes=f"Chapter {chapter} default pattern"
            )
        
        # Method 4: Long range pattern matching
        verse_part = old_reference.split(':')[1] if ':' in old_reference else ""
        for long_range, replacement in self.patterns["long_ranges"].items():
            if long_range in verse_part:
                return PsalmResolution(
                    rowid=rowid,
                    date=date,
                    old_reference=old_reference,
                    new_reference=f"Ps {chapter}:{replacement}",
                    response="Lord, hear our prayer.",  # Default response
                    confidence=0.60,
                    method="range_pattern",
                    notes=f"Long range pattern: {long_range} → {replacement}"
                )
        
        # Method 5: Generic correction for common issues
        if re.search(r'^\d+-\d+$', verse_part):
            # Simple sequential range, break into stanzas
            start_end = verse_part.split('-')
            start, end = int(start_end[0]), int(start_end[1])
            if end - start > 10:
                # Create a reasonable 3-stanza pattern
                stanza1 = f"{start}-{start+1}"
                stanza2 = f"{start+2}-{start+3}"
                stanza3 = f"{end-1}-{end}"
                new_ref = f"Ps {chapter}:{stanza1}, {stanza2}, {stanza3}"
                return PsalmResolution(
                    rowid=rowid,
                    date=date,
                    old_reference=old_reference,
                    new_reference=new_ref,
                    response="Lord, hear our prayer.",
                    confidence=0.50,
                    method="generic_correction",
                    notes=f"Generic correction of long range {verse_part}"
                )
        
        return None
    
    def resolve_all(self, audit_file: str, confidence_threshold: float = 0.8) -> List[PsalmResolution]:
        """Resolve all problematic psalm references from audit results."""
        
        with open(audit_file, 'r') as f:
            audit_data = json.load(f)
        
        resolutions = []
        
        for entry in audit_data["problematic_entries"]:
            resolution = self.resolve_reference(
                rowid=entry["rowid"],
                date=entry["date"],
                old_reference=entry["reference"]
            )
            
            if resolution and resolution.confidence >= confidence_threshold:
                resolutions.append(resolution)
            elif resolution:
                print(f"Low confidence ({resolution.confidence:.2f}) for row {resolution.rowid}: {resolution.old_reference} → {resolution.new_reference}")
        
        return resolutions

def main():
    """Main entry point."""
    import argparse
    
    parser = argparse.ArgumentParser(description="Resolve psalm references using offline data")
    parser.add_argument("--audit-file", default="psalm_audit_results.json", help="Path to audit results JSON")
    parser.add_argument("--mapper-file", help="Path to psalm mapper data (extracted from app)")
    parser.add_argument("--confidence-threshold", type=float, default=0.8, help="Minimum confidence score")
    parser.add_argument("--output", default="psalm_resolutions.json", help="Output mapping file")
    parser.add_argument("--dry-run", action="store_true", help="Show resolutions without saving")
    
    args = parser.parse_args()
    
    if not Path(args.audit_file).exists():
        print(f"Error: Audit file not found at {args.audit_file}")
        print("Run 'python scripts/audit_psalm_references.py' first to generate audit results.")
        return 1
    
    print(f"Loading audit results from: {args.audit_file}")
    print(f"Confidence threshold: {args.confidence_threshold}")
    print()
    
    resolver = PsalmReferenceResolver(args.mapper_file)
    resolutions = resolver.resolve_all(args.audit_file, args.confidence_threshold)
    
    print(f"Resolved {len(resolutions)} psalm references")
    print()
    
    if not args.dry_run:
        # Save resolutions
        output_data = {
            "metadata": {
                "total_resolved": len(resolutions),
                "confidence_threshold": args.confidence_threshold,
                "generated_at": datetime.now().isoformat()
            },
            "resolutions": [
                {
                    "rowid": r.rowid,
                    "date": r.date,
                    "old_reference": r.old_reference,
                    "new_reference": r.new_reference,
                    "response": r.response,
                    "confidence": r.confidence,
                    "method": r.method,
                    "notes": r.notes
                }
                for r in resolutions
            ]
        }
        
        with open(args.output, 'w') as f:
            json.dump(output_data, f, indent=2)
        
        print(f"Resolutions saved to: {args.output}")
    else:
        print("DRY RUN - Resolutions not saved:")
        for r in resolutions[:10]:  # Show first 10
            print(f"  Row {r.rowid} ({r.date}): {r.old_reference} → {r.new_reference} (confidence: {r.confidence:.2f})")
        
        if len(resolutions) > 10:
            print(f"  ... and {len(resolutions) - 10} more")
    
    return 0

if __name__ == '__main__':
    exit(main())
