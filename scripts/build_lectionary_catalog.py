"""
Build a comprehensive Catholic Lectionary psalm/acclamation catalog.

Strategy:
1. Extract psalm+acclamation data from weekday PDFs by scanning for 
   RESPONSORIAL PSALM and GOSPEL ACCLAMATION patterns
2. Use lectionary numbers to map to Season/Week/Day
3. Supplement with Sunday cycle data from known lectionary structure
4. Output lectionary_psalms.csv and discrepancies.csv
"""
import re
import csv
import os

# ============================================================
# LECTIONARY NUMBER -> SEASON/WEEK/DAY MAPPING
# Based on the Ordo Lectionum Missae (OLM) numbering
# ============================================================

# Weekday lectionary numbers (from TOC of the 1993 Canadian Lectionary)
LECTIONARY_MAP = {}

# Advent Week 1: Mon-Sat = 175-180
for i, day in enumerate(['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday']):
    LECTIONARY_MAP[175+i] = ('Advent', '1', day)

# Advent Week 2: Mon-Sat = 181-186
for i, day in enumerate(['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday']):
    LECTIONARY_MAP[181+i] = ('Advent', '2', day)

# Advent Week 3: Mon-Sat = 187-192
for i, day in enumerate(['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday']):
    LECTIONARY_MAP[187+i] = ('Advent', '3', day)

# December 17-24 = 193-200
for i, d in enumerate(range(17, 25)):
    LECTIONARY_MAP[193+i] = ('Advent', f'Dec {d}', f'December {d}')

# Christmas Octave: Dec 26-31 + Jan 1 = 201-207
xmas_dates = ['December 26','December 27','December 28','December 29','December 30','December 31','January 1']
for i, d in enumerate(xmas_dates):
    LECTIONARY_MAP[201+i] = ('Christmas', 'Octave', d)

# Weekdays between Jan 2 and Epiphany = 208-212 (5 days)
for i in range(5):
    LECTIONARY_MAP[208+i] = ('Christmas', 'Before Epiphany', f'Day {i+1}')

# Weekdays after Epiphany before Baptism = 213-216
for i in range(4):
    LECTIONARY_MAP[213+i] = ('Christmas', 'After Epiphany', f'Day {i+1}')

# Ordinary Time Weeks 1-9, Mon-Sat (Year I: 305-358, Year II: 359-412)
# Actually the OLM numbers for OT weekdays are:
# Week 1: 305-310 (Year I) and same numbers but different readings for Year II
# The PDF separates them by pages, not by lectionary number
# Let me use a different approach for OT

# OT Week 1-34 weekdays: Mon-Sat
# Year I readings: lectionary #s 305-512
# Year II readings: lectionary #s 305-512 (same numbers, different first readings)
ot_base = 305
for week in range(1, 35):
    for i, day in enumerate(['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday']):
        num = ot_base + (week - 1) * 6 + i
        LECTIONARY_MAP[num] = ('Ordinary Time', str(week), day)

# Lent - special weekdays before Ash Wednesday Week
# Ash Wednesday = 219
LECTIONARY_MAP[219] = ('Lent', 'Ash Wed', 'Ash Wednesday')
LECTIONARY_MAP[220] = ('Lent', 'After Ash Wed', 'Thursday')
LECTIONARY_MAP[221] = ('Lent', 'After Ash Wed', 'Friday')
LECTIONARY_MAP[222] = ('Lent', 'After Ash Wed', 'Saturday')

# Lent Weeks 1-5, Mon-Sat = 223-252
lent_base = 223
for week in range(1, 6):
    for i, day in enumerate(['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday']):
        num = lent_base + (week - 1) * 6 + i
        LECTIONARY_MAP[num] = ('Lent', str(week), day)

# Holy Week: Mon-Thu (before Triduum) = 253-257 approximately
LECTIONARY_MAP[253] = ('Holy Week', '', 'Monday')
LECTIONARY_MAP[254] = ('Holy Week', '', 'Tuesday')
LECTIONARY_MAP[255] = ('Holy Week', '', 'Wednesday')
# Holy Thursday, Good Friday, Easter Vigil are special

# Easter Octave: Mon-Sat = 257-262 or thereabouts
easter_oct_base = 261
for i, day in enumerate(['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday']):
    LECTIONARY_MAP[easter_oct_base + i] = ('Easter', 'Octave', day)

# Easter Weeks 2-7, Mon-Sat
easter_base = 267
for week in range(2, 8):
    for i, day in enumerate(['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday']):
        num = easter_base + (week - 2) * 6 + i
        LECTIONARY_MAP[num] = ('Easter', str(week), day)


