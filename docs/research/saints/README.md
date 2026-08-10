# Saint profile research protocol

Every researched profile is an original Catholic Daily synthesis backed by a
reviewable dossier. A profile is not publishable merely because its JSON parses.
It must pass identity, evidence, copyright, factual, theological, and automated
validation gates.

## Binding rules

1. Read at least three credible sources when three exist. For modern canonized
   saints and documented celebrations, include at least one official or primary
   source.
2. Prefer Holy See documents, canonization material, bishops' conferences,
   primary writings, liturgical documents, and official diocesan or religious
   community archives. Use scholarly references for historical control.
3. Wikidata and Wikipedia are discovery and cross-check sources only. They may
   not be the sole authority for a material claim.
4. Record the exact URL, access date, tier, institution, reuse basis, and claims
   supported by every source.
5. Resolve conflicts by proximity, date, genre, and scholarly reliability, and
   record rejected or unresolved versions in the dossier.
6. Classify claims as documented, reliably traditional, legendary, disputed, or
   mixed. Never present tradition silently as established history.
7. Include a quotation only when its exact wording, attribution, edition or
   translation, and source can be verified.
8. Write biography, reflection, practices, and prayer in original prose. Do not
   copy or closely paraphrase a copyrighted biography or Vatican News article.
9. Include an image only when its creator, source page, license, credit line, and
   derivative status are all verified. Text-only profiles are acceptable.
10. Make every Gospel insight, virtue, practice, question, and prayer specific
    to the documented subject. Rewrite content that could be transferred to a
    different saint by changing only the name.
11. Describe enslavement, abuse, persecution, illness, and martyrdom accurately,
    without graphic detail or sensational language.
12. Preserve correct Unicode and diacritics. Omit facts that are not established
    by the reviewed sources.
13. Record separate factual/content and theological review passes. Only then may
    editorial state become `published` with a positive revision and no warnings.

## Required dossier

Each `dossiers/<profile-id>.md` contains substantive content under every heading:

```markdown
# <Canonical profile name>

## Identity resolution
- Stable ID:
- Profile kind:
- Celebration IDs:
- Canonical name and aliases:
- Feast date and calendar scope:
- Identity conflicts resolved:

## Source ledger
| ID | Tier | Author/institution | Title | Publisher | URL | Accessed | Reuse basis |
|---|---:|---|---|---|---|---|---|

## Claim ledger
| Profile field | Claim or editorial conclusion | Source IDs | Certainty | Reconciliation note |
|---|---|---|---|---|

## Copyright and media decision

## Content review

## Theological review

## Final validation
```

If reviewed sources do not establish a requested fact, the dossier says
"Not established by the reviewed sources; omitted from the profile" and the
unsupported field is omitted from JSON.

## Commands

```powershell
dart run tool/saint_research_queue.dart
dart run tool/saint_research_queue.dart --ids josephine_bakhita,hildegard_of_bingen
dart run tool/saint_research_queue.dart --batch 1
dart run tool/validate_saint_profiles.dart
```
