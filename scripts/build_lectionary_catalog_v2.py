"""
Build Catholic Lectionary psalm/acclamation catalog - V2.
Uses page footer patterns like "NNN WEEK IN ORDINARY TIME - YEAR I/II"
to accurately track weekday cycle.
"""
import re
import csv
import os
from collections import defaultdict

def extract_entries_v2(text_path):
    """
    Extract psalm+acclamation entries using page footers for context.
    The key insight: page footers contain "PAGE_NUM SEASON - YEAR I/II"
    """
    with open(text_path, 'r', encoding='utf-8') as f:
        lines = f.read().split('\n')

    entries = []
    current_season = ""
    current_week = ""
    current_day = ""
    current_lect_num = ""
    current_year = ""  # I or II

    # Patterns
    day_header = re.compile(r'^(\d{1,3})\s+(MONDAY|TUESDAY|WEDNESDAY|THURSDAY|FRIDAY|SATURDAY)\s*$')
    date_header = re.compile(r'^(\d{1,3})\s+(DECEMBER|JANUARY|FEBRUARY|MARCH|APRIL|MAY|JUNE)\s+(\d{1,2})\s*$')

    # Page footer with YEAR indicator (critical for OT)
    # e.g., "106 FIRST WEEK IN ORDINARY TIME – YEAR I"
    ot_year_footer = re.compile(
        r'(\d+)\s+(FIRST|SECOND|THIRD|FOURTH|FIFTH|SIXTH|SEVENTH|EIGHTH|NINTH)\s+WEEK\s+IN\s+ORDINARY\s+TIME\s*[–\-]\s*YEAR\s+(I+)',
        re.IGNORECASE
    )
    week_num_map = {'FIRST':'1','SECOND':'2','THIRD':'3','FOURTH':'4','FIFTH':'5',
                    'SIXTH':'6','SEVENTH':'7','EIGHTH':'8','NINTH':'9'}

    # Week headers (for non-OT seasons)
    week_header = re.compile(
        r'(FIRST|SECOND|THIRD|FOURTH|FIFTH|SIXTH|SEVENTH|EIGHTH|NINTH)\s+WEEK\s+'
        r'(?:OF|IN)\s+(ADVENT|LENT|EASTER|ORDINARY TIME)',
        re.IGNORECASE
    )

    # Season markers with page footer patterns for non-OT
    lent_footer = re.compile(r'(\d+)\s+(FIRST|SECOND|THIRD|FOURTH|FIFTH)\s+WEEK\s+OF\s+LENT', re.IGNORECASE)
    advent_footer = re.compile(r'(\d+)\s+(FIRST|SECOND|THIRD)\s+WEEK\s+OF\s+ADVENT', re.IGNORECASE)
    easter_footer = re.compile(r'(\d+)\s+(SECOND|THIRD|FOURTH|FIFTH|SIXTH|SEVENTH)\s+WEEK\s+OF\s+EASTER', re.IGNORECASE)

    psalm_line = re.compile(r'RESPONSORIAL\s+PSALM\s+(.*)', re.IGNORECASE)
    response_line = re.compile(r'^R\.\s+(.+)')
    accl_header = re.compile(r'GOSPEL\s+ACCLAMATI\s*O\s*N\s*(.*)', re.IGNORECASE)

    pending_psalm = None
    i = 0
    n = len(lines)

    while i < n:
        line = lines[i].strip()
        upper = line.upper()

        # --- OT Year footer (highest priority for cycle tracking) ---
        ym = ot_year_footer.search(line)
        if ym:
            current_season = 'Ordinary Time'
            current_week = week_num_map.get(ym.group(2).upper(), ym.group(2))
            current_year = ym.group(3).upper()
            i += 1; continue

        # --- Lent/Advent/Easter week footers ---
        lm = lent_footer.search(line)
        if lm and 'ORDINARY' not in upper:
            current_season = 'Lent'
            current_week = week_num_map.get(lm.group(2).upper(), lm.group(2))
            current_year = 'I/II'
            i += 1; continue

        am = advent_footer.search(line)
        if am and 'ORDINARY' not in upper and 'LENT' not in upper:
            current_season = 'Advent'
            current_week = week_num_map.get(am.group(2).upper(), am.group(2))
            current_year = 'I/II'
            i += 1; continue

        em = easter_footer.search(line)
        if em and 'ORDINARY' not in upper:
            current_season = 'Easter'
            current_week = week_num_map.get(em.group(2).upper(), em.group(2))
            current_year = 'I/II'
            i += 1; continue

        # --- General week headers ---
        wm = week_header.search(line)
        if wm:
            w = wm.group(1).upper()
            s = wm.group(2).upper()
            current_week = week_num_map.get(w, w)
            if 'ADVENT' in s:
                current_season = 'Advent'; current_year = 'I/II'
            elif 'LENT' in s:
                current_season = 'Lent'; current_year = 'I/II'
            elif 'EASTER' in s:
                current_season = 'Easter'; current_year = 'I/II'
            elif 'ORDINARY' in s:
                current_season = 'Ordinary Time'
            i += 1; continue

        # --- Special season markers ---
        if 'OCTAVE OF CHRISTMAS' in upper:
            current_season = 'Christmas'; current_week = 'Octave'; current_year = 'I/II'
        elif 'OCTAVE OF EASTER' in upper:
            current_season = 'Easter'; current_week = 'Octave'; current_year = 'I/II'
        elif re.search(r'HOLY WEEK', upper) and 'FIFTH' not in upper:
            current_season = 'Holy Week'; current_week = ''; current_year = 'I/II'
        elif re.search(r'ADVENT WEEKDAYS.*DECEMBER 17', upper):
            current_season = 'Advent'; current_week = 'Dec 17-24'; current_year = 'I/II'
        elif 'WEEKDAYS BETWEEN NEW YEAR' in upper or 'WEEKDAYS BETWEEN JANUARY' in upper:
            current_season = 'Christmas'; current_week = 'Before Epiphany'; current_year = 'I/II'
        elif 'WEEKDAYS BETWEEN EPIPHANY' in upper:
            current_season = 'Christmas'; current_week = 'After Epiphany'; current_year = 'I/II'
        elif 'ASH WEDNESDAY' in upper and re.match(r'^\d+\s+ASH', upper):
            current_season = 'Lent'; current_week = 'Ash Wed'; current_day = 'Ash Wednesday'; current_year = 'I/II'
        elif re.search(r'AFTER ASH WEDNESDAY', upper):
            current_season = 'Lent'; current_week = 'After Ash Wed'; current_year = 'I/II'
        elif 'GOSPEL ACCLAMATIONS' in upper and 'ORDINARY' in upper:
            # Skip gospel acclamation index pages
            i += 1; continue

        # --- Day header ---
        dm = day_header.match(line)
        if dm:
            current_lect_num = dm.group(1)
            current_day = dm.group(2).title()
            if pending_psalm:
                entries.append(pending_psalm)
                pending_psalm = None
            i += 1; continue

        # --- Date header (e.g., "193 DECEMBER 17") ---
        dtm = date_header.match(line)
        if dtm:
            current_lect_num = dtm.group(1)
            month = dtm.group(2).title()
            day_num = dtm.group(3)
            current_day = f'{month} {day_num}'
            if pending_psalm:
                entries.append(pending_psalm)
                pending_psalm = None
            i += 1; continue

        # --- Responsorial Psalm ---
        pm = psalm_line.search(line)
        if pm:
            if pending_psalm:
                entries.append(pending_psalm)

            psalm_ref = pm.group(1).strip()
            # Clean trailing ++ and page artifacts
            psalm_ref = re.sub(r'\s*\+\+\s*$', '', psalm_ref)

            # Get response
            response = ""
            j = i + 1
            while j < min(i + 5, n):
                rline = lines[j].strip()
                rm = response_line.match(rline)
                if rm:
                    response = rm.group(1).strip()
                    # Check continuation
                    k = j + 1
                    if k < n:
                        next_l = lines[k].strip()
                        if next_l and not re.match(r'^(\d+\s|R\.|or:|GOSPEL|RESPONSORIAL|FIRST|GO\s*S)', next_l) and len(next_l) < 80:
                            response += ' ' + next_l
                    break
                j += 1

            # Clean response
            response = re.sub(r'\s*\+\+\s*$', '', response)

            pending_psalm = {
                'season': current_season,
                'week': current_week,
                'day': current_day,
                'weekday_cycle': current_year if current_year else '',
                'sunday_cycle': '',
                'psalm_reference': psalm_ref,
                'response_text': response,
                'acclamation_ref': '',
                'acclamation_text': '',
                'lectionary_number': current_lect_num,
            }
            i = max(j + 1, i + 1)
            continue

        # --- Gospel Acclamation ---
        acm = accl_header.search(line)
        if acm and pending_psalm:
            accl_ref = acm.group(1).strip()

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
                   day_header.match(aline) or \
                   date_header.match(aline) or \
                   re.match(r'RESPONSORIAL', aline):
                    break
                accl_parts.append(aline)
                if len(accl_parts) >= 3:
                    break
                j += 1

            accl_text = ' '.join(accl_parts).strip()
            # Clean trailing page/section markers
            accl_text = re.sub(r'\s+\d+\s+(FIRST|SECOND|THIRD|FOURTH|FIFTH|SIXTH|SEVENTH|EIGHTH|NINTH)\s+WEEK.*$', '', accl_text, flags=re.IGNORECASE)
            accl_text = re.sub(r'\s+\d+\s+(ADVENT|LENT|EASTER|ORDINARY|MONDAY|TUESDAY|WEDNESDAY|THURSDAY|FRIDAY|SATURDAY|DECEMBER|JANUARY|HOLY|WEEKDAYS|CHRISTMAS|OCTAVE|SARURDAY|AFTER|BETWEEN).*$', '', accl_text, flags=re.IGNORECASE)
            accl_text = re.sub(r'\s+\d+$', '', accl_text)

            pending_psalm['acclamation_ref'] = accl_ref
            pending_psalm['acclamation_text'] = accl_text

            entries.append(pending_psalm)
            pending_psalm = None
            i = j + 1
            continue

        i += 1

    if pending_psalm:
        entries.append(pending_psalm)

    return entries