def extract_psalm_acclamation_pairs(text_path):
    """
    Simpler, more robust extraction: find every RESPONSORIAL PSALM 
    followed by a GOSPEL ACCLAMATION, and pair them together.
    Track the current day/section context.
    """
    with open(text_path, 'r', encoding='utf-8') as f:
        lines = f.read().split('\n')
    
    entries = []
    current_season = ""
    current_week = ""
    current_day = ""
    current_lect_num = ""
    current_reading_year = ""
    
    # Patterns
    day_header = re.compile(r'^(\d{1,3})\s+(MONDAY|TUESDAY|WEDNESDAY|THURSDAY|FRIDAY|SATURDAY)\s*$')
    date_header = re.compile(r'^(\d{1,3})\s+(DECEMBER|JANUARY|FEBRUARY|MARCH|APRIL|MAY|JUNE)\s+(\d{1,2})\s*$')
    
    week_header = re.compile(
        r'(FIRST|SECOND|THIRD|FOURTH|FIFTH|SIXTH|SEVENTH|EIGHTH|NINTH)\s+WEEK\s+'
        r'(?:OF|IN)\s+(ADVENT|LENT|EASTER|ORDINARY TIME)',
        re.IGNORECASE
    )
    week_num = {'FIRST':'1','SECOND':'2','THIRD':'3','FOURTH':'4','FIFTH':'5',
                'SIXTH':'6','SEVENTH':'7','EIGHTH':'8','NINTH':'9'}
    
    psalm_line = re.compile(r'RESPONSORIAL\s+PSALM\s+(.*)', re.IGNORECASE)
    response_line = re.compile(r'^R\.\s+(.+)')
    accl_header = re.compile(r'GOSPEL\s+ACCLAMATI\s*O\s*N\s*(.*)', re.IGNORECASE)
    year_in_reading = re.compile(r'YEAR[S]?\s+(I+|A|B|C)', re.IGNORECASE)
    
    # State
    pending_psalm = None  # Dict with psalm info waiting for acclamation
    
    i = 0
    n = len(lines)
    
    while i < n:
        line = lines[i].strip()
        
        # --- Context tracking ---
        
        # Week header
        wm = week_header.search(line)
        if wm:
            w = wm.group(1).upper()
            s = wm.group(2).upper()
            current_week = week_num.get(w, w)
            if 'ADVENT' in s: current_season = 'Advent'
            elif 'LENT' in s: current_season = 'Lent'
            elif 'EASTER' in s: current_season = 'Easter'
            elif 'ORDINARY' in s: current_season = 'Ordinary Time'
            i += 1; continue
        
        # Special season markers
        upper = line.upper()
        if 'OCTAVE OF CHRISTMAS' in upper:
            current_season = 'Christmas'; current_week = 'Octave'
        elif 'OCTAVE OF EASTER' in upper:
            current_season = 'Easter'; current_week = 'Octave'
        elif 'HOLY WEEK' in upper and 'FIFTH' not in upper:
            current_season = 'Holy Week'; current_week = ''
        elif re.search(r'ADVENT WEEKDAYS.*DECEMBER 17', upper):
            current_season = 'Advent'; current_week = 'Dec 17-24'
        elif 'WEEKDAYS BETWEEN NEW YEAR' in upper or 'WEEKDAYS BETWEEN JANUARY' in upper:
            current_season = 'Christmas'; current_week = 'Before Epiphany'
        elif 'WEEKDAYS BETWEEN EPIPHANY' in upper:
            current_season = 'Christmas'; current_week = 'After Epiphany'
        elif 'SEASON OF LENT' in upper:
            current_season = 'Lent'
        elif 'ASH WEDNESDAY' in upper and re.match(r'^\d+\s+ASH', upper):
            current_season = 'Lent'; current_week = 'Ash Wed'; current_day = 'Ash Wednesday'
        
        # Day header (e.g., "175 MONDAY")
        dm = day_header.match(line)
        if dm:
            current_lect_num = dm.group(1)
            current_day = dm.group(2).title()
            current_reading_year = ""
            # Save any pending psalm without acclamation
            if pending_psalm:
                entries.append(pending_psalm)
                pending_psalm = None
            i += 1; continue
        
        # Date header (e.g., "193 DECEMBER 17")
        dtm = date_header.match(line)
        if dtm:
            current_lect_num = dtm.group(1)
            month = dtm.group(2).title()
            day_num = dtm.group(3)
            current_day = f'{month} {day_num}'
            current_reading_year = ""
            if pending_psalm:
                entries.append(pending_psalm)
                pending_psalm = None
            i += 1; continue
        
        # Year indicator in readings
        if 'FIRST READING' in upper or 'READING' in upper:
            ym = year_in_reading.search(line)
            if ym:
                current_reading_year = ym.group(1).upper()
        
        # --- Data extraction ---
        
        # Responsorial Psalm
        pm = psalm_line.search(line)
        if pm:
            # Save any previous pending psalm
            if pending_psalm:
                entries.append(pending_psalm)
            
            psalm_ref = pm.group(1).strip()
            
            # Get response text
            response = ""
            j = i + 1
            while j < min(i + 5, n):
                rline = lines[j].strip()
                rm = response_line.match(rline)
                if rm:
                    response = rm.group(1).strip()
                    # Sometimes response continues to next line before verse numbers
                    k = j + 1
                    if k < n:
                        next_l = lines[k].strip()
                        # Continue if line doesn't start with a number/verse and isn't empty
                        if next_l and not re.match(r'^(\d+\s|R\.|or:|GOSPEL|RESPONSORIAL|FIRST|GO\s*S)', next_l):
                            response += ' ' + next_l
                    break
                j += 1
            
            # Determine weekday cycle
            if current_reading_year in ('I', 'II'):
                wk_cycle = current_reading_year
            elif current_reading_year in ('A',):
                wk_cycle = 'I'
            elif current_reading_year in ('B',):
                wk_cycle = 'II'
            else:
                wk_cycle = ''
            
            # For non-OT seasons, readings are same both years
            if current_season in ('Advent', 'Christmas', 'Lent', 'Holy Week', 'Easter'):
                wk_cycle = 'I/II'
            
            pending_psalm = {
                'season': current_season,
                'week': current_week,
                'day': current_day,
                'weekday_cycle': wk_cycle,
                'sunday_cycle': '',
                'psalm_reference': psalm_ref,
                'response_text': response,
                'acclamation_ref': '',
                'acclamation_text': '',
                'lectionary_number': current_lect_num,
            }
            i = max(j + 1, i + 1)
            continue
        
        # Gospel Acclamation
        am = accl_header.search(line)
        if am and pending_psalm:
            accl_ref = am.group(1).strip()
            if accl_ref.startswith('See '):
                accl_ref = accl_ref  # Keep "See Psalm 80.4" etc.
            
            # Get acclamation text (skip boilerplate)
            accl_parts = []
            j = i + 1
            while j < min(i + 10, n):
                aline = lines[j].strip()
                if not aline or 'This verse may accompany' in aline or \
                   'If the Alleluia is not sung' in aline or \
                   'the acclamation is omitted' in aline:
                    j += 1; continue
                if re.match(r'GO\s*S\s*P\s*E\s*L\s', aline) or \
                   re.match(r'FIRST READING', aline) or \
                   re.match(r'\d+\s+(MONDAY|TUESDAY|WEDNESDAY|THURSDAY|FRIDAY|SATURDAY)', aline) or \
                   re.match(r'RESPONSORIAL', aline) or \
                   re.match(r'\d+\s+(DECEMBER|JANUARY)', aline):
                    break
                accl_parts.append(aline)
                if len(accl_parts) >= 3:  # Max 3 lines for acclamation text
                    break
                j += 1
            
            accl_text = ' '.join(accl_parts).strip()
            # Clean trailing page/section markers
            accl_text = re.sub(r'\s+\d+\s+(FIRST|SECOND|THIRD|FOURTH|FIFTH|SIXTH|SEVENTH|EIGHTH|NINTH)\s+WEEK.*$', '', accl_text)
            accl_text = re.sub(r'\s+\d+\s+(ADVENT|LENT|EASTER|ORDINARY|MONDAY|TUESDAY|WEDNESDAY|THURSDAY|FRIDAY|SATURDAY|DECEMBER|JANUARY|HOLY|WEEKDAYS|CHRISTMAS|OCTAVE|SARURDAY).*$', '', accl_text, flags=re.IGNORECASE)
            accl_text = re.sub(r'\s+\d+$', '', accl_text)  # Trailing page number
            
            pending_psalm['acclamation_ref'] = accl_ref
            pending_psalm['acclamation_text'] = accl_text
            
            entries.append(pending_psalm)
            pending_psalm = None
            i = j + 1
            continue
        
        i += 1
    
    # Don't forget last pending
    if pending_psalm:
        entries.append(pending_psalm)
    
    return entries


