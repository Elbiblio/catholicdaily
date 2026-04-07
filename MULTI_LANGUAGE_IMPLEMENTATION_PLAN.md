# Multi-Language Order of Mass Implementation Plan

## Executive Summary

This plan outlines the comprehensive strategy for adding multi-language support to the Catholic Daily Missal app's Order of Mass feature, while maintaining English and Latin as the only options for general app language.

## Current State

**App Language Support:**
- General Language: English (en), Latin (la) only
- Order of Mass Language: English (en), Latin (la) only

**Current Architecture:**
- `LanguagePreferenceService`: Handles general app language (en/la only)
- `OrderOfMassPreferenceService`: Handles Order of Mass language (currently en/la)
- Prayer HTML files: Contain English + Latin embedded
- `order_of_mass.json`: Config with language codes in `availableLanguages` array
- `order_of_mass_service.dart`: Resolves content by language

## Official Translation Sources

### Phase 1 Languages (High Priority)

#### 1. Spanish (es)
**Official Source:** Misal Romano, Tercera Edición
**Authority:** 
- USCCB (United States Conference of Catholic Bishops) - 2018
- Conferencia del Episcopado Mexicano - 2014
- Various Latin American episcopal conferences
**Vatican Recognition:** Confirmed by Apostolic See (recognitio)
**Base Text:** Misal Romano (Spanish translation of Missale Romanum, Editio Typica Tertia)
**Notes:** 
- US has its own specific edition approved by USCCB
- Mexico has its own edition (CEM)
- Most Spanish-speaking countries use variations based on these base texts
- Recommendation: Use USCCB Misal Romano as base for broad compatibility

#### 2. Portuguese (pt)
**Official Source:** Missal Romano, 3ª Edição Típica
**Authority:** 
- CNBB (Conferência Nacional dos Bispos do Brasil) - 2022
**Vatican Recognition:** Submitted to Congregation for Divine Worship (CDW) for recognitio
**Base Text:** Brazilian translation of Missale Romanum, Editio Typica Tertia
**Notes:**
- Brazil has the largest Catholic population worldwide
- CNBB spent 18+ years on this translation
- Official launch: September 19, 2022
- Mandatory use from First Sunday of Advent 2023

#### 3. French (fr)
**Official Source:** Missel Romain, nouvelle traduction
**Authority:** 
- AELF (Association Épiscopale Liturgique Francophone)
**Vatican Recognition:** Approved by CDW
**Base Text:** French translation of Missale Romanum, Editio Typica Tertia
**Notes:**
- Used in France, DRC, and Francophone Africa
- New translation approved around 2019
- Key changes: "consubstantiel au Père" instead of "de même nature"
- Covers all Francophone Catholic regions