def deduplicate_ot_entries(entries):
    """
    In OT, each weekday has ONE psalm that goes with THAT day's readings.
    The PDF lists multiple first readings per week (Mon-Sat), each followed
    by its own psalm. These are actually different days, not alternatives.
    
    But the parser might create duplicates if the day tracking gets confused.
    Group by (season, week, day, cycle) and keep unique psalm entries.
    """
    seen = set()
    deduped = []
    for e in entries:
        key = (e['season'], e['week'], e['day'], e['weekday_cycle'], e['psalm_reference'])
        if key not in seen:
            seen.add(key)
            deduped.append(e)
    return deduped


def build_sunday_data():
    """Build Sunday psalm data for all 3 cycles (A, B, C) across all seasons."""
    sundays = []

    # Helper to add entries
    def add(season, week, cycle, psalm_ref, refrain, accl_ref, accl_text):
        sundays.append({
            'season': season, 'week': week, 'day': 'Sunday',
            'weekday_cycle': '', 'sunday_cycle': cycle,
            'psalm_reference': psalm_ref, 'response_text': refrain,
            'acclamation_ref': accl_ref, 'acclamation_text': accl_text,
            'lectionary_number': '',
        })

    # ==== ADVENT - CYCLE A ====
    add('Advent','1','A','Psalm 122:1-2.3-4.5-6.7-8.9 (R. cf. 1)','Let us go rejoicing to the house of the Lord.','Psalm 85:8','Lord, show us your mercy and love, and grant us your salvation.')
    add('Advent','2','A','Psalm 72:1-2.7-8.12-13.17 (R. cf. 7)','In his days justice shall flourish and peace till the moon fails.','Luke 3:4.6','Prepare the way of the Lord, make straight his paths: all people shall see the salvation of God.')
    add('Advent','3','A','Psalm 146:6-7.8-9.9-10 (R. cf. Isaiah 35:4)','Come, Lord, and save us.','Isaiah 61:1','The spirit of the Lord has been given to me. He has sent me to bring good news to the poor.')
    add('Advent','4','A','Psalm 24:1-2.3-4.5-6 (R. cf. 7c.10b)','Let the Lord enter! He is king of glory.','Matthew 1:23','The virgin will conceive and give birth to a son and they will call him Emmanuel, a name which means God-is-with-us.')

    # ==== ADVENT - CYCLE B ====
    add('Advent','1','B','Psalm 80:2-3.15-16.18-19 (R. 4)','God of hosts, bring us back; let your face shine on us and we shall be saved.','Psalm 85:8','Lord, show us your mercy and love, and grant us your salvation.')
    add('Advent','2','B','Psalm 85:9-10.11-12.13-14 (R. 8)','Let us see, O Lord, your mercy and give us your saving help.','Luke 3:4.6','Prepare the way of the Lord, make straight his paths: all people shall see the salvation of God.')
    add('Advent','3','B','Luke 1:46-48.49-50.53-54 (R. Isaiah 61:10b)','My soul rejoices in my God.','Isaiah 61:1','The spirit of the Lord has been given to me. He has sent me to bring good news to the poor.')
    add('Advent','4','B','Psalm 89:2-3.4-5.27.29 (R. 2a)','I will sing for ever of your love, O Lord.','Luke 1:38','I am the handmaid of the Lord: let what you have said be done to me.')

    # ==== ADVENT - CYCLE C ====
    add('Advent','1','C','Psalm 25:4-5.8-9.10.14 (R. 1b)','To you, O Lord, I lift my soul.','Psalm 85:8','Lord, show us your mercy and love, and grant us your salvation.')
    add('Advent','2','C','Psalm 126:1-2.2-3.4-5.6 (R. 3)','What marvels the Lord worked for us! Indeed we were glad.','Luke 3:4.6','Prepare the way of the Lord, make straight his paths: all people shall see the salvation of God.')
    add('Advent','3','C','Isaiah 12:2-3.4.5-6 (R. 6)','Sing and shout for joy for great in your midst is the Holy One of Israel.','Isaiah 61:1','The spirit of the Lord has been given to me. He has sent me to bring good news to the poor.')
    add('Advent','4','C','Psalm 80:2-3.15-16.18-19 (R. 4)','God of hosts, bring us back; let your face shine on us and we shall be saved.','Luke 1:38','I am the handmaid of the Lord: let what you have said be done to me.')

    # ==== LENT - CYCLE A ====
    add('Lent','1','A','Psalm 51:3-4.5-6.12-13.14.17 (R. cf. 3a)','Have mercy on us, O Lord, for we have sinned.','Matthew 4:4b','Man does not live on bread alone, but on every word that comes from the mouth of God.')
    add('Lent','2','A','Psalm 33:4-5.18-19.20.22 (R. 22)','May your love be upon us, O Lord, as we place all our hope in you.','cf. Matthew 17:5','From the bright cloud the Father\'s voice was heard: This is my Son, the Beloved. Listen to him.')
    add('Lent','3','A','Psalm 95:1-2.6-7.8-9 (R. 8)','O that today you would listen to his voice! Harden not your hearts.','cf. John 4:42.15','Lord, you are truly the saviour of the world; give me the living water, so that I may never thirst again.')
    add('Lent','4','A','Psalm 23:1-3a.3b-4.5.6 (R. 1)','The Lord is my shepherd; there is nothing I shall want.','John 8:12','I am the light of the world, says the Lord; anyone who follows me will have the light of life.')
    add('Lent','5','A','Psalm 130:1-2.3-4.5-6.7-8 (R. 7)','With the Lord there is mercy and fullness of redemption.','John 11:25-26','I am the resurrection and the life, says the Lord; whoever believes in me will never die.')

    # ==== LENT - CYCLE B ====
    add('Lent','1','B','Psalm 25:4-5.6-7.8-9 (R. cf. 10)','Your ways, Lord, are faithfulness and love for those who keep your covenant.','Matthew 4:4b','Man does not live on bread alone, but on every word that comes from the mouth of God.')
    add('Lent','2','B','Psalm 116:10.15.16-17.18-19 (R. 9)','I will walk in the presence of the Lord in the land of the living.','cf. Matthew 17:5','From the bright cloud the Father\'s voice was heard: This is my Son, the Beloved. Listen to him.')
    add('Lent','3','B','Psalm 19:8.9.10.11 (R. John 6:68c)','You, Lord, have the message of eternal life.','John 3:16','God loved the world so much that he gave his only Son; everyone who believes in him has eternal life.')
    add('Lent','4','B','Psalm 137:1-2.3.4-5.6 (R. 6a)','O let my tongue cleave to my mouth if I remember you not!','John 3:16','God loved the world so much that he gave his only Son; everyone who believes in him has eternal life.')
    add('Lent','5','B','Psalm 51:3-4.12-13.14-15 (R. 12a)','A pure heart create for me, O God.','John 12:26','If a man serves me, he must follow me, says the Lord; and where I am, there also will my servant be.')

    # ==== LENT - CYCLE C ====
    add('Lent','1','C','Psalm 91:1-2.10-11.12-13.14-15 (R. cf. 15b)','Be with me, O Lord, in my distress.','Matthew 4:4b','Man does not live on bread alone, but on every word that comes from the mouth of God.')
    add('Lent','2','C','Psalm 27:1.7-8.8-9.13-14 (R. 1a)','The Lord is my light and my help.','cf. Matthew 17:5','From the bright cloud the Father\'s voice was heard: This is my Son, the Beloved. Listen to him.')
    add('Lent','3','C','Psalm 103:1-2.3-4.6-7.8.11 (R. 8a)','The Lord is compassion and love.','Matthew 4:17','Repent, says the Lord, for the kingdom of heaven is close at hand.')
    add('Lent','4','C','Psalm 34:2-3.4-5.6-7 (R. 9a)','Taste and see that the Lord is good.','Luke 15:18','I will leave this place and go to my father and say: Father, I have sinned against heaven and against you.')
    add('Lent','5','C','Psalm 126:1-2.2-3.4-5.6 (R. 3)','What marvels the Lord worked for us! Indeed we were glad.','Joel 2:12-13','With all your heart turn to me, for I am tender and compassionate.')

    # ==== EASTER - CYCLE A ====
    add('Easter','2','A','Psalm 118:2-4.13-15.22-24 (R. 1)','Give thanks to the Lord for he is good, for his love has no end.','John 20:29','Jesus said: You believe because you can see me. Happy are those who have not seen and yet believe.')
    add('Easter','3','A','Psalm 16:1-2.5.7-8.9-10.11 (R. 11a)','You will show me the path of life, the fullness of joy in your presence.','cf. Luke 24:32','Lord Jesus, explain the scriptures to us. Make our hearts burn within us as you talk to us.')
    add('Easter','4','A','Psalm 23:1-3a.3b-4.5.6 (R. 1)','The Lord is my shepherd; there is nothing I shall want.','John 10:14','I am the good shepherd, says the Lord; I know my own sheep and my own know me.')
    add('Easter','5','A','Psalm 33:1-2.4-5.18-19 (R. 22)','May your love be upon us, O Lord, as we place all our hope in you.','John 14:6','I am the Way, the Truth and the Life, says the Lord; no one can come to the Father except through me.')
    add('Easter','6','A','Psalm 66:1-3.4-5.6-7.16.20 (R. 1)','Cry out with joy to God all the earth.','John 14:23','If anyone loves me he will keep my word, and my Father will love him, and we shall come to him.')
    add('Easter','7','A','Psalm 27:1.4.7-8 (R. 13)','I am sure I shall see the Lord\'s goodness in the land of the living.','cf. John 14:18','I will not leave you orphans, says the Lord; I will come back to you, and your hearts will be full of joy.')

    # ==== EASTER - CYCLE B ====
    add('Easter','2','B','Psalm 118:2-4.13-15.22-24 (R. 1)','Give thanks to the Lord for he is good, for his love has no end.','John 20:29','Jesus said: You believe because you can see me. Happy are those who have not seen and yet believe.')
    add('Easter','3','B','Psalm 4:2.4.7.9 (R. 7a)','Lift up the light of your face on us, O Lord.','cf. Luke 24:32','Lord Jesus, explain the scriptures to us. Make our hearts burn within us as you talk to us.')
    add('Easter','4','B','Psalm 118:1.8-9.21-23.26.28-29 (R. 22)','The stone which the builders rejected has become the corner stone.','John 10:14','I am the good shepherd, says the Lord; I know my own sheep and my own know me.')
    add('Easter','5','B','Psalm 22:26-27.28.30.31-32 (R. 26a)','You, Lord, are my praise in the great assembly.','John 15:4a.5b','Make your home in me, as I make mine in you. Whoever remains in me bears fruit in plenty.')
    add('Easter','6','B','Psalm 98:1.2-3.3-4 (R. cf. 2b)','The Lord has shown his salvation to the nations.','John 14:23','If anyone loves me he will keep my word, and my Father will love him, and we shall come to him.')
    add('Easter','7','B','Psalm 103:1-2.11-12.19-20 (R. 19a)','The Lord has set his sway in heaven.','cf. John 14:18','I will not leave you orphans, says the Lord; I will come back to you, and your hearts will be full of joy.')

    # ==== EASTER - CYCLE C ====
    add('Easter','2','C','Psalm 118:2-4.13-15.22-24 (R. 1)','Give thanks to the Lord for he is good, for his love has no end.','John 20:29','Jesus said: You believe because you can see me. Happy are those who have not seen and yet believe.')
    add('Easter','3','C','Psalm 30:2.4.5-6.11-12.13 (R. 2a)','I will praise you, Lord, you have rescued me.','','Christ is risen, the Lord of all creation; he has shown pity on all people.')
    add('Easter','4','C','Psalm 100:1-2.3.5 (R. 3c)','We are his people, the sheep of his flock.','John 10:14','I am the good shepherd, says the Lord; I know my own sheep and my own know me.')
    add('Easter','5','C','Psalm 145:8-9.10-11.12-13 (R. cf. 1)','I will bless your name for ever, O God my King.','John 13:34','I give you a new commandment: love one another just as I have loved you, says the Lord.')
    add('Easter','6','C','Psalm 67:2-3.5.6.8 (R. 4)','Let the peoples praise you, O God; let all the peoples praise you.','John 14:23','If anyone loves me he will keep my word, and my Father will love him, and we shall come to him.')
    add('Easter','7','C','Psalm 97:1-2.6-7.9 (R. cf. 1a.9a)','The Lord is king, most high above all the earth.','cf. John 14:18','I will not leave you orphans, says the Lord; I will come back to you, and your hearts will be full of joy.')

    # ==== ORDINARY TIME - CYCLE A (Weeks 2-34) ====
    ot_a = [
        ('2','Psalm 40:2.4.7-8.8-9.10 (R. 8a.9a)','Here I am, Lord! I come to do your will.','John 1:14.12b','The Word was made flesh and lived among us; to all who did accept him he gave power to become children of God.'),
        ('3','Psalm 27:1.4.13-14 (R. 1a)','The Lord is my light and my help.','cf. Matthew 4:23','Jesus proclaimed the Good News of the kingdom and cured all kinds of sickness among the people.'),
        ('4','Psalm 146:6-7.8-9.9-10 (R. cf. Matthew 5:3)','How happy are the poor in spirit; theirs is the kingdom of heaven.','Matthew 5:12a','Rejoice and be glad, for your reward will be great in heaven.'),
        ('5','Psalm 112:4-5.6-7.8-9 (R. 4a)','A light rises in the darkness for the upright.','Matthew 5:16','Your light must shine in the sight of men, so that, seeing your good works, they may give the praise to your Father in heaven.'),
        ('6','Psalm 119:1-2.4-5.17-18.33-34 (R. 1b)','They are happy who follow God\'s law!','cf. Matthew 11:25','Blessed are you, Father, Lord of heaven and earth, for revealing the mysteries of the kingdom to mere children.'),
        ('7','Psalm 103:1-2.3-4.8.10.12-13 (R. 8a)','The Lord is compassion and love.','1 John 2:5','If anyone obeys the word of Christ, God\'s love comes to perfection in him.'),
        ('8','Psalm 62:2-3.6-7.8-9 (R. 2b)','In God alone is my soul at rest.','Hebrews 4:12','The word of God is something alive and active; it can judge the secret emotions and thoughts.'),
        ('9','Psalm 31:2-3.3-4.17.25 (R. 3a)','Be a rock of refuge for me, O Lord.','cf. John 15:15b','I call you friends, says the Lord, because I have made known to you everything I have learnt from my Father.'),
        ('10','Psalm 50:1.8.12-13.14-15 (R. 23b)','To the upright I will show the saving power of God.','cf. John 13:34','I give you a new commandment: love one another just as I have loved you, says the Lord.'),
        ('11','Psalm 100:1-2.3.5 (R. 3c)','We are his people, the sheep of his flock.','Mark 1:15','The kingdom of God is close at hand: repent, and believe the Good News.'),
        ('12','Psalm 69:8-10.14.17.33-35 (R. 14c)','In your great love, answer me, O God.','John 15:26b.27a','The Spirit of Truth will be my witness; and you too will be my witnesses, says the Lord.'),
        ('13','Psalm 89:2-3.16-17.18-19 (R. 2a)','I will sing for ever of your love, O Lord.','1 Peter 2:9','You are a chosen race, a royal priesthood, a holy nation; praise God who called you out of darkness into his wonderful light.'),
        ('14','Psalm 145:1-2.8-9.10-11.13-14 (R. 1)','I will bless your name for ever, O God my King.','cf. Matthew 11:25','Blessed are you, Father, Lord of heaven and earth, for revealing the mysteries of the kingdom to mere children.'),
        ('15','Psalm 65:10.11.12-13.14 (R. Luke 8:8)','The seed that falls on good ground will yield a fruitful harvest.','','The seed is the word of God, Christ the sower; all who come to him will have life for ever.'),
        ('16','Psalm 86:5-6.9-10.15-16 (R. 5a)','O Lord, you are good and forgiving.','cf. Matthew 11:25','Blessed are you, Father, Lord of heaven and earth, for revealing the mysteries of the kingdom to mere children.'),
        ('17','Psalm 119:57.72.76-77.127-128.129-130 (R. 97a)','Lord, how I love your law!','cf. Matthew 11:25','Blessed are you, Father, Lord of heaven and earth, for revealing the mysteries of the kingdom to mere children.'),
        ('18','Psalm 145:8-9.15-16.17-18 (R. 16)','You open wide your hand, O Lord, you grant our desires.','cf. Matthew 4:4b','Man does not live on bread alone, but on every word that comes from the mouth of God.'),
        ('19','Psalm 85:9-10.11-12.13-14 (R. 8)','Let us see, O Lord, your mercy and give us your saving help.','cf. Psalm 130:5','I hope in the Lord, I trust in his word.'),
        ('20','Psalm 67:2-3.5.6.8 (R. 4)','Let the peoples praise you, O God; let all the peoples praise you.','cf. Matthew 4:23','Jesus proclaimed the Good News of the kingdom and cured all kinds of sickness among the people.'),
        ('21','Psalm 138:1-2.2-3.6.8 (R. 8a)','Your love, O Lord, is eternal, discard not the work of your hands.','Matthew 16:18','You are Peter and on this rock I will build my Church. And the gates of the underworld can never hold out against it.'),
        ('22','Psalm 63:2.3-4.5-6.8-9 (R. 2b)','For you my soul is thirsting, O God, my God.','cf. Ephesians 1:17-18','May the Father of our Lord Jesus Christ enlighten the eyes of our mind, so that we can see what hope his call holds for us.'),
        ('23','Psalm 95:1-2.6-7.8-9 (R. 8)','O that today you would listen to his voice! Harden not your hearts.','2 Corinthians 5:19','God in Christ was reconciling the world to himself, and he has entrusted to us the news that they are reconciled.'),
        ('24','Psalm 103:1-2.3-4.9-10.11-12 (R. 8)','The Lord is compassion and love, slow to anger and rich in mercy.','John 13:34','I give you a new commandment: love one another just as I have loved you, says the Lord.'),
        ('25','Psalm 145:2-3.8-9.17-18 (R. 18a)','The Lord is close to all who call him.','cf. Acts 16:14b','Open our heart, O Lord, to accept the words of your Son.'),
        ('26','Psalm 25:4-5.6-7.8-9 (R. 6a)','Remember your mercy, Lord.','John 10:27','The sheep that belong to me listen to my voice, says the Lord, I know them and they follow me.'),
        ('27','Psalm 80:9.12.13-14.15-16.19-20 (R. Isaiah 5:7a)','The vineyard of the Lord is the House of Israel.','cf. John 15:16','I chose you from the world to go out and bear fruit, fruit that will last, says the Lord.'),
        ('28','Psalm 23:1-3a.3b-4.5.6 (R. 6cd)','In the Lord\'s own house shall I dwell for ever and ever.','cf. Ephesians 1:17-18','May the Father of our Lord Jesus Christ enlighten the eyes of our mind, so that we can see what hope his call holds for us.'),
        ('29','Psalm 96:1.3.4-5.7-8.9-10 (R. 7b)','Give the Lord glory and power.','Philippians 2:15-16','You will shine in the world like bright stars because you are offering it the word of life.'),
        ('30','Psalm 18:2-3.3-4.47.51 (R. 2)','I love you, Lord, my strength.','John 14:23','If anyone loves me he will keep my word, and my Father will love him, and we shall come to him.'),
        ('31','Psalm 131:1.2.3 (R. 1)','Keep my soul in peace before you, O Lord.','Matthew 23:9b.10b','You have only one Father, and he is in heaven; you have only one Teacher, the Christ.'),
        ('32','Psalm 63:2.3-4.5-6.7-8 (R. 2b)','For you my soul is thirsting, O God, my God.','Matthew 25:13','Stay awake and stand ready, because you do not know the hour when the Son of Man is coming.'),
        ('33','Psalm 128:1-2.3.4-5 (R. cf. 1a)','O blessed are those who fear the Lord.','John 15:4a.5b','Make your home in me, as I make mine in you. Whoever remains in me bears fruit in plenty.'),
        ('34','Psalm 23:1-2.2-3.5-6 (R. 1)','The Lord is my shepherd; there is nothing I shall want.','Mark 11:10','Blessed is he who comes in the name of the Lord! Blessed is the kingdom of our father David that is coming!'),
    ]
    for wk, ps, ref, ar, at in ot_a:
        add('Ordinary Time', wk, 'A', ps, ref, ar, at)

    # ==== ORDINARY TIME - CYCLE B (Weeks 2-34) ====
    ot_b = [
        ('2','Psalm 40:2.4.7-8.8-9.10 (R. 8a.9a)','Here I am, Lord! I come to do your will.','John 1:41.17b','We have found the Messiah - which means the Christ - grace and truth have come through him.'),
        ('3','Psalm 25:4-5.6-7.8-9 (R. 4a)','Lord, make me know your ways.','Mark 1:15','The kingdom of God is close at hand: repent, and believe the Good News.'),
        ('4','Psalm 95:1-2.6-7.7-9 (R. 8)','O that today you would listen to his voice! Harden not your hearts.','Matthew 4:16','A people that walked in darkness has seen a great light; on those who dwell in the land of gloom a light has shone.'),
        ('5','Psalm 147:1-2.3-4.5-6 (R. cf. 3a)','Praise the Lord who heals the broken-hearted.','Matthew 8:17','He took our sicknesses away, and carried our diseases for us.'),
        ('6','Psalm 32:1-2.5.11 (R. 7)','You are my hiding place, O Lord; you surround me with cries of deliverance.','Luke 7:16','A great prophet has appeared among us; God has visited his people.'),
        ('7','Psalm 41:2-3.4-5.13-14 (R. cf. 5)','Heal my soul for I have sinned against you.','2 Corinthians 5:19','God in Christ was reconciling the world to himself, and he has entrusted to us the news that they are reconciled.'),
        ('8','Psalm 103:1-2.3-4.8.10.12-13 (R. 8a)','The Lord is compassion and love.','cf. 2 Timothy 1:10','Our Saviour Jesus Christ abolished death, and he has proclaimed life through the Good News.'),
        ('9','Psalm 81:3-4.5-6.6-8.10-11 (R. 2a)','Ring out your joy to God our strength!','cf. James 1:18','By his own choice the Father made us his children by the message of the truth, so that we should be a sort of first-fruits of all that he created.'),
        ('10','Psalm 130:1-2.3-4.5-6.7-8 (R. 7)','With the Lord there is mercy and fullness of redemption.','John 12:31b-32','Now the prince of this world is to be overthrown, says the Lord. And when I am lifted up from the earth, I shall draw all men to myself.'),
        ('11','Psalm 92:2-3.13-14.15-16 (R. cf. 2a)','It is good to give you thanks, O Lord.','','The seed is the word of God, Christ the sower; all who come to him will have life for ever.'),
        ('12','Psalm 107:23-24.25-26.28-29.30-31 (R. 1)','O give thanks to the Lord, for his love endures for ever.','Luke 7:16','A great prophet has appeared among us; God has visited his people.'),
        ('13','Psalm 30:2.4.5-6.11-12.13 (R. 2a)','I will praise you, Lord, you have rescued me.','cf. 2 Timothy 1:10','Our Saviour Jesus Christ abolished death, and he has proclaimed life through the Good News.'),
        ('14','Psalm 123:1-2.2.3-4 (R. 2cd)','Our eyes are on the Lord till he shows us his mercy.','cf. Ezekiel 2:2','The Spirit of the Lord rests on me; he has sent me to bring good news to the poor.'),
        ('15','Psalm 85:9-10.11-12.13-14 (R. 8)','Let us see, O Lord, your mercy and give us your saving help.','cf. Ephesians 1:17-18','May the Father of our Lord Jesus Christ enlighten the eyes of our mind, so that we can see what hope his call holds for us.'),
        ('16','Psalm 23:1-3.3-4.5.6 (R. 1)','The Lord is my shepherd; there is nothing I shall want.','John 10:27','The sheep that belong to me listen to my voice, says the Lord, I know them and they follow me.'),
        ('17','Psalm 145:10-11.15-16.17-18 (R. 16)','You open wide your hand, O Lord, you grant our desires.','cf. Ephesians 1:17-18','May the Father of our Lord Jesus Christ enlighten the eyes of our mind, so that we can see what hope his call holds for us.'),
        ('18','Psalm 78:3-4.23-24.25.54 (R. 24b)','The Lord gave them bread from heaven.','cf. Matthew 4:4b','Man does not live on bread alone, but on every word that comes from the mouth of God.'),
        ('19','Psalm 34:2-3.4-5.6-7.8-9 (R. 9a)','Taste and see that the Lord is good.','John 6:51','I am the living bread which has come down from heaven, says the Lord. Anyone who eats this bread will live for ever.'),
        ('20','Psalm 34:2-3.10-11.12-13.14-15 (R. 9a)','Taste and see that the Lord is good.','John 6:56','He who eats my flesh and drinks my blood lives in me and I live in him, says the Lord.'),
        ('21','Psalm 34:2-3.16-17.20-21.22-23 (R. 9a)','Taste and see that the Lord is good.','John 6:63c.68c','Your words are spirit, Lord, and they are life; you have the message of eternal life.'),
        ('22','Psalm 15:2-3.3-4.4-5 (R. 1a)','The just will live in the presence of the Lord.','cf. James 1:18','By his own choice the Father made us his children by the message of the truth, so that we should be a sort of first-fruits of all that he created.'),
        ('23','Psalm 146:6-7.8-9.9-10 (R. 1b)','My soul, give praise to the Lord.','cf. Matthew 4:23','Jesus proclaimed the Good News of the kingdom and cured all kinds of sickness among the people.'),
        ('24','Psalm 116:1-2.3-4.5-6.8-9 (R. 9)','I will walk in the presence of the Lord in the land of the living.','Galatians 6:14','The only thing I can boast about is the cross of our Lord Jesus Christ, through whom the world is crucified to me, and I to the world.'),
        ('25','Psalm 54:3-4.5.6.8 (R. 6b)','The Lord upholds my life.','cf. 2 Thessalonians 2:14','Through the Good News God called us to share the glory of our Lord Jesus Christ.'),
        ('26','Psalm 19:8.10.12-13.14 (R. 9a)','The precepts of the Lord gladden the heart.','cf. John 17:17b.a','Your word is truth, O Lord; consecrate us in the truth.'),
        ('27','Psalm 128:1-2.3.4-5.6 (R. cf. 5)','May the Lord bless us all the days of our life.','1 John 4:12','As long as we love one another God will live in us and his love will be complete in us.'),
        ('28','Psalm 90:12-13.14-15.16-17 (R. 14)','Fill us with your love, O Lord, and we will sing for joy!','Matthew 5:3','Happy the poor in spirit; theirs is the kingdom of heaven.'),
        ('29','Psalm 33:4-5.18-19.20.22 (R. 22)','May your love be upon us, O Lord, as we place all our hope in you.','Mark 10:45','The Son of Man came to serve, and to give his life as a ransom for many.'),
        ('30','Psalm 126:1-2.2-3.4-5.6 (R. 3)','What marvels the Lord worked for us! Indeed we were glad.','cf. 2 Timothy 1:10','Our Saviour Jesus Christ abolished death, and he has proclaimed life through the Good News.'),
        ('31','Psalm 18:2-3.3-4.47.51 (R. 2)','I love you, Lord, my strength.','Mark 12:29b-31a','The first commandment is this: you must love the Lord your God with all your heart; the second is this: you must love your neighbour as yourself.'),
        ('32','Psalm 146:6-7.8-9.9-10 (R. 1b)','My soul, give praise to the Lord.','Matthew 5:3','Happy the poor in spirit; theirs is the kingdom of heaven.'),
        ('33','Psalm 16:5.8.9-10.11 (R. 1)','Preserve me, God, I take refuge in you.','Luke 21:36','Stay awake, praying at all times for the strength to stand with confidence before the Son of Man.'),
        ('34','Psalm 93:1.1-2.5 (R. 1a)','The Lord is king, with majesty enrobed.','Mark 11:10','Blessed is he who comes in the name of the Lord! Blessed is the kingdom of our father David that is coming!'),
    ]
    for wk, ps, ref, ar, at in ot_b:
        add('Ordinary Time', wk, 'B', ps, ref, ar, at)

    # ==== ORDINARY TIME - CYCLE C (Weeks 2-34) ====
    ot_c = [
        ('2','Psalm 96:1-2.2-3.7-8.9-10 (R. 3)','Proclaim the wonders of the Lord among all the peoples.','cf. 2 Thessalonians 2:14','Through the Good News God called us to share the glory of our Lord Jesus Christ.'),
        ('3','Psalm 19:8.9.10.15 (R. cf. John 6:63c)','Your words are spirit, Lord, and they are life.','cf. Luke 4:18','The Lord has sent me to bring the good news to the poor, to proclaim liberty to captives.'),
        ('4','Psalm 71:1-2.3-4.5-6.15-17 (R. 15a)','My lips will tell of your help.','cf. Luke 4:18','The Lord has sent me to bring the good news to the poor, to proclaim liberty to captives.'),
        ('5','Psalm 138:1-2.2-3.4-5.7-8 (R. 1c)','Before the angels I will bless you, O Lord.','Matthew 4:19','Come, follow me, says the Lord, and I will make you into fishers of men.'),
        ('6','Psalm 1:1-2.3.4.6 (R. 40:5a)','Happy the man who has placed his trust in the Lord.','Luke 6:23ab','Rejoice and be glad: your reward will be great in heaven.'),
        ('7','Psalm 103:1-2.3-4.8.10.12-13 (R. 8a)','The Lord is compassion and love.','John 13:34','I give you a new commandment: love one another just as I have loved you, says the Lord.'),
        ('8','Psalm 92:2-3.13-14.15-16 (R. cf. 2a)','It is good to give you thanks, O Lord.','Philippians 3:8-9','I count all things as loss compared with gaining Christ, so as to be found in him.'),
        ('9','Psalm 117:1.2 (R. cf. Mark 16:15)','Go out to the whole world; proclaim the Good News.','John 3:16','God loved the world so much that he gave his only Son; everyone who believes in him has eternal life.'),
        ('10','Psalm 30:2.4.5-6.11-12.13 (R. 2a)','I will praise you, Lord, you have rescued me.','Luke 7:16','A great prophet has appeared among us; God has visited his people.'),
        ('11','Psalm 32:1-2.5.7.11 (R. cf. 7)','You are my hiding place, O Lord; you fill me with the joy of salvation.','1 John 4:10b','God loved us and sent his Son to be the sacrifice that takes our sins away.'),
        ('12','Psalm 63:2.3-4.5-6.8-9 (R. 2b)','For you my soul is thirsting, O God, my God.','Matthew 8:17','He took our sicknesses away, and carried our diseases for us.'),
        ('13','Psalm 16:1-2.5.7-8.9-10.11 (R. cf. 5a)','O Lord, it is you who are my portion.','1 Samuel 3:9; John 6:68c','Speak, Lord, your servant is listening: you have the message of eternal life.'),
        ('14','Psalm 66:1-3.4-5.6-7.16.20 (R. 1)','Cry out with joy to God all the earth.','cf. Colossians 3:15a.16a','May the peace of Christ reign in your hearts; let the message of Christ find a home in you.'),
        ('15','Psalm 69:14.17.30-31.33-34.36-37 (R. cf. 33)','Seek the Lord, you who are poor, and your hearts will revive.','cf. John 6:63c.68c','Your words are spirit, Lord, and they are life; you have the message of eternal life.'),
        ('16','Psalm 15:2-3.3-4.5 (R. 1a)','The just will live in the presence of the Lord.','cf. Luke 8:15','Happy are they who have kept the word with a generous heart, and yield a harvest through perseverance.'),
        ('17','Psalm 138:1-2.2-3.6-7.7-8 (R. 3a)','On the day I called, you answered me, O Lord.','Romans 8:15bc','You received the Spirit which makes us God\'s children, and in that Spirit we call God our Father.'),
        ('18','Psalm 90:3-4.5-6.12-13.14.17 (R. 1)','O Lord, you have been our refuge from one generation to the next.','Matthew 5:3','Happy the poor in spirit; theirs is the kingdom of heaven.'),
        ('19','Psalm 33:1.12.18-19.20.22 (R. 12b)','Happy the people the Lord has chosen as his own.','Matthew 24:42.44','Stand ready, because the Son of Man is coming at an hour you do not expect.'),
        ('20','Psalm 40:2.3.4.18 (R. 14b)','Lord, come to my help!','Hebrews 12:2','With our eyes fixed on Jesus, who leads us in our faith and brings it to perfection, let us bear our sufferings with perseverance.'),
        ('21','Psalm 117:1.2 (R. cf. Mark 16:15)','Go out to the whole world; proclaim the Good News.','John 14:6','I am the Way, the Truth and the Life, says the Lord; no one can come to the Father except through me.'),
        ('22','Psalm 68:4-5.6-7.10-11 (R. cf. 11b)','In your goodness, O God, you prepared a home for the poor.','Matthew 11:29ab','Shoulder my yoke and learn from me, for I am gentle and humble in heart.'),
        ('23','Psalm 90:3-4.5-6.12-13.14.17 (R. 1)','O Lord, you have been our refuge from one generation to the next.','Psalm 119:135','Let your face shine on your servant, and teach me your decrees.'),
        ('24','Psalm 51:3-4.12-13.17.19 (R. Luke 15:18)','I will leave this place and go to my father.','2 Corinthians 5:19','God in Christ was reconciling the world to himself, and he has entrusted to us the news that they are reconciled.'),
        ('25','Psalm 113:1-2.4-6.7-8 (R. cf. 1a.7b)','Praise the Lord, who raises the poor.','2 Corinthians 8:9','Jesus Christ was rich, but he became poor for your sake, to make you rich out of his poverty.'),
        ('26','Psalm 146:6-7.8-9.9-10 (R. 1b)','My soul, give praise to the Lord.','2 Corinthians 8:9','Jesus Christ was rich, but he became poor for your sake, to make you rich out of his poverty.'),
        ('27','Psalm 95:1-2.6-7.8-9 (R. 8)','O that today you would listen to his voice! Harden not your hearts.','2 Timothy 1:10','Our Saviour Jesus Christ abolished death, and he has proclaimed life through the Good News.'),
        ('28','Psalm 98:1.2-3.3-4 (R. cf. 2b)','The Lord has shown his salvation to the nations.','1 Thessalonians 5:18','For all things give thanks to God, because this is what God expects of you in Christ Jesus.'),
        ('29','Psalm 121:1-2.3-4.5-6.7-8 (R. cf. 2)','Our help is in the name of the Lord who made heaven and earth.','Hebrews 4:12','The word of God is something alive and active; it can judge the secret emotions and thoughts.'),
        ('30','Psalm 34:2-3.17-18.19.23 (R. 7a)','This poor man called; the Lord heard him.','2 Corinthians 5:19','God in Christ was reconciling the world to himself, and he has entrusted to us the news that they are reconciled.'),
        ('31','Psalm 145:1-2.8-9.10-11.13-14 (R. cf. 1)','I will bless your name for ever, O God my King.','John 3:16','God loved the world so much that he gave his only Son; everyone who believes in him has eternal life.'),
        ('32','Psalm 17:1.5-6.8.15 (R. 15b)','I shall be filled, when I awake, with the sight of your glory, O Lord.','Apocalypse 1:5-6','Jesus Christ is the firstborn of the dead; glory and kingship be his for ever and ever.'),
        ('33','Psalm 98:5-6.7-8.9 (R. cf. 9)','The Lord comes to rule the peoples with fairness.','Luke 21:28','Stand erect, hold your heads high, because your liberation is near at hand.'),
        ('34','Psalm 122:1-2.3-4.4-5 (R. cf. 1)','I rejoiced when I heard them say: Let us go to God\'s house.','Mark 11:10','Blessed is he who comes in the name of the Lord! Blessed is the kingdom of our father David that is coming!'),
    ]
    for wk, ps, ref, ar, at in ot_c:
        add('Ordinary Time', wk, 'C', ps, ref, ar, at)

    return sundays


