#!/usr/bin/env python3
"""Map 1967 Prayer of the Faithful to current liturgical calendar structure"""

import csv
from pathlib import Path

input_path = Path(r'c:\dev\catholicdaily-flutter\scripts\prayer_of_faithful_1967_cleaned.csv')
output_path = Path(r'c:\dev\catholicdaily-flutter\scripts\prayer_of_faithful_mapped.csv')

# Mapping from 1967 occasion to current calendar structure
# Format: (season, week, day, notes)
calendar_mapping = {
    # Advent
    'THE FIRST SUNDAY OF ADVENT': ('Advent', '1', 'Sunday', 'Cycle-independent'),
    'THE SECOND SUNDAY OF ADVENT': ('Advent', '2', 'Sunday', 'Cycle-independent'),
    'THE THIRD SUNDAY OF ADVENT': ('Advent', '3', 'Sunday', 'Cycle-independent'),
    'THE FOURTH SUNDAY OF ADVENT': ('Advent', '4', 'Sunday', 'Cycle-independent'),
    
    # Christmas Season
    'CHRISTMAS DAY THE NATIVITY OF OUR LORD': ('Christmas', 'Christmas', 'Sunday', 'Christmas Day'),
    'SUNDAY WITHIN THE OCTAVE OF CHRISTMAS': ('Christmas', 'Holy Family', 'Sunday', 'Holy Family'),
    'THE OCTAVE OF THE NATIVITY': ('Christmas', 'Octave', 'Sunday', 'Octave of Christmas'),
    'THE MOST HOLY NAME OF JESUS': ('Christmas', 'Holy Name', 'Sunday', 'Holy Name of Jesus'),
    'THE EPIPHANY OF OUR LORD': ('Christmas', 'Epiphany', 'Sunday', 'Epiphany'),
    'THE FIRST SUNDAY AFTER EPIPHANY (THE HOLY FAMILY)': ('Christmas', 'Holy Family', 'Sunday', 'Holy Family'),
    'THE SECOND SUNDAY AFTER EPIPHANY': ('Christmas', '2', 'Sunday', 'After Epiphany'),
    'THE THIRD SUNDAY AFTER EPIPHANY': ('Christmas', '3', 'Sunday', 'After Epiphany'),
    'THE FOURTH SUNDAY AFTER EPIPHANY': ('Christmas', '4', 'Sunday', 'After Epiphany'),
    'THE FIFTH SUNDAY AFTER EPIPHANY': ('Christmas', '5', 'Sunday', 'After Epiphany'),
    'THE SIXTH SUNDAY AFTER EPIPHANY': ('Christmas', '6', 'Sunday', 'After Epiphany'),
    
    # Pre-Lent (removed from current calendar - mark as obsolete)
    'SEPTUAGESIMA SUNDAY': ('Obsolete', 'Pre-Lent', 'Sunday', 'Removed from current calendar'),
    'SEXAGESIMA SUNDAY': ('Obsolete', 'Pre-Lent', 'Sunday', 'Removed from current calendar'),
    'QUINQUAGESIMA SUNDAY': ('Obsolete', 'Pre-Lent', 'Sunday', 'Removed from current calendar'),
    
    # Lent
    'THE FIRST SUNDAY IN LENT': ('Lent', '1', 'Sunday', 'Cycle-independent'),
    'THE SECOND SUNDAY IN LENT': ('Lent', '2', 'Sunday', 'Cycle-independent'),
    'THE THIRD SUNDAY IN LENT': ('Lent', '3', 'Sunday', 'Cycle-independent'),
    'THE FOURTH SUNDAY IN LENT': ('Lent', '4', 'Sunday', 'Cycle-independent'),
    
    # Passiontide
    'THE FIRST SUNDAY IN PASSIONTIDE': ('Lent', '5', 'Sunday', 'Passion Sunday'),
    'THE SECOND SUNDAY IN PASSIONTIDE (PALM SUNDAY)': ('Lent', '6', 'Sunday', 'Palm Sunday'),
    
    # Easter Season
    'EASTER SUNDAY': ('Easter', 'Easter', 'Sunday', 'Easter Sunday'),
    'LOW SUNDAY': ('Easter', '2', 'Sunday', 'Divine Mercy Sunday'),
    'THE SECOND SUNDAY AFTER EASTER': ('Easter', '3', 'Sunday', 'Easter'),
    'THE THIRD SUNDAY AFTER EASTER': ('Easter', '4', 'Sunday', 'Easter'),
    'THE FOURTH SUNDAY AFTER EASTER': ('Easter', '5', 'Sunday', 'Easter'),
    'THE FIFTH SUNDAY AFTER EASTER': ('Easter', '6', 'Sunday', 'Easter'),
    'THE ASCENSION OF OUR LORD': ('Easter', 'Ascension', 'Sunday', 'Ascension'),
    'SUNDAY AFTER THE ASCENSION': ('Easter', '7', 'Sunday', 'After Ascension'),
    
    # Pentecost Season
    'PENTECOST OR WHIT SUNDAY': ('Easter', 'Pentecost', 'Sunday', 'Pentecost'),
    'TRINITY SUNDAY': ('Ordinary Time', '1', 'Sunday', 'Trinity Sunday'),
    'CORPUS CHRISTI': ('Ordinary Time', '2', 'Sunday', 'Corpus Christi'),
    'THE MOST SACRED HEART OF JESUS': ('Ordinary Time', '3', 'Sunday', 'Sacred Heart'),
    
    # Ordinary Time (Sundays after Pentecost)
    'THE SECOND SUNDAY AFTER PENTECOST': ('Ordinary Time', '4', 'Sunday', 'Ordinary Time'),
    'THE THIRD SUNDAY AFTER PENTECOST': ('Ordinary Time', '5', 'Sunday', 'Ordinary Time'),
    'THE FOURTH SUNDAY AFTER PENTECOST': ('Ordinary Time', '6', 'Sunday', 'Ordinary Time'),
    'THE FIFTH SUNDAY AFTER PENTECOST': ('Ordinary Time', '7', 'Sunday', 'Ordinary Time'),
    'THE SIXTH SUNDAY AFTER PENTECOST': ('Ordinary Time', '8', 'Sunday', 'Ordinary Time'),
    'THE SEVENTH SUNDAY AFTER PENTECOST': ('Ordinary Time', '9', 'Sunday', 'Ordinary Time'),
    'THE EIGHTH SUNDAY AFTER PENTECOST': ('Ordinary Time', '10', 'Sunday', 'Ordinary Time'),
    'THE NINTH SUNDAY AFTER PENTECOST': ('Ordinary Time', '11', 'Sunday', 'Ordinary Time'),
    'THE TENTH SUNDAY AFTER PENTECOST': ('Ordinary Time', '12', 'Sunday', 'Ordinary Time'),
    'THE ELEVENTH SUNDAY AFTER PENTECOST': ('Ordinary Time', '13', 'Sunday', 'Ordinary Time'),
    'THE TWELFTH SUNDAY AFTER PENTECOST': ('Ordinary Time', '14', 'Sunday', 'Ordinary Time'),
    'THE THIRTEENTH SUNDAY AFTER PENTECOST': ('Ordinary Time', '15', 'Sunday', 'Ordinary Time'),
    'THE FOURTEENTH SUNDAY AFTER PENTECOST': ('Ordinary Time', '16', 'Sunday', 'Ordinary Time'),
    'THE FIFTEENTH SUNDAY AFTER PENTECOST': ('Ordinary Time', '17', 'Sunday', 'Ordinary Time'),
    'THE SIXTEENTH SUNDAY AFTER PENTECOST': ('Ordinary Time', '18', 'Sunday', 'Ordinary Time'),
    'THE SEVENTEENTH SUNDAY AFTER PENTECOST': ('Ordinary Time', '19', 'Sunday', 'Ordinary Time'),
    'THE EIGHTEENTH SUNDAY AFTER PENTECOST': ('Ordinary Time', '20', 'Sunday', 'Ordinary Time'),
    'THE NINETEENTH SUNDAY AFTER PENTECOST': ('Ordinary Time', '21', 'Sunday', 'Ordinary Time'),
    'THE TWENTIETH SUNDAY AFTER PENTECOST': ('Ordinary Time', '22', 'Sunday', 'Ordinary Time'),
    'THE TWENTY-FIRST SUNDAY AFTER PENTECOST': ('Ordinary Time', '23', 'Sunday', 'Ordinary Time'),
    'THE TWENTY-SECOND SUNDAY AFTER PENTECOST': ('Ordinary Time', '24', 'Sunday', 'Ordinary Time'),
    'THE TWENTY-THIRD SUNDAY AFTER PENTECOST': ('Ordinary Time', '25', 'Sunday', 'Ordinary Time'),
    'THE TWENTY-FOURTH AND LAST SUNDAY AFTER PENTECOST': ('Ordinary Time', '34', 'Sunday', 'Christ the King'),
    
    # Major Feasts
    'SS. PETER AND PAUL': ('Ordinary Time', 'Feast', 'Sunday', 'Saints Peter and Paul'),
    'THE KINGSHIP OF OUR LORD JESUS CHRIST': ('Ordinary Time', '34', 'Sunday', 'Christ the King'),
    'THE ASSUMPTION OF OUR LADY': ('Ordinary Time', 'Feast', 'Sunday', 'Assumption'),
    'ALL SAINTS': ('Ordinary Time', 'Feast', 'Sunday', 'All Saints'),
    'ALL SOULS\' DAY': ('Ordinary Time', 'Feast', 'Sunday', 'All Souls'),
    'FEASTS OF OUR LADY': ('Ordinary Time', 'Feast', 'Sunday', 'Marian Feasts'),
    'FEASTS OF SAINTS': ('Ordinary Time', 'Feast', 'Sunday', 'Saints'),
    'THE DEDICATION OF': ('Ordinary Time', 'Feast', 'Sunday', 'Dedication of Church'),
    
    # Special Occasions (not calendar-specific)
    'AT A CONFIRMATION. I': ('Special', 'Confirmation', 'Sacrament', 'Confirmation'),
    'AT A CONFIRMATION. II': ('Special', 'Confirmation', 'Sacrament', 'Confirmation'),
    'A NUPTIAL MASS. I': ('Special', 'Marriage', 'Sacrament', 'Wedding'),
    'WEDDINGS': ('Special', 'Marriage', 'Sacrament', 'Wedding'),
    'BAPTISMS': ('Special', 'Baptism', 'Sacrament', 'Baptism'),
    'FIRST COMMUNIONS': ('Special', 'Eucharist', 'Sacrament', 'First Communion'),
    'ORDINATIONS': ('Special', 'Holy Orders', 'Sacrament', 'Ordination'),
    'FUNERALS': ('Special', 'Funeral', 'Sacrament', 'Funeral'),
    'CENOTAPH SERVICES': ('Special', 'Funeral', 'Sacrament', 'Memorial Service'),
    
    # Devotional/Community
    'BENEDICTION (HOLY HOUR)': ('Special', 'Devotional', 'Devotion', 'Benediction'),
    'BIBLE VIGILS': ('Special', 'Devotional', 'Devotion', 'Bible Vigil'),
    'MAY PROCESSIONS': ('Special', 'Devotional', 'Devotion', 'Procession'),
    'PILGRIMAGES': ('Special', 'Devotional', 'Devotion', 'Pilgrimage'),
    'YOUTH RALLIES': ('Special', 'Community', 'Event', 'Youth Rally'),
    'EDUCATION DAYS': ('Special', 'Community', 'Event', 'Education Day'),
    'MISSIONS': ('Special', 'Community', 'Event', 'Mission'),
    'PATRONAL FEASTS': ('Special', 'Community', 'Event', 'Patronal Feast'),
    'ANY SAINT\'S DAY': ('Special', 'Feast', 'Sunday', 'Any Saint'),
    
    # Appendix
    'APPENDIX - Categorized Petitions': ('Appendix', 'Categories', 'Reference', 'Petition templates'),
}

