import csv
import json
import os
import re

BASE = r'c:\dev\catholicdaily-flutter'
OPTIONAL_MEMORIAL_DART = os.path.join(BASE, 'lib', 'data', 'services', 'optional_memorial_service.dart')
MAJOR_CELEBRATIONS_JSON = os.path.join(BASE, 'scripts', 'major_celebration_refs.json')
OUT_CSV = os.path.join(BASE, 'memorial_feasts.csv')

RANK_MAP = {
    'optionalMemorial': 'Optional Memorial',
    'obligatoryMemorial': 'Obligatory Memorial',
    'feast': 'Feast',
    'solemnity': 'Solemnity',
}

COLOR_MAP = {
    'white': 'white',
    'red': 'red',
    'green': 'green',
    'violet': 'violet',
    'rose': 'rose',
    'black': 'black',
    'gold': 'gold',
}

FIXED_SUPPLEMENTS = {
    'conversion_of_saint_paul': {
        'title': 'The Conversion of Saint Paul, Apostle', 'rank': 'Feast', 'color': 'white', 'month': '1', 'day': '25', 'date_rule': '', 'common_type': ''
    },
    'presentation_of_the_lord': {
        'title': 'The Presentation of the Lord', 'rank': 'Feast', 'color': 'white', 'month': '2', 'day': '2', 'date_rule': '', 'common_type': ''
    },
    'chair_of_saint_peter': {
        'title': 'The Chair of Saint Peter, Apostle', 'rank': 'Feast', 'color': 'white', 'month': '2', 'day': '22', 'date_rule': '', 'common_type': ''
    },
    'mark_evangelist': {
        'title': 'Saint Mark, Evangelist', 'rank': 'Feast', 'color': 'red', 'month': '4', 'day': '25', 'date_rule': '', 'common_type': ''
    },
    'philip_and_james_apostles': {
        'title': 'Saints Philip and James, Apostles', 'rank': 'Feast', 'color': 'red', 'month': '5', 'day': '3', 'date_rule': '', 'common_type': ''
    },
    'matthias_apostle': {
        'title': 'Saint Matthias, Apostle', 'rank': 'Feast', 'color': 'red', 'month': '5', 'day': '14', 'date_rule': '', 'common_type': ''
    },
    'visitation_of_mary': {
        'title': 'The Visitation of the Blessed Virgin Mary', 'rank': 'Feast', 'color': 'white', 'month': '5', 'day': '31', 'date_rule': '', 'common_type': 'BlessedVirginMary'
    },
    'thomas_apostle': {
        'title': 'Saint Thomas, Apostle', 'rank': 'Feast', 'color': 'red', 'month': '7', 'day': '3', 'date_rule': '', 'common_type': ''
    },
    'mary_magdalene': {
        'title': 'Saint Mary Magdalene', 'rank': 'Feast', 'color': 'white', 'month': '7', 'day': '22', 'date_rule': '', 'common_type': ''
    },
    'james_apostle': {
        'title': 'Saint James, Apostle', 'rank': 'Feast', 'color': 'red', 'month': '7', 'day': '25', 'date_rule': '', 'common_type': ''
    },
    'transfiguration_of_the_lord': {
        'title': 'The Transfiguration of the Lord', 'rank': 'Feast', 'color': 'white', 'month': '8', 'day': '6', 'date_rule': '', 'common_type': ''
    },
    'lawrence_of_rome_deacon': {
        'title': 'Saint Lawrence, Deacon and Martyr', 'rank': 'Feast', 'color': 'red', 'month': '8', 'day': '10', 'date_rule': '', 'common_type': ''
    },
    'maximilian_mary_kolbe': {
        'title': 'Saint Maximilian Mary Kolbe, Priest and Martyr', 'rank': 'Obligatory Memorial', 'color': 'red', 'month': '8', 'day': '14', 'date_rule': '', 'common_type': 'Martyrs'
    },
    'queenship_of_blessed_virgin_mary': {
        'title': 'The Queenship of the Blessed Virgin Mary', 'rank': 'Obligatory Memorial', 'color': 'white', 'month': '8', 'day': '22', 'date_rule': '', 'common_type': 'BlessedVirginMary'
    },
    'bartholomew_apostle': {
        'title': 'Saint Bartholomew, Apostle', 'rank': 'Feast', 'color': 'red', 'month': '8', 'day': '24', 'date_rule': '', 'common_type': ''
    },
    'passion_of_john_the_baptist': {
        'title': 'The Passion of Saint John the Baptist', 'rank': 'Obligatory Memorial', 'color': 'red', 'month': '8', 'day': '29', 'date_rule': '', 'common_type': ''
    },
    'nativity_of_blessed_virgin_mary': {
        'title': 'The Nativity of the Blessed Virgin Mary', 'rank': 'Feast', 'color': 'white', 'month': '9', 'day': '8', 'date_rule': '', 'common_type': 'BlessedVirginMary'
    },
    'exaltation_of_holy_cross': {
        'title': 'The Exaltation of the Holy Cross', 'rank': 'Feast', 'color': 'red', 'month': '9', 'day': '14', 'date_rule': '', 'common_type': ''
    },
    'our_lady_of_sorrows': {
        'title': 'Our Lady of Sorrows', 'rank': 'Obligatory Memorial', 'color': 'white', 'month': '9', 'day': '15', 'date_rule': '', 'common_type': 'BlessedVirginMary'
    },
    'matthew_apostle': {
        'title': 'Saint Matthew, Apostle and Evangelist', 'rank': 'Feast', 'color': 'red', 'month': '9', 'day': '21', 'date_rule': '', 'common_type': ''
    },
    'michael_gabriel_raphael_archangels': {
        'title': 'Saints Michael, Gabriel, and Raphael, Archangels', 'rank': 'Feast', 'color': 'white', 'month': '9', 'day': '29', 'date_rule': '', 'common_type': ''
    },
    'our_lady_of_the_rosary': {
        'title': 'Our Lady of the Rosary', 'rank': 'Obligatory Memorial', 'color': 'white', 'month': '10', 'day': '7', 'date_rule': '', 'common_type': 'BlessedVirginMary'
    },
    'luke_evangelist': {
        'title': 'Saint Luke, Evangelist', 'rank': 'Feast', 'color': 'red', 'month': '10', 'day': '18', 'date_rule': '', 'common_type': ''
    },
    'simon_and_jude_apostles': {
        'title': 'Saints Simon and Jude, Apostles', 'rank': 'Feast', 'color': 'red', 'month': '10', 'day': '28', 'date_rule': '', 'common_type': ''
    },
    'dedication_of_lateran_basilica': {
        'title': 'The Dedication of the Lateran Basilica', 'rank': 'Feast', 'color': 'white', 'month': '11', 'day': '9', 'date_rule': '', 'common_type': ''
    },
    'presentation_of_blessed_virgin_mary': {
        'title': 'The Presentation of the Blessed Virgin Mary', 'rank': 'Obligatory Memorial', 'color': 'white', 'month': '11', 'day': '21', 'date_rule': '', 'common_type': 'BlessedVirginMary'
    },
    'andrew_apostle': {
        'title': 'Saint Andrew, Apostle', 'rank': 'Feast', 'color': 'red', 'month': '11', 'day': '30', 'date_rule': '', 'common_type': ''
    },
    'stephen_first_martyr': {
        'title': 'Saint Stephen, the First Martyr', 'rank': 'Feast', 'color': 'red', 'month': '12', 'day': '26', 'date_rule': '', 'common_type': ''
    },
    'john_apostle': {
        'title': 'Saint John, Apostle and Evangelist', 'rank': 'Feast', 'color': 'white', 'month': '12', 'day': '27', 'date_rule': '', 'common_type': ''
    },
    'holy_innocents': {
        'title': 'The Holy Innocents, Martyrs', 'rank': 'Feast', 'color': 'red', 'month': '12', 'day': '28', 'date_rule': '', 'common_type': ''
    },
    'holy_family': {
        'title': 'The Holy Family of Jesus, Mary, and Joseph', 'rank': 'Feast', 'color': 'white', 'month': '', 'day': '', 'date_rule': 'Sunday within the Octave of Christmas, or December 30 if no Sunday occurs', 'common_type': ''
    },
    'immaculate_heart_of_mary': {
        'title': 'The Immaculate Heart of the Blessed Virgin Mary', 'rank': 'Obligatory Memorial', 'color': 'white', 'month': '', 'day': '', 'date_rule': 'Saturday after the Solemnity of the Most Sacred Heart of Jesus', 'common_type': 'BlessedVirginMary'
    },
}