def clean_entries(entries):
    """Post-process to clean up entries."""
    cleaned = []
    for e in entries:
        # Skip entries with empty psalm reference
        if not e['psalm_reference']:
            continue
        
        # Clean psalm reference - remove trailing artifacts
        ref = e['psalm_reference']
        ref = re.sub(r'\s*\+\+\s*$', '', ref)  # Remove trailing ++
        e['psalm_reference'] = ref.strip()
        
        # Clean response text
        resp = e['response_text']
        resp = re.sub(r'\s*\+\+\s*$', '', resp)
        e['response_text'] = resp.strip()
        
        # Clean acclamation text
        accl = e['acclamation_text']
        accl = re.sub(r'\s*\+\+\s*$', '', accl)
        e['acclamation_text'] = accl.strip()
        
        cleaned.append(e)
    
    return cleaned


# ============================================================
# SUNDAY LECTIONARY DATA
# 3-year cycle (A, B, C) - from the Roman Lectionary
# ============================================================

def build_sunday_data():
    """
    Build Sunday psalm data from the official Roman Lectionary.
    Using the Grail Psalter refrains as used in the English-speaking world.
    """
    sundays = []
    
    # ---- ADVENT ----
    advent_sundays = {
        'A': [
            ('Advent', '1', 'Sunday', '', 'A', 'Psalm 122:1-2.3-4.5-6.7-8.9 (R. cf. 1)', 'Let us go rejoicing to the house of the Lord.', 'Psalm 85:8', 'Lord, show us your mercy and love, and grant us your salvation.'),
            ('Advent', '2', 'Sunday', '', 'A', 'Psalm 72:1-2.7-8.12-13.17 (R. cf. 7)', 'In his days justice shall flourish and peace till the moon fails.', 'Luke 3:4.6', 'Prepare the way of the Lord, make straight his paths: all people shall see the salvation of God.'),
            ('Advent', '3', 'Sunday', '', 'A', 'Psalm 146:6-7.8-9.9-10 (R. cf. Isaiah 35:4)', 'Come, Lord, and save us.', 'Isaiah 61:1', 'The spirit of the Lord has been given to me. He has sent me to bring good news to the poor.'),
            ('Advent', '4', 'Sunday', '', 'A', 'Psalm 24:1-2.3-4.5-6 (R. cf. 7c.10b)', 'Let the Lord enter! He is king of glory.', 'Matthew 1:23', 'The virgin will conceive and give birth to a son and they will call him Emmanuel, a name which means God-is-with-us.'),
        ],
        'B': [
            ('Advent', '1', 'Sunday', '', 'B', 'Psalm 80:2-3.15-16.18-19 (R. 4)', 'God of hosts, bring us back; let your face shine on us and we shall be saved.', 'Psalm 85:8', 'Lord, show us your mercy and love, and grant us your salvation.'),
            ('Advent', '2', 'Sunday', '', 'B', 'Psalm 85:9-10.11-12.13-14 (R. 8)', 'Let us see, O Lord, your mercy and give us your saving help.', 'Luke 3:4.6', 'Prepare the way of the Lord, make straight his paths: all people shall see the salvation of God.'),
            ('Advent', '3', 'Sunday', '', 'B', 'Luke 1:46-48.49-50.53-54 (R. Isaiah 61:10b)', 'My soul rejoices in my God.', '(Isaiah 61:1)', 'The spirit of the Lord has been given to me. He has sent me to bring good news to the poor.'),
            ('Advent', '4', 'Sunday', '', 'B', 'Psalm 89:2-3.4-5.27.29 (R. 2a)', 'I will sing for ever of your love, O Lord.', 'Luke 1:38', 'I am the handmaid of the Lord: let what you have said be done to me.'),
        ],
        'C': [
            ('Advent', '1', 'Sunday', '', 'C', 'Psalm 25:4-5.8-9.10.14 (R. 1b)', 'To you, O Lord, I lift my soul.', 'Psalm 85:8', 'Lord, show us your mercy and love, and grant us your salvation.'),
            ('Advent', '2', 'Sunday', '', 'C', 'Psalm 126:1-2.2-3.4-5.6 (R. 3)', 'What marvels the Lord worked for us! Indeed we were glad.', 'Luke 3:4.6', 'Prepare the way of the Lord, make straight his paths: all people shall see the salvation of God.'),
            ('Advent', '3', 'Sunday', '', 'C', 'Isaiah 12:2-3.4.5-6 (R. 6)', 'Sing and shout for joy for great in your midst is the Holy One of Israel.', 'Isaiah 61:1', 'The spirit of the Lord has been given to me. He has sent me to bring good news to the poor.'),
            ('Advent', '4', 'Sunday', '', 'C', 'Psalm 80:2-3.15-16.18-19 (R. 4)', 'God of hosts, bring us back; let your face shine on us and we shall be saved.', 'Luke 1:38', 'I am the handmaid of the Lord: let what you have said be done to me.'),
        ],
    }
    
    # ---- LENT ----
    lent_sundays = {
        'A': [
            ('Lent', '1', 'Sunday', '', 'A', 'Psalm 51:3-4.5-6.12-13.14.17 (R. cf. 3a)', 'Have mercy on us, O Lord, for we have sinned.', 'Matthew 4:4b', 'Man does not live on bread alone, but on every word that comes from the mouth of God.'),
            ('Lent', '2', 'Sunday', '', 'A', 'Psalm 33:4-5.18-19.20.22 (R. 22)', 'May your love be upon us, O Lord, as we place all our hope in you.', 'cf. Matthew 17:5', 'From the bright cloud the Father\'s voice was heard: This is my Son, the Beloved. Listen to him.'),
            ('Lent', '3', 'Sunday', '', 'A', 'Psalm 95:1-2.6-7.8-9 (R. 8)', 'O that today you would listen to his voice! Harden not your hearts.', 'cf. John 4:42.15', 'Lord, you are truly the saviour of the world; give me the living water, so that I may never thirst again.'),
            ('Lent', '4', 'Sunday', '', 'A', 'Psalm 23:1-3a.3b-4.5.6 (R. 1)', 'The Lord is my shepherd; there is nothing I shall want.', 'John 8:12', 'I am the light of the world, says the Lord; anyone who follows me will have the light of life.'),
            ('Lent', '5', 'Sunday', '', 'A', 'Psalm 130:1-2.3-4.5-6.7-8 (R. 7)', 'With the Lord there is mercy and fullness of redemption.', 'John 11:25-26', 'I am the resurrection and the life, says the Lord; whoever believes in me will never die.'),
        ],
        'B': [
            ('Lent', '1', 'Sunday', '', 'B', 'Psalm 25:4-5.6-7.8-9 (R. cf. 10)', 'Your ways, Lord, are faithfulness and love for those who keep your covenant.', 'Matthew 4:4b', 'Man does not live on bread alone, but on every word that comes from the mouth of God.'),
            ('Lent', '2', 'Sunday', '', 'B', 'Psalm 116:10.15.16-17.18-19 (R. 9)', 'I will walk in the presence of the Lord in the land of the living.', 'cf. Matthew 17:5', 'From the bright cloud the Father\'s voice was heard: This is my Son, the Beloved. Listen to him.'),
            ('Lent', '3', 'Sunday', '', 'B', 'Psalm 19:8.9.10.11 (R. John 6:68c)', 'You, Lord, have the message of eternal life.', 'John 3:16', 'God loved the world so much that he gave his only Son; everyone who believes in him has eternal life.'),
            ('Lent', '4', 'Sunday', '', 'B', 'Psalm 137:1-2.3.4-5.6 (R. 6a)', 'O let my tongue cleave to my mouth if I remember you not!', 'John 3:16', 'God loved the world so much that he gave his only Son; everyone who believes in him has eternal life.'),
            ('Lent', '5', 'Sunday', '', 'B', 'Psalm 51:3-4.12-13.14-15 (R. 12a)', 'A pure heart create for me, O God.', 'John 12:26', 'If a man serves me, he must follow me, says the Lord; and where I am, there also will my servant be.'),
        ],
        'C': [
            ('Lent', '1', 'Sunday', '', 'C', 'Psalm 91:1-2.10-11.12-13.14-15 (R. cf. 15b)', 'Be with me, O Lord, in my distress.', 'Matthew 4:4b', 'Man does not live on bread alone, but on every word that comes from the mouth of God.'),
            ('Lent', '2', 'Sunday', '', 'C', 'Psalm 27:1.7-8.8-9.13-14 (R. 1a)', 'The Lord is my light and my help.', 'cf. Matthew 17:5', 'From the bright cloud the Father\'s voice was heard: This is my Son, the Beloved. Listen to him.'),
            ('Lent', '3', 'Sunday', '', 'C', 'Psalm 103:1-2.3-4.6-7.8.11 (R. 8a)', 'The Lord is compassion and love.', 'Matthew 4:17', 'Repent, says the Lord, for the kingdom of heaven is close at hand.'),
            ('Lent', '4', 'Sunday', '', 'C', 'Psalm 34:2-3.4-5.6-7 (R. 9a)', 'Taste and see that the Lord is good.', 'Luke 15:18', 'I will leave this place and go to my father and say: Father, I have sinned against heaven and against you.'),
            ('Lent', '5', 'Sunday', '', 'C', 'Psalm 126:1-2.2-3.4-5.6 (R. 3)', 'What marvels the Lord worked for us! Indeed we were glad.', 'Joel 2:12-13', 'With all your heart turn to me, for I am tender and compassionate.'),
        ],
    }
    
    # ---- ORDINARY TIME ----
    ot_sundays = {
        'A': [
            ('Ordinary Time', '2', 'Sunday', '', 'A', 'Psalm 40:2.4.7-8.8-9.10 (R. 8a.9a)', 'Here I am, Lord! I come to do your will.', 'John 1:14.12b', 'The Word was made flesh and lived among us; to all who did accept him he gave power to become children of God.'),
            ('Ordinary Time', '3', 'Sunday', '', 'A', 'Psalm 27:1.4.13-14 (R. 1a)', 'The Lord is my light and my help.', 'cf. Matthew 4:23', 'Jesus proclaimed the Good News of the kingdom and cured all kinds of sickness among the people.'),
            ('Ordinary Time', '4', 'Sunday', '', 'A', 'Psalm 146:6-7.8-9.9-10 (R. cf. Matthew 5:3)', 'How happy are the poor in spirit; theirs is the kingdom of heaven.', 'Matthew 5:12a', 'Rejoice and be glad, for your reward will be great in heaven.'),
            ('Ordinary Time', '5', 'Sunday', '', 'A', 'Psalm 112:4-5.6-7.8-9 (R. 4a)', 'A light rises in the darkness for the upright.', 'Matthew 5:16', 'Your light must shine in the sight of men, so that, seeing your good works, they may give the praise to your Father in heaven.'),
            ('Ordinary Time', '6', 'Sunday', '', 'A', 'Psalm 119:1-2.4-5.17-18.33-34 (R. 1b)', 'They are happy who follow God\'s law!', 'cf. Matthew 11:25', 'Blessed are you, Father, Lord of heaven and earth, for revealing the mysteries of the kingdom to mere children.'),
            ('Ordinary Time', '7', 'Sunday', '', 'A', 'Psalm 103:1-2.3-4.8.10.12-13 (R. 8a)', 'The Lord is compassion and love.', '1 John 2:5', 'If anyone obeys the word of Christ, God\'s love comes to perfection in him.'),
            ('Ordinary Time', '8', 'Sunday', '', 'A', 'Psalm 62:2-3.6-7.8-9 (R. 2b)', 'In God alone is my soul at rest.', 'Hebrews 4:12', 'The word of God is something alive and active; it can judge the secret emotions and thoughts.'),
            ('Ordinary Time', '9', 'Sunday', '', 'A', 'Psalm 31:2-3.3-4.17.25 (R. 3a)', 'Be a rock of refuge for me, O Lord.', 'cf. John 15:15b', 'I call you friends, says the Lord, because I have made known to you everything I have learnt from my Father.'),
            ('Ordinary Time', '10', 'Sunday', '', 'A', 'Psalm 50:1.8.12-13.14-15 (R. 23b)', 'To the upright I will show the saving power of God.', 'cf. John 13:34', 'I give you a new commandment: love one another just as I have loved you, says the Lord.'),
            ('Ordinary Time', '11', 'Sunday', '', 'A', 'Psalm 100:1-2.3.5 (R. 3c)', 'We are his people, the sheep of his flock.', 'Mark 1:15', 'The kingdom of God is close at hand: repent, and believe the Good News.'),
            ('Ordinary Time', '12', 'Sunday', '', 'A', 'Psalm 69:8-10.14.17.33-35 (R. 14c)', 'In your great love, answer me, O God.', 'John 15:26b.27a', 'The Spirit of Truth will be my witness; and you too will be my witnesses, says the Lord.'),
            ('Ordinary Time', '13', 'Sunday', '', 'A', 'Psalm 89:2-3.16-17.18-19 (R. 2a)', 'I will sing for ever of your love, O Lord.', '1 Peter 2:9', 'You are a chosen race, a royal priesthood, a holy nation; praise God who called you out of darkness into his wonderful light.'),
            ('Ordinary Time', '14', 'Sunday', '', 'A', 'Psalm 145:1-2.8-9.10-11.13-14 (R. 1)', 'I will bless your name for ever, O God my King.', 'cf. Matthew 11:25', 'Blessed are you, Father, Lord of heaven and earth, for revealing the mysteries of the kingdom to mere children.'),
            ('Ordinary Time', '15', 'Sunday', '', 'A', 'Psalm 65:10.11.12-13.14 (R. Luke 8:8)', 'The seed that falls on good ground will yield a fruitful harvest.', '', 'The seed is the word of God, Christ the sower; all who come to him will have life for ever.'),
            ('Ordinary Time', '16', 'Sunday', '', 'A', 'Psalm 86:5-6.9-10.15-16 (R. 5a)', 'O Lord, you are good and forgiving.', 'cf. Matthew 11:25', 'Blessed are you, Father, Lord of heaven and earth, for revealing the mysteries of the kingdom to mere children.'),
            ('Ordinary Time', '17', 'Sunday', '', 'A', 'Psalm 119:57.72.76-77.127-128.129-130 (R. 97a)', 'Lord, how I love your law!', 'cf. Matthew 11:25', 'Blessed are you, Father, Lord of heaven and earth, for revealing the mysteries of the kingdom to mere children.'),
            ('Ordinary Time', '18', 'Sunday', '', 'A', 'Psalm 145:8-9.15-16.17-18 (R. 16)', 'You open wide your hand, O Lord, you grant our desires.', 'cf. Matthew 4:4b', 'Man does not live on bread alone, but on every word that comes from the mouth of God.'),
            ('Ordinary Time', '19', 'Sunday', '', 'A', 'Psalm 85:9-10.11-12.13-14 (R. 8)', 'Let us see, O Lord, your mercy and give us your saving help.', 'cf. Psalm 130:5', 'I hope in the Lord, I trust in his word.'),
            ('Ordinary Time', '20', 'Sunday', '', 'A', 'Psalm 67:2-3.5.6.8 (R. 4)', 'Let the peoples praise you, O God; let all the peoples praise you.', 'cf. Matthew 4:23', 'Jesus proclaimed the Good News of the kingdom and cured all kinds of sickness among the people.'),
            ('Ordinary Time', '21', 'Sunday', '', 'A', 'Psalm 138:1-2.2-3.6.8 (R. 8a)', 'Your love, O Lord, is eternal, discard not the work of your hands.', 'Matthew 16:18', 'You are Peter and on this rock I will build my Church. And the gates of the underworld can never hold out against it.'),
            ('Ordinary Time', '22', 'Sunday', '', 'A', 'Psalm 63:2.3-4.5-6.8-9 (R. 2b)', 'For you my soul is thirsting, O God, my God.', 'cf. Ephesians 1:17-18', 'May the Father of our Lord Jesus Christ enlighten the eyes of our mind, so that we can see what hope his call holds for us.'),
            ('Ordinary Time', '23', 'Sunday', '', 'A', 'Psalm 95:1-2.6-7.8-9 (R. 8)', 'O that today you would listen to his voice! Harden not your hearts.', '2 Corinthians 5:19', 'God in Christ was reconciling the world to himself, and he has entrusted to us the news that they are reconciled.'),
            ('Ordinary Time', '24', 'Sunday', '', 'A', 'Psalm 103:1-2.3-4.9-10.11-12 (R. 8)', 'The Lord is compassion and love, slow to anger and rich in mercy.', 'John 13:34', 'I give you a new commandment: love one another just as I have loved you, says the Lord.'),
            ('Ordinary Time', '25', 'Sunday', '', 'A', 'Psalm 145:2-3.8-9.17-18 (R. 18a)', 'The Lord is close to all who call him.', 'cf. Acts 16:14b', 'Open our heart, O Lord, to accept the words of your Son.'),
            ('Ordinary Time', '26', 'Sunday', '', 'A', 'Psalm 25:4-5.6-7.8-9 (R. 6a)', 'Remember your mercy, Lord.', 'John 10:27', 'The sheep that belong to me listen to my voice, says the Lord, I know them and they follow me.'),
            ('Ordinary Time', '27', 'Sunday', '', 'A', 'Psalm 80:9.12.13-14.15-16.19-20 (R. Isaiah 5:7a)', 'The vineyard of the Lord is the House of Israel.', 'cf. John 15:16', 'I chose you from the world to go out and bear fruit, fruit that will last, says the Lord.'),
            ('Ordinary Time', '28', 'Sunday', '', 'A', 'Psalm 23:1-3a.3b-4.5.6 (R. 6cd)', 'In the Lord\'s own house shall I dwell for ever and ever.', 'cf. Ephesians 1:17-18', 'May the Father of our Lord Jesus Christ enlighten the eyes of our mind, so that we can see what hope his call holds for us.'),
            ('Ordinary Time', '29', 'Sunday', '', 'A', 'Psalm 96:1.3.4-5.7-8.9-10 (R. 7b)', 'Give the Lord glory and power.', 'Philippians 2:15-16', 'You will shine in the world like bright stars because you are offering it the word of life.'),
            ('Ordinary Time', '30', 'Sunday', '', 'A', 'Psalm 18:2-3.3-4.47.51 (R. 2)', 'I love you, Lord, my strength.', 'John 14:23', 'If anyone loves me he will keep my word, and my Father will love him, and we shall come to him.'),
            ('Ordinary Time', '31', 'Sunday', '', 'A', 'Psalm 131:1.2.3 (R. 1)', 'Keep my soul in peace before you, O Lord.', 'Matthew 23:9b.10b', 'You have only one Father, and he is in heaven; you have only one Teacher, the Christ.'),
            ('Ordinary Time', '32', 'Sunday', '', 'A', 'Psalm 63:2.3-4.5-6.7-8 (R. 2b)', 'For you my soul is thirsting, O God, my God.', 'Matthew 25:13', 'Stay awake and stand ready, because you do not know the hour when the Son of Man is coming.'),
            ('Ordinary Time', '33', 'Sunday', '', 'A', 'Psalm 128:1-2.3.4-5 (R. cf. 1a)', 'O blessed are those who fear the Lord.', 'John 15:4a.5b', 'Make your home in me, as I make mine in you. Whoever remains in me bears fruit in plenty.'),
            ('Ordinary Time', '34', 'Sunday', '', 'A', 'Psalm 23:1-2.2-3.5-6 (R. 1)', 'The Lord is my shepherd; there is nothing I shall want.', 'Mark 11:10', 'Blessed is he who comes in the name of the Lord! Blessed is the kingdom of our father David that is coming!'),
        ],
        'B': [],  # Will populate
        'C': [],  # Will populate
    }
    
    # ---- EASTER ----
    easter_sundays = {
        'A': [
            ('Easter', '2', 'Sunday', '', 'A', 'Psalm 118:2-4.13-15.22-24 (R. 1)', 'Give thanks to the Lord for he is good, for his love has no end.', 'John 20:29', 'Jesus said: You believe because you can see me. Happy are those who have not seen and yet believe.'),
            ('Easter', '3', 'Sunday', '', 'A', 'Psalm 16:1-2.5.7-8.9-10.11 (R. 11a)', 'You will show me the path of life, the fullness of joy in your presence.', 'cf. Luke 24:32', 'Lord Jesus, explain the scriptures to us. Make our hearts burn within us as you talk to us.'),
            ('Easter', '4', 'Sunday', '', 'A', 'Psalm 23:1-3a.3b-4.5.6 (R. 1)', 'The Lord is my shepherd; there is nothing I shall want.', 'John 10:14', 'I am the good shepherd, says the Lord; I know my own sheep and my own know me.'),
            ('Easter', '5', 'Sunday', '', 'A', 'Psalm 33:1-2.4-5.18-19 (R. 22)', 'May your love be upon us, O Lord, as we place all our hope in you.', 'John 14:6', 'I am the Way, the Truth and the Life, says the Lord; no one can come to the Father except through me.'),
            ('Easter', '6', 'Sunday', '', 'A', 'Psalm 66:1-3.4-5.6-7.16.20 (R. 1)', 'Cry out with joy to God all the earth.', 'John 14:23', 'If anyone loves me he will keep my word, and my Father will love him, and we shall come to him.'),
            ('Easter', '7', 'Sunday', '', 'A', 'Psalm 27:1.4.7-8 (R. 13)', 'I am sure I shall see the Lord\'s goodness in the land of the living.', 'cf. John 14:18', 'I will not leave you orphans, says the Lord; I will come back to you, and your hearts will be full of joy.'),
        ],
        'B': [],
        'C': [],
    }
    
    # Build all entries from the Sunday data
    all_sunday = []
    for cycle in ('A', 'B', 'C'):
        for data_set in (advent_sundays, lent_sundays, ot_sundays, easter_sundays):
            if cycle in data_set:
                for entry_tuple in data_set[cycle]:
                    all_sunday.append({
                        'season': entry_tuple[0],
                        'week': entry_tuple[1],
                        'day': entry_tuple[2],
                        'weekday_cycle': entry_tuple[3],
                        'sunday_cycle': entry_tuple[4],
                        'psalm_reference': entry_tuple[5],
                        'response_text': entry_tuple[6],
                        'acclamation_ref': entry_tuple[7],
                        'acclamation_text': entry_tuple[8],
                        'lectionary_number': '',
                    })
    
    return all_sunday