def write_csv(entries, output_path):
    """Write entries to CSV."""
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


def find_discrepancies(entries):
    """Flag potential issues for manual review."""
    discrepancies = []
    for e in entries:
        issues = []
        if not e['psalm_reference']: issues.append('MISSING_PSALM_REF')
        if not e['response_text']: issues.append('MISSING_RESPONSE')
        if not e['acclamation_text'] and not e['acclamation_ref']: issues.append('MISSING_ACCLAMATION')
        if e['psalm_reference'] and not re.search(r'\d+[.\-:,]', e['psalm_reference']): issues.append('SUSPICIOUS_PSALM_REF')
        if e['response_text'] and len(e['response_text']) < 10: issues.append('SHORT_RESPONSE')
        if e['response_text'] and len(e['response_text']) > 150: issues.append('LONG_RESPONSE')
        if e['acclamation_text'] and len(e['acclamation_text']) > 200: issues.append('LONG_ACCLAMATION')
        if not e['season']: issues.append('MISSING_SEASON')
        if not e['day']: issues.append('MISSING_DAY')
        if e['season'] == 'Ordinary Time' and not e['weekday_cycle'] and not e['sunday_cycle']:
            issues.append('MISSING_CYCLE_FOR_OT')
        if issues:
            d = dict(e)
            d['issues'] = '; '.join(issues)
            discrepancies.append(d)
    return discrepancies