#### 4. Tagalog/Filipino (tl)
**Official Source:** Roman Missal in Tagalog
**Authority:** 
- CBCP (Catholic Bishops' Conference of the Philippines)
**Vatican Recognition:** Approved by CDW
**Base Text:** Tagalog translation of Missale Romanum
**Notes:**
- Philippines has 3rd largest Catholic population
- Note: Some online sources show auto-translated content
- Must verify with official CBCP publication
- May also need Cebuano and other Philippine languages for full coverage

### Phase 2 Languages (Medium Priority)

#### 5. Italian (it)
**Official Source:** Messale Romano
**Authority:** 
- CEI (Conferenza Episcopale Italiana)
**Vatican Recognition:** Confirmed by Pope Francis, 2020
**Base Text:** Italian translation of Missale Romanum, Editio Typica Tertia
**Notes:**
- Mandatory from Easter 2021
- Notable changes to Pater Noster and Gloria
- Historical significance as center of Catholic Church

#### 6. Polish (pl)
**Official Source:** Mszał Rzymski
**Authority:** 
- Konferencja Episkopatu Polski (Polish Episcopal Conference)
**Vatican Recognition:** Approved
**Base Text:** Polish translation of Missale Romanum
**Notes:**
- Poland has one of highest Catholic percentages (85-90%)
- Strong Catholic identity
- "Mszał rzymski dla diecezji polskich" is the official edition

#### 7. Vietnamese (vi)
**Official Source:** Sách Lễ Roma
**Authority:** 
- CBCV (Catholic Bishops' Conference of Vietnam)
**Vatican Recognition:** Approved
**Base Text:** Vietnamese translation of Missale Romanum
**Notes:**
- Significant Catholic population (~7 million)
- Growing Catholic community
- Need to verify official CBCV translation

#### 8. Korean (ko)
**Official Source:** 미사 전례서 (Roman Missal in Korean)
**Authority:** 
- CBCK (Catholic Bishops' Conference of Korea)
**Vatican Recognition:** Approved by CDW (October 2016)
**Base Text:** Korean translation of Missale Romanum, Editio Typica Tertia
**Notes:**
- Growing Catholic population (~5.5 million)
- CBCK decided to publish new version in 2016
- Active Catholic community in South Korea

## Architecture Design

### Language Settings Separation

The app will maintain TWO separate language settings:

#### 1. General Language (UI Language)
**Purpose:** App interface, navigation, labels, general content
**Options:** English (en), Latin (la) only
**Service:** `LanguagePreferenceService` (existing)
**Scope:** 
- App UI labels
- Navigation
- Settings screens
- General app text
- Reading content (Bible readings, etc.)

#### 2. Order of Mass Language
**Purpose:** Liturgical texts, prayers, Order of Mass content
**Options:** English (en), Latin (la), Spanish (es), Portuguese (pt), French (fr), Tagalog (tl), Italian (it), Polish (pl), Vietnamese (vi), Korean (ko)
**Service:** `OrderOfMassPreferenceService` (expand existing)
**Scope:**
- Order of Mass prayers
- Liturgical responses
- Mass-related prayers
- Any content in `order_of_mass.json`

### Data Structure Changes

#### 1. Language Preference Service (No Changes Needed)
Keep `LanguagePreferenceService` as-is with only en/la options.

#### 2. Order of Mass Preference Service (Expansion)

**Current:**
```dart
static const String _preferredLanguageKey = 'preferred_order_of_mass_language';
static const String _defaultLanguage = 'en';
```

**Expanded:**
```dart
static const String _preferredLanguageKey = 'preferred_order_of_mass_language';
static const String _defaultLanguage = 'en';

// Language codes
static const String english = 'en';
static const String latin = 'la';
static const String spanish = 'es';
static const String portuguese = 'pt';
static const String french = 'fr';
static const String tagalog = 'tl';
static const String italian = 'it';
static const String polish = 'pl';
static const String vietnamese = 'vi';
static const String korean = 'ko';

// Display names
static const Map<String, String> _languageNames = {
  english: 'English',
  latin: 'Latin',
  spanish: 'Español',
  portuguese: 'Português',
  french: 'Français',
  tagalog: 'Tagalog',
  italian: 'Italiano',
  polish: 'Polski',
  vietnamese: 'Tiếng Việt',
  korean: '한국어',
};

List<String> get availableLanguages => [
  english, latin, spanish, portuguese, french, tagalog,
  italian, polish, vietnamese, korean
];

String getLanguageDisplayName(String languageCode) {
  return _languageNames[languageCode] ?? languageCode;
}
```

#### 3. Order of Mass JSON Structure

**Current structure (already supports multiple languages):**
```json
{
  "id": "sign_of_the_cross",
  "title": "Sign of the Cross",
  "insertionPoint": "before_readings",
  "order": 1,
  "prayerSlug": "sign_of_the_cross",
  "availableLanguages": ["en", "la"],
  "conditions": ["always"],
  "isOptional": false
}
```

**Updated structure (add new language codes):**
```json
{
  "id": "sign_of_the_cross",
  "title": "Sign of the Cross",
  "insertionPoint": "before_readings",
  "order": 1,
  "prayerSlug": "sign_of_the_cross",
  "availableLanguages": ["en", "la", "es", "pt", "fr", "tl", "it", "pl", "vi", "ko"],
  "conditions": ["always"],
  "isOptional": false
}
```

#### 4. Prayer HTML Structure Refactoring

**Current structure (embedded languages):**
```html
<HTML>
<BODY>
Hail, Mary, full of grace.
<br>The Lord is with you.
...
<br><b>In Latin
<br></b>Ave Maria, gratia plena,
...
</BODY>
</HTML>
```

**Recommended new structure (separate files):**
```
assets/prayers/
├── hail_mary_en.html
├── hail_mary_la.html
├── hail_mary_es.html
├── hail_mary_pt.html
├── hail_mary_fr.html
├── hail_mary_tl.html
├── hail_mary_it.html
├── hail_mary_pl.html
├── hail_mary_vi.html
└── hail_mary_ko.html
```

**Alternative structure (language folders):**
```
assets/prayers/
├── en/
│   ├── hail_mary.html
│   ├── pater_noster.html
│   └── ...
├── la/
│   ├── hail_mary.html
│   ├── pater_noster.html
│   └── ...
├── es/
│   ├── hail_mary.html
│   ├── pater_noster.html
│   └── ...
└── ...
```

**Recommendation:** Use language folders structure for better organization and scalability.

#### 5. Prayer Service Updates

Update `PrayerService` to load language-specific files:

```dart
String _getPrayerFilePath(String slug, String language) {
  return 'assets/prayers/$language/$slug.html';
}
```

## Implementation Phases

### Phase 1: Foundation (Week 1-2)

**Objective:** Set up architecture for multi-language Order of Mass

**Tasks:**
1. Expand `OrderOfMassPreferenceService` with all language codes and display names
2. Update language switcher widget to handle Order of Mass language separately
3. Create language folder structure in assets/prayers/
4. Update `PrayerService` to load language-specific files
5. Add migration logic to convert existing embedded HTML to separate files
6. Update `order_of_mass.json` to include all language codes in `availableLanguages`
7. Add language selection UI in settings screen for Order of Mass language

**Deliverables:**
- Updated `OrderOfMassPreferenceService`
- New prayer file structure
- Updated `PrayerService`
- Settings UI for Order of Mass language selection
- Migration script for existing prayers

### Phase 2: Spanish & Portuguese (Week 3-4)

**Objective:** Add Spanish and Portuguese Order of Mass content

**Tasks:**
1. Obtain official Spanish translation texts (Misal Romano)
2. Obtain official Portuguese translation texts (Missal Romano CNBB)
3. Translate/create HTML files for all Order of Mass prayers in Spanish
4. Translate/create HTML files for all Order of Mass prayers in Portuguese
5. Update prayer service to load es/pt files
6. Test Order of Mass display in Spanish and Portuguese
7. Verify translations against official sources

**Content Required:**
- Sign of the Cross
- Confiteor
- Creed (Credo)
- Sanctus
- Pater Noster (Our Father)
- Agnus Dei (Lamb of God)
- Dismissal
- Gloria
- Kyrie
- Other Order of Mass items

**Sources:**
- Spanish: USCCB Misal Romano (https://www.usccb.org/prayer-and-worship/the-mass/general-instruction-of-the-roman-missal)
- Portuguese: CNBB Missal Romano (https://www.edicoescnbb.com.br/)

### Phase 3: French & Tagalog (Week 5-6)

**Objective:** Add French and Tagalog Order of Mass content

**Tasks:**
1. Obtain official French translation texts (AELF Missel Romain)
2. Obtain official Tagalog translation texts (CBCP)
3. Translate/create HTML files for all Order of Mass prayers in French
4. Translate/create HTML files for all Order of Mass prayers in Tagalog
5. Update prayer service to load fr/tl files
6. Test Order of Mass display in French and Tagalog
7. Verify translations against official sources

**Sources:**
- French: AELF (https://www.aelf.org/)
- Tagalog: CBCP Philippines (verify official publication)

### Phase 4: Italian & Polish (Week 7-8)

**Objective:** Add Italian and Polish Order of Mass content

**Tasks:**
1. Obtain official Italian translation texts (CEI Messale Romano)
2. Obtain official Polish translation texts (Episkopat Polski)
3. Translate/create HTML files for all Order of Mass prayers in Italian
4. Translate/create HTML files for all Order of Mass prayers in Polish
5. Update prayer service to load it/pl files
6. Test Order of Mass display in Italian and Polish
7. Verify translations against official sources

**Sources:**
- Italian: CEI (https://www.chiesacattolica.it/messale-romano/)
- Polish: Konferencja Episkopatu Polski

### Phase 5: Vietnamese & Korean (Week 9-10)

**Objective:** Add Vietnamese and Korean Order of Mass content

**Tasks:**
1. Obtain official Vietnamese translation texts (CBCV)
2. Obtain official Korean translation texts (CBCK)
3. Translate/create HTML files for all Order of Mass prayers in Vietnamese
4. Translate/create HTML files for all Order of Mass prayers in Korean
5. Update prayer service to load vi/ko files
6. Test Order of Mass display in Vietnamese and Korean
7. Verify translations against official sources

**Sources:**
- Vietnamese: CBCV (verify official publication)
- Korean: CBCK (https://www.cbck.or.kr/)

### Phase 6: Testing & QA (Week 11-12)

**Objective:** Comprehensive testing across all languages

**Tasks:**
1. Test Order of Mass in all 10 languages
2. Test language switching functionality
3. Test settings UI for language selection
4. Verify all translations display correctly
5. Test edge cases (missing translations, fallback logic)
6. Performance testing with multiple language files
7. User acceptance testing with native speakers
8. Fix bugs and issues

### Phase 7: Documentation & Launch (Week 13-14)

**Objective:** Prepare for release

**Tasks:**
1. Update app store descriptions with new language support
2. Create user documentation for language features
3. Update README with language support information
4. Create changelog
5. Prepare marketing materials
6. Submit to app stores
7. Monitor feedback and issues post-launch

## Content Acquisition Strategy

### Official Sources Verification

For each language, verify the official translation by:

1. **Check Vatican CDW recognitio:**
   - Search Vatican website for "recognitio" + language + "Missale Romanum"
   - Verify the translation has Vatican approval

2. **Check Episcopal Conference website:**
   - Find the official bishops' conference for each country/region
   - Look for official missal publications
   - Verify the translation is the current approved version

3. **Cross-reference with multiple sources:**
   - Compare with liturgical publishers (OCP, GIA, etc.)
   - Check Catholic book publishers
   - Verify with diocesan websites

4. **Avoid auto-translated content:**
   - Some online sources (like massineverylanguage.com) use auto-translation
   - Always verify with official episcopal conference publications
   - Cross-check with printed missals when possible

### Content Creation Process

For each language:

1. **Obtain official text:**
   - Purchase official missal or obtain from episcopal conference
   - Scan/OCR if necessary (respecting copyright)
   - Verify text accuracy

2. **Create HTML files:**
   - Follow existing HTML structure
   - Use proper HTML formatting
   - Include appropriate line breaks and formatting

3. **Quality assurance:**
   - Have native speaker review translations
   - Compare with official source
   - Check for typos and formatting issues

4. **Copyright considerations:**
   - Official liturgical translations may have copyright
   - Check with episcopal conference for usage permissions
   - Some translations may be available for non-commercial use
   - Consider fair use for educational/devotional purposes

## Technical Considerations

### File Size Management

Adding 8 new languages with ~100 prayer files each = ~800 new files

**Strategies:**
1. Lazy loading: Only load prayer files when needed
2. Asset bundling: Consider on-demand asset loading
3. Compression: Use efficient file formats
4. Selective inclusion: Allow users to download only needed languages

### Fallback Logic

Implement intelligent fallback:

```dart
String? getContentForLanguage(String languageCode) {
  // Try requested language
  if (contentByLanguage[languageCode] != null) {
    return contentByLanguage[languageCode];
  }
  
  // Fallback to English
  if (contentByLanguage['en'] != null) {
    return contentByLanguage['en'];
  }
  
  // Fallback to Latin
  if (contentByLanguage['la'] != null) {
    return contentByLanguage['la'];
  }
  
  return null;
}
```

### Settings UI Design

Create clear separation in settings:

```
Settings
├── App Language (English, Latin)
└── Order of Mass Language (English, Latin, Spanish, Portuguese, French, Tagalog, Italian, Polish, Vietnamese, Korean)
```

### Testing Strategy

1. **Unit tests:** Test language loading logic
2. **Integration tests:** Test Order of Mass service with different languages
3. **UI tests:** Test language switching in settings
4. **Manual testing:** Native speaker review for each language

## Risk Assessment

### High Risks

1. **Copyright issues with official translations**
   - Mitigation: Check with episcopal conferences for permissions
   - Alternative: Use public domain or creative commons translations where available

2. **Translation accuracy**
   - Mitigation: Verify with official sources
   - Have native speakers review

3. **App size increase**
   - Mitigation: Implement lazy loading
   - Consider optional language downloads

### Medium Risks

1. **Incomplete translations**
   - Mitigation: Implement fallback logic
   - Clearly indicate which prayers are available in which languages

2. **Maintenance burden**
   - Mitigation: Automated testing
   - Clear documentation for future updates

## Success Metrics

1. **Coverage:** All 10 languages supported for Order of Mass
2. **Accuracy:** 100% of translations verified against official sources
3. **Performance:** App startup time < 3 seconds with all languages
4. **User satisfaction:** Positive feedback from native speakers
5. **Adoption:** Track language selection in analytics

## Future Enhancements

1. **Additional languages:**
   - German (Germany, Austria)
   - Swahili (East Africa)
   - Amharic (Ethiopia/Eritrea)
   - Chinese (China, diaspora)

2. **Regional variations:**
   - Different Spanish translations (Mexico, Spain, US)
   - Different French translations (France, DRC, Canada)

3. **Audio support:**
   - Add audio recordings of prayers in each language

4. **Offline support:**
   - Download languages for offline use

## Conclusion

This plan provides a comprehensive roadmap for adding multi-language support to the Order of Mass feature while maintaining English and Latin as the only general app languages. The phased approach allows for manageable implementation with quality verification at each stage.

The key to success is:
1. Using only official Vatican-approved translations
2. Maintaining clear separation between app language and Order of Mass language
3. Implementing robust fallback logic
4. Thorough testing with native speakers
5. Respecting copyright and obtaining necessary permissions

Estimated timeline: 14 weeks for full implementation of all 8 new languages.