def write_csv(entries, output_path, fieldnames=None):
    """Write entries to CSV."""
    if not fieldnames:
        fieldnames = [
            'Season', 'Week', 'Day', 'Weekday Cycle', 'Sunday Cycle',
            'Full Reference', 'Refrain Text', 'Acclamation Ref', 'Acclamation Text',
            'Lectionary Number'
        ]
    
    with open(output_path, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        
        for entry in entries:
            writer.writerow({
                'Season': entry['season'],
                'Week': entry['week'],
                'Day': entry['day'],
                'Weekday Cycle': entry['weekday_cycle'],
                'Sunday Cycle': entry['sunday_cycle'],
                'Full Reference': entry['psalm_reference'],
                'Refrain Text': entry['response_text'],
                'Acclamation Ref': entry['acclamation_ref'],
                'Acclamation Text': entry['acclamation_text'],
                'Lectionary Number': entry.get('lectionary_number', ''),
            })
    
    print(f"Wrote {len(entries)} entries to {output_path}")


def find_discrepancies(weekday_entries, sunday_entries):
    """Flag potential issues for manual review."""
    discrepancies = []
    
    for e in weekday_entries + sunday_entries:
        issues = []
        
        # Empty psalm reference
        if not e['psalm_reference']:
            issues.append('MISSING_PSALM_REF')
        
        # Empty response
        if not e['response_text']:
            issues.append('MISSING_RESPONSE')
        
        # Empty acclamation
        if not e['acclamation_text'] and not e['acclamation_ref']:
            issues.append('MISSING_ACCLAMATION')
        
        # Suspicious psalm reference (no verse numbers)
        if e['psalm_reference'] and not re.search(r'\d+[.\-,]', e['psalm_reference']):
            issues.append('SUSPICIOUS_PSALM_REF')
        
        # Response text too short
        if e['response_text'] and len(e['response_text']) < 10:
            issues.append('SHORT_RESPONSE')
        
        # Response text too long (might have garbage)
        if e['response_text'] and len(e['response_text']) > 120:
            issues.append('LONG_RESPONSE')
        
        # Acclamation text too long
        if e['acclamation_text'] and len(e['acclamation_text']) > 200:
            issues.append('LONG_ACCLAMATION')
        
        # Missing season/day
        if not e['season']:
            issues.append('MISSING_SEASON')
        if not e['day']:
            issues.append('MISSING_DAY')
        
        if issues:
            d = dict(e)
            d['issues'] = '; '.join(issues)
            discrepancies.append(d)
    
    return discrepancies


def main():
    base_dir = r'c:\dev\catholicdaily-flutter'
    scripts_dir = os.path.join(base_dir, 'scripts')
    
    # 1. Extract weekday data from PDFs
    print("=== Extracting weekday data from PDF A (Year I) ===")
    entries_a = extract_psalm_acclamation_pairs(os.path.join(scripts_dir, 'weekday_a_full.txt'))
    entries_a = clean_entries(entries_a)
    print(f"  Extracted {len(entries_a)} entries")
    
    print("=== Extracting weekday data from PDF B (Year II) ===")
    entries_b = extract_psalm_acclamation_pairs(os.path.join(scripts_dir, 'weekday_b_full.txt'))
    entries_b = clean_entries(entries_b)
    print(f"  Extracted {len(entries_b)} entries")
    
    # 2. Build Sunday data
    print("=== Building Sunday lectionary data ===")
    sunday_entries = build_sunday_data()
    print(f"  Built {len(sunday_entries)} Sunday entries")
    
    # 3. Combine all weekday entries (deduplicate seasonal)
    all_weekday = []
    seen_seasonal = set()
    
    for entry in entries_a:
        if entry['weekday_cycle'] == 'I/II':
            key = (entry['season'], entry['week'], entry['day'], entry['psalm_reference'])
            if key not in seen_seasonal:
                seen_seasonal.add(key)
                all_weekday.append(entry)
        else:
            all_weekday.append(entry)
    
    for entry in entries_b:
        if entry['weekday_cycle'] == 'I/II':
            key = (entry['season'], entry['week'], entry['day'], entry['psalm_reference'])
            if key not in seen_seasonal:
                seen_seasonal.add(key)
                all_weekday.append(entry)
        else:
            all_weekday.append(entry)
    
    print(f"  Combined weekday (deduplicated): {len(all_weekday)} entries")
    
    # 4. Combine weekday + Sunday
    all_entries = all_weekday + sunday_entries
    
    # Sort
    season_order = {'Advent':0, 'Christmas':1, 'Ordinary Time':2, 'Lent':3, 'Holy Week':4, 'Easter':5}
    day_order = {'Monday':0, 'Tuesday':1, 'Wednesday':2, 'Thursday':3, 'Friday':4, 'Saturday':5, 'Sunday':6}
    
    def sort_key(e):
        s = season_order.get(e['season'], 99)
        try: w = int(e['week'])
        except: w = 99 if e['week'] not in ('Octave','Ash Wed','Dec 17-24') else 0
        d = day_order.get(e['day'], 99)
        return (s, w, d)
    
    all_entries.sort(key=sort_key)
    
    # 5. Write main CSV
    write_csv(all_entries, os.path.join(base_dir, 'lectionary_psalms.csv'))
    
    # 6. Find and write discrepancies
    discrepancies = find_discrepancies(all_weekday, sunday_entries)
    
    disc_fields = [
        'Season', 'Week', 'Day', 'Weekday Cycle', 'Sunday Cycle',
        'Full Reference', 'Refrain Text', 'Acclamation Ref', 'Acclamation Text',
        'Lectionary Number', 'Issues'
    ]
    
    with open(os.path.join(base_dir, 'discrepancies.csv'), 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=disc_fields)
        writer.writeheader()
        for d in discrepancies:
            writer.writerow({
                'Season': d['season'],
                'Week': d['week'],
                'Day': d['day'],
                'Weekday Cycle': d['weekday_cycle'],
                'Sunday Cycle': d['sunday_cycle'],
                'Full Reference': d['psalm_reference'],
                'Refrain Text': d['response_text'],
                'Acclamation Ref': d['acclamation_ref'],
                'Acclamation Text': d['acclamation_text'],
                'Lectionary Number': d.get('lectionary_number', ''),
                'Issues': d['issues'],
            })
    
    print(f"\nWrote {len(discrepancies)} discrepancies to discrepancies.csv")
    
    # Summary by season
    print(f"\n=== Final Summary ===")
    print(f"Total entries: {len(all_entries)}")
    from collections import Counter
    season_counts = Counter(e['season'] for e in all_entries)
    for s, c in sorted(season_counts.items()):
        print(f"  {s}: {c}")
    
    cycle_counts = Counter(e['weekday_cycle'] or e['sunday_cycle'] or 'Unknown' for e in all_entries)
    print(f"\nBy cycle:")
    for c, cnt in sorted(cycle_counts.items()):
        print(f"  {c}: {cnt}")
    
    # Show samples
    print(f"\n=== Sample entries ===")
    for e in all_entries[:5]:
        cyc = e['weekday_cycle'] or e['sunday_cycle']
        print(f"  {e['season']}\t{e['week']}\t{e['day']}\t{cyc}\t{e['psalm_reference'][:50]}\t{e['response_text'][:50]}")


if __name__ == '__main__':
    main()