def main():
    base_dir = r'c:\dev\catholicdaily-flutter'
    scripts_dir = os.path.join(base_dir, 'scripts')

    # 1. Extract weekday data
    print("=== Extracting weekday data from PDF A ===")
    entries_a = extract_entries_v2(os.path.join(scripts_dir, 'weekday_a_full.txt'))
    print(f"  Extracted {len(entries_a)} raw entries")

    print("=== Extracting weekday data from PDF B ===")
    entries_b = extract_entries_v2(os.path.join(scripts_dir, 'weekday_b_full.txt'))
    print(f"  Extracted {len(entries_b)} raw entries")

    # 2. Build Sunday data
    print("=== Building Sunday data ===")
    sunday = build_sunday_data()
    print(f"  Built {len(sunday)} Sunday entries")

    # 3. Combine weekday, deduplicate seasonal
    all_weekday = []
    seen = set()
    for e in entries_a + entries_b:
        if e['weekday_cycle'] == 'I/II':
            key = (e['season'], e['week'], e['day'], e['psalm_reference'])
            if key not in seen:
                seen.add(key)
                all_weekday.append(e)
        else:
            all_weekday.append(e)

    all_weekday = deduplicate_ot_entries(all_weekday)
    print(f"  Combined weekday (deduplicated): {len(all_weekday)}")

    # 4. Merge
    all_entries = all_weekday + sunday

    # Sort
    season_order = {'Advent':0,'Christmas':1,'Ordinary Time':2,'Lent':3,'Holy Week':4,'Easter':5}
    day_order = {'Sunday':0,'Monday':1,'Tuesday':2,'Wednesday':3,'Thursday':4,'Friday':5,'Saturday':6}
    def sort_key(e):
        s = season_order.get(e['season'], 99)
        try: w = int(e['week'])
        except: w = 0
        d = day_order.get(e['day'], 99)
        c = e.get('sunday_cycle','') or e.get('weekday_cycle','')
        return (s, w, d, c)
    all_entries.sort(key=sort_key)

    # 5. Write main CSV
    write_csv(all_entries, os.path.join(base_dir, 'lectionary_psalms.csv'))

    # 6. Discrepancies
    disc = find_discrepancies(all_entries)
    disc_fields = [
        'Season','Week','Day','Weekday Cycle','Sunday Cycle',
        'Full Reference','Refrain Text','Acclamation Ref','Acclamation Text',
        'Lectionary Number','Issues'
    ]
    with open(os.path.join(base_dir, 'discrepancies.csv'), 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=disc_fields)
        writer.writeheader()
        for d in disc:
            writer.writerow({
                'Season': d['season'], 'Week': d['week'], 'Day': d['day'],
                'Weekday Cycle': d['weekday_cycle'], 'Sunday Cycle': d['sunday_cycle'],
                'Full Reference': d['psalm_reference'], 'Refrain Text': d['response_text'],
                'Acclamation Ref': d['acclamation_ref'], 'Acclamation Text': d['acclamation_text'],
                'Lectionary Number': d.get('lectionary_number',''), 'Issues': d['issues'],
            })
    print(f"Wrote {len(disc)} discrepancies to discrepancies.csv")

    # Summary
    print(f"\n=== FINAL SUMMARY ===")
    print(f"Total entries: {len(all_entries)}")
    from collections import Counter
    for label, counter in [
        ("By Season", Counter(e['season'] for e in all_entries)),
        ("By Weekday Cycle", Counter(e['weekday_cycle'] for e in all_entries if e['weekday_cycle'])),
        ("By Sunday Cycle", Counter(e['sunday_cycle'] for e in all_entries if e['sunday_cycle'])),
    ]:
        print(f"\n{label}:")
        for k, v in sorted(counter.items()):
            print(f"  {k}: {v}")


if __name__ == '__main__':
    main()
