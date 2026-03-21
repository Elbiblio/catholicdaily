# Missing Gospel Incipits Research

## Current Issue
Many gospel incipits are missing in `memorial_feasts.csv`, particularly for Marian feasts and other solemnities.

## Examples Found
- **Luke 1:26-38** (Annunciation): Missing incipit
- Other Marian feasts with Luke 1:26-38 also missing incipits

## Research Strategy

### 1. Official Lectionary Sources
- **USCCB Lectionary**: https://bible.usccb.org/
- **Roman Missal**: Official liturgical texts
- **Local Diocesan Resources**: Often have complete lectionary texts

### 2. Catholic Liturgy Websites
- **EWTN**: https://www.ewtn.com/
- **Catholic Culture**: https://www.catholicculture.org/
- **Universalis**: https://www.universalis.com/

### 3. Expected Incipit Patterns

Based on lectionary standards, gospel incipits typically follow these patterns:

#### Marian Feasts (Luke 1:26-38)
- **Expected**: "At that time: The Angel Gabriel was sent from God to a town in Galilee called Nazareth..."

#### Christological Events
- **Pattern**: "At that time: [narrative introduction]..."
- **Examples**: "At that time: Jesus was teaching...", "At that time: The disciples came to Jesus..."

#### Apostolic Events
- **Pattern**: "At that time: [apostolic action]..."
- **Examples**: "At that time: Jesus called the Twelve...", "At that time: The disciples were gathered..."

#### Parables and Teachings
- **Pattern**: "At that time: Jesus said to his disciples...", "At that time: Jesus told his disciples..."

### 4. Specific Missing Incipits to Research

#### High Priority (Luke 1:26-38 occurrences):
1. **Queenship of Blessed Virgin Mary** (Aug 22)
2. **Our Lady of the Rosary** (Oct 7) 
3. **Our Lady of Loreto** (Dec 10)
4. **Our Lady of Guadalupe** (Dec 12)

#### Other Common Missing Incipits:
1. **Baptism of the Lord**: "At that time: Jesus came from Galilee..."
2. **Transfiguration**: "At that time: Jesus took Peter, James, and John..."
3. **Good Shepherd**: "At that time: Jesus said: 'I am the good shepherd...'"

### 5. Implementation Plan

#### Phase 1: Research Core Incipits
- Focus on the most frequently used gospel readings
- Check multiple sources for consistency
- Verify exact wording with official lectionary when possible

#### Phase 2: Systematic Addition
- Add incipits to `memorial_feasts.csv` for:
  - All Luke 1:26-38 occurrences
  - Common feast day gospels
  - Frequently used readings

#### Phase 3: Quality Assurance
- Cross-reference with existing incipits in `standard_lectionary_complete.csv`
- Ensure consistency in formatting and capitalization
- Test with the IncipitProcessingService

### 6. Research Resources to Check

#### Primary Sources:
1. **Lectionary for Mass: United States** (USCCB)
2. **Roman Missal, Third Edition**
3. **Local Diocesan Worship Offices**

#### Secondary Sources:
1. **EWTN Library**: https://www.ewtn.com/library/
2. **Catholic Liturgy**: Various parish websites
3. **Monastic Communities**: Often have complete liturgical texts

### 7. Immediate Action Items

1. **Contact Local Parish**: Many parishes have complete lectionary texts
2. **Check Catholic Bookstore**: May have lectionary with incipits
3. **Diocesan Worship Office**: Official source for liturgical texts
4. **Online Catholic Communities**: Facebook groups, forums

## Next Steps

1. **Create Research Template**: Standardize format for recording incipits
2. **Prioritize High-Impact Feasts**: Focus on most commonly celebrated
3. **Verify Each Incipit**: Cross-check multiple sources
4. **Implement Incrementally**: Add in batches to test functionality

## Expected Outcome

Complete gospel incipit coverage for all memorial feasts, with proper formatting:
- "At that time: [proper incipit text]"
- Consistent with lectionary standards
- Compatible with IncipitProcessingService