MAJOR_CELEBRATION_SUPPLEMENTS = {
    'mary_mother_of_god': {
        'title': 'Mary, the Holy Mother of God', 'rank': 'Solemnity', 'color': 'white', 'month': '1', 'day': '1', 'date_rule': '', 'common_type': 'BlessedVirginMary'
    },
    'epiphany_of_the_lord': {
        'title': 'The Epiphany of the Lord', 'rank': 'Solemnity', 'color': 'white', 'month': '', 'day': '', 'date_rule': 'Sunday between January 2 and January 8', 'common_type': ''
    },
    'baptism_of_the_lord': {
        'title': 'The Baptism of the Lord', 'rank': 'Feast', 'color': 'white', 'month': '', 'day': '', 'date_rule': 'Sunday after January 6, or Monday after Epiphany if Epiphany is celebrated on January 7 or 8', 'common_type': ''
    },
    'saint_joseph_spouse_of_blessed_virgin_mary': {
        'title': 'Saint Joseph, Spouse of the Blessed Virgin Mary', 'rank': 'Solemnity', 'color': 'white', 'month': '3', 'day': '19', 'date_rule': 'Transferred when impeded by Holy Week or other higher celebrations', 'common_type': ''
    },
    'annunciation_of_the_lord': {
        'title': 'The Annunciation of the Lord', 'rank': 'Solemnity', 'color': 'white', 'month': '3', 'day': '25', 'date_rule': 'Transferred when impeded by Holy Week or Easter Octave', 'common_type': ''
    },
    'nativity_of_saint_john_the_baptist': {
        'title': 'The Nativity of Saint John the Baptist', 'rank': 'Solemnity', 'color': 'white', 'month': '6', 'day': '24', 'date_rule': '', 'common_type': ''
    },
    'saints_peter_and_paul_apostles': {
        'title': 'Saints Peter and Paul, Apostles', 'rank': 'Solemnity', 'color': 'red', 'month': '6', 'day': '29', 'date_rule': '', 'common_type': ''
    },
    'assumption_of_blessed_virgin_mary': {
        'title': 'The Assumption of the Blessed Virgin Mary', 'rank': 'Solemnity', 'color': 'white', 'month': '8', 'day': '15', 'date_rule': '', 'common_type': 'BlessedVirginMary'
    },
    'all_saints': {
        'title': 'All Saints', 'rank': 'Solemnity', 'color': 'white', 'month': '11', 'day': '1', 'date_rule': '', 'common_type': 'Saints'
    },
    'commemoration_of_all_the_faithful_departed': {
        'title': 'The Commemoration of All the Faithful Departed', 'rank': 'Commemoration', 'color': 'violet', 'month': '11', 'day': '2', 'date_rule': '', 'common_type': ''
    },
    'immaculate_conception_of_blessed_virgin_mary': {
        'title': 'The Immaculate Conception of the Blessed Virgin Mary', 'rank': 'Solemnity', 'color': 'white', 'month': '12', 'day': '8', 'date_rule': '', 'common_type': 'BlessedVirginMary'
    },
    'nativity_of_the_lord': {
        'title': 'The Nativity of the Lord', 'rank': 'Solemnity', 'color': 'white', 'month': '12', 'day': '25', 'date_rule': '', 'common_type': ''
    },
    'palm_sunday_of_the_passion_of_the_lord': {
        'title': 'Palm Sunday of the Passion of the Lord', 'rank': 'Solemnity', 'color': 'red', 'month': '', 'day': '', 'date_rule': 'Sunday before Easter', 'common_type': ''
    },
    'holy_thursday_evening_mass_of_the_lords_supper': {
        'title': "Holy Thursday - Evening Mass of the Lord's Supper", 'rank': 'Solemnity', 'color': 'white', 'month': '', 'day': '', 'date_rule': 'Thursday before Easter', 'common_type': ''
    },
    'friday_of_the_passion_of_the_lord': {
        'title': 'Friday of the Passion of the Lord', 'rank': 'Day', 'color': 'red', 'month': '', 'day': '', 'date_rule': 'Friday before Easter', 'common_type': ''
    },
    'holy_saturday': {
        'title': 'Holy Saturday', 'rank': 'Day', 'color': 'violet', 'month': '', 'day': '', 'date_rule': 'Saturday before Easter', 'common_type': ''
    },
    'easter_sunday_of_the_resurrection_of_the_lord': {
        'title': 'Easter Sunday of the Resurrection of the Lord', 'rank': 'Solemnity', 'color': 'white', 'month': '', 'day': '', 'date_rule': 'Easter Sunday', 'common_type': ''
    },
    'second_sunday_of_easter_divine_mercy': {
        'title': 'Second Sunday of Easter (Divine Mercy)', 'rank': 'Sunday', 'color': 'white', 'month': '', 'day': '', 'date_rule': 'Second Sunday of Easter', 'common_type': ''
    },
    'pentecost_sunday': {
        'title': 'Pentecost Sunday', 'rank': 'Solemnity', 'color': 'red', 'month': '', 'day': '', 'date_rule': '50th day of Easter', 'common_type': ''
    },
    'most_holy_trinity': {
        'title': 'The Most Holy Trinity', 'rank': 'Solemnity', 'color': 'white', 'month': '', 'day': '', 'date_rule': 'Sunday after Pentecost', 'common_type': ''
    },
    'most_holy_body_and_blood_of_christ': {
        'title': 'The Most Holy Body and Blood of Christ', 'rank': 'Solemnity', 'color': 'white', 'month': '', 'day': '', 'date_rule': 'Sunday after Trinity Sunday', 'common_type': ''
    },
    'most_sacred_heart_of_jesus': {
        'title': 'The Most Sacred Heart of Jesus', 'rank': 'Solemnity', 'color': 'white', 'month': '', 'day': '', 'date_rule': 'Friday after the Second Sunday after Pentecost', 'common_type': ''
    },
    'our_lord_jesus_christ_king_of_the_universe': {
        'title': 'Our Lord Jesus Christ, King of the Universe', 'rank': 'Solemnity', 'color': 'white', 'month': '', 'day': '', 'date_rule': 'Last Sunday of the liturgical year', 'common_type': ''
    },
}