with open(input_path, 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    rows = list(reader)

csv_lines = []
csv_lines.append('season,week,day,occasion_1967,season_mapped,week_mapped,day_mapped,cycle_applicability,notes,petitions,page_number\n')

mapped_count = 0
obsolete_count = 0
special_count = 0

for row in rows:
    occasion = row['occasion']
    petitions = row['petitions']
    page_number = row['page_number']
    
    if occasion in calendar_mapping:
        season, week, day, notes = calendar_mapping[occasion]
        
        # Determine cycle applicability
        if season in ['Special', 'Appendix', 'Obsolete']:
            cycle = 'ALL'
        else:
            cycle = 'ALL'  # 1967 source is cycle-independent
        
        if season == 'Obsolete':
            obsolete_count += 1
        elif season in ['Special', 'Appendix']:
            special_count += 1
        else:
            mapped_count += 1
        
        csv_lines.append(f'"{season}","{week}","{day}","{occasion}","{season}","{week}","{day}","{cycle}","{notes}","{petitions}","{page_number}"\n')
    else:
        # Not found in mapping - mark as unmapped
        csv_lines.append(f'"Unmapped","","","{occasion}","","","","ALL","Not in mapping","{petitions}","{page_number}"\n')

with open(output_path, 'w', encoding='utf-8') as f:
    f.writelines(csv_lines)

print(f"Mapping complete:")
print(f"  - Mapped to current calendar: {mapped_count} entries")
print(f"  - Obsolete (pre-Lent): {obsolete_count} entries")
print(f"  - Special occasions: {special_count} entries")
print(f"  - Total: {len(rows)} entries")
print(f"Output: {output_path}")