FIELDS = [
    'id', 'title', 'rank', 'color', 'month', 'day', 'date_rule', 'common_type',
    'first_reading', 'alternative_first_reading', 'psalm_reference', 'psalm_response',
    'second_reading', 'gospel', 'alternative_gospel', 'gospel_acclamation'
]


def read_text(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def unescape_dart_string(value):
    return value.replace("\\'", "'").replace('—', '-').strip()


def parse_optional_celebrations(text):
    pattern = re.compile(
        r"const OptionalCelebration\(id: '([^']+)', title: '((?:\\'|[^'])*)', rank: CelebrationRank\.(\w+), color: LiturgicalColor\.(\w+), month: (\d+), day: (\d+), commonType: '([^']*)'\)",
        re.MULTILINE,
    )
    rows = {}
    for match in pattern.finditer(text):
        celebration_id, title, rank, color, month, day, common_type = match.groups()
        rows[celebration_id] = {
            'id': celebration_id,
            'title': unescape_dart_string(title),
            'rank': RANK_MAP.get(rank, rank),
            'color': COLOR_MAP.get(color, color),
            'month': month,
            'day': day,
            'date_rule': '',
            'common_type': common_type if common_type != 'None' else '',
        }
    return rows


def slugify_title(title):
    normalized = title.lower().replace("'", '')
    normalized = re.sub(r'[^a-z0-9]+', '_', normalized)
    return normalized.strip('_')


def load_major_celebrations():
    if not os.path.exists(MAJOR_CELEBRATIONS_JSON):
        return {}, {}

    with open(MAJOR_CELEBRATIONS_JSON, encoding='utf-8') as f:
        raw = json.load(f)

    metadata = {}
    readings = {}
    for row in raw:
        title = row.get('title', '').strip()
        if not title:
            continue
        celebration_id = slugify_title(title)
        supplement = MAJOR_CELEBRATION_SUPPLEMENTS.get(celebration_id)
        if supplement is None:
            continue

        metadata[celebration_id] = {
            'id': celebration_id,
            'title': supplement['title'],
            'rank': supplement['rank'],
            'color': supplement['color'],
            'month': supplement['month'],
            'day': supplement['day'],
            'date_rule': supplement['date_rule'],
            'common_type': supplement['common_type'],
        }

        if celebration_id in readings:
            continue

        grouped = {item.get('position', ''): item for item in row.get('readings', [])}
        gospel_rows = [item for item in row.get('readings', []) if item.get('position') == 'Gospel']
        readings[celebration_id] = {
            'first_reading': grouped.get('First Reading', {}).get('reading', ''),
            'alternative_first_reading': '',
            'psalm_reference': grouped.get('Responsorial Psalm', {}).get('reading', ''),
            'psalm_response': grouped.get('Responsorial Psalm', {}).get('psalm_response', '') or '',
            'second_reading': grouped.get('Second Reading', {}).get('reading', ''),
            'gospel': gospel_rows[0].get('reading', '') if gospel_rows else '',
            'alternative_gospel': gospel_rows[1].get('reading', '') if len(gospel_rows) > 1 else '',
            'gospel_acclamation': '',
        }

    return metadata, readings


def extract_block(text, start_marker):
    start = text.find(start_marker)
    if start == -1:
        return ''
    brace_start = text.find('{', start)
    depth = 0
    for idx in range(brace_start, len(text)):
        ch = text[idx]
        if ch == '{':
            depth += 1
        elif ch == '}':
            depth -= 1
            if depth == 0:
                return text[brace_start + 1:idx]
    return ''


def parse_proper_readings(text):
    block = extract_block(text, 'static final Map<String, ProperReadingSet> _properReadingsMap')
    entry_pattern = re.compile(r"'([^']+)': const ProperReadingSet\((.*?)\),", re.DOTALL)
    field_patterns = {
        'first_reading': r"firstReading: '((?:\\'|[^'])*)'",
        'alternative_first_reading': r"alternativeFirstReading: '((?:\\'|[^'])*)'",
        'psalm_reference': r"psalm: '((?:\\'|[^'])*)'",
        'psalm_response': r"psalmResponse: '((?:\\'|[^'])*)'",
        'second_reading': r"secondReading: '((?:\\'|[^'])*)'",
        'gospel': r"gospel: '((?:\\'|[^'])*)'",
        'alternative_gospel': r"alternativeGospel: '((?:\\'|[^'])*)'",
        'gospel_acclamation': r"gospelAcclamation: '((?:\\'|[^'])*)'",
    }
    rows = {}
    for entry_match in entry_pattern.finditer(block):
        celebration_id, body = entry_match.groups()
        row = {}
        for key, pattern in field_patterns.items():
            field_match = re.search(pattern, body, re.DOTALL)
            row[key] = unescape_dart_string(field_match.group(1)) if field_match else ''
        rows[celebration_id] = row
    return rows


def build_rows():
    text = read_text(OPTIONAL_MEMORIAL_DART)
    celebrations = parse_optional_celebrations(text)
    proper = parse_proper_readings(text)
    major_metadata, major_readings = load_major_celebrations()

    for celebration_id, supplement in FIXED_SUPPLEMENTS.items():
        celebrations.setdefault(celebration_id, {'id': celebration_id})
        celebrations[celebration_id].update({
            'title': supplement['title'],
            'rank': supplement['rank'],
            'color': supplement['color'],
            'month': supplement['month'],
            'day': supplement['day'],
            'date_rule': supplement['date_rule'],
            'common_type': supplement['common_type'],
        })

    for celebration_id, metadata in major_metadata.items():
        celebrations.setdefault(celebration_id, {'id': celebration_id})
        celebrations[celebration_id].update(metadata)

    for celebration_id, reading_set in major_readings.items():
        proper.setdefault(celebration_id, reading_set)

    rows = []
    all_ids = sorted(set(celebrations) | set(proper))
    for celebration_id in all_ids:
        meta = celebrations.get(celebration_id, {'id': celebration_id})
        readings = proper.get(celebration_id, {})
        row = {
            'id': celebration_id,
            'title': meta.get('title', ''),
            'rank': meta.get('rank', ''),
            'color': meta.get('color', ''),
            'month': meta.get('month', ''),
            'day': meta.get('day', ''),
            'date_rule': meta.get('date_rule', ''),
            'common_type': meta.get('common_type', ''),
            'first_reading': readings.get('first_reading', ''),
            'alternative_first_reading': readings.get('alternative_first_reading', ''),
            'psalm_reference': readings.get('psalm_reference', ''),
            'psalm_response': readings.get('psalm_response', ''),
            'second_reading': readings.get('second_reading', ''),
            'gospel': readings.get('gospel', ''),
            'alternative_gospel': readings.get('alternative_gospel', ''),
            'gospel_acclamation': readings.get('gospel_acclamation', ''),
        }
        rows.append(row)
    rows.sort(key=lambda row: (
        13 if not row['month'] else int(row['month']),
        32 if not row['day'] else int(row['day']),
        row['title'],
    ))
    return rows


def main():
    rows = build_rows()
    with open(OUT_CSV, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(rows)
    proper_count = sum(1 for row in rows if row['first_reading'] or row['gospel'])
    print(f'Wrote {len(rows)} rows to {OUT_CSV}')
    print(f'Rows with proper readings: {proper_count}')


if __name__ == '__main__':
    main()
