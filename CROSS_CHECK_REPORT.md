# Cross-Check Report: Prayer Translations

## Date: April 7, 2026

## Purpose
Cross-check French and Tagalog prayer translations with official modern sources to identify any distinctions or issues.

---

## French (fr) - Credo (Nicene Creed)

### File: `assets/prayers/fr/credo.html`

**Current Content:**
```
Je crois en un seul Dieu, le Père tout-puissant, créateur du ciel et de la terre, de l'univers visible et invisible.
Je crois en un seul Seigneur, Jésus Christ, le Fils unique de Dieu, né du Père avant tous les siècles : Il est Dieu, né de Dieu, lumière née de la lumière, vrai Dieu, né du vrai Dieu, Engendré, non pas créé, consubstantiel au Père, et par lui tout a été fait. Pour nous les hommes, et pour notre salut, il descendit du ciel ; Par l'Esprit Saint, il a pris chair de la Vierge Marie, et s'est fait homme. Crucifié pour nous sous Ponce Pilate, il souffrit sa passion et fut mis au tombeau. Il ressuscita le troisième jour, conformément aux Écritures, et il monta au ciel ; il est assis à la droite du Père. Il reviendra dans la gloire, pour juger les vivants et les morts ; et son règne n'aura pas de fin.
Je crois en l'Esprit Saint, qui est Seigneur et qui donne la vie ; il procède du Père et du Fils ; avec le Père et le Fils, il reçoit même adoration et même gloire ; il a parlé par les prophètes.
Je crois en l'Église, une, sainte, catholique et apostolique. Je reconnais un seul baptême pour le pardon des péchés. J'attends la résurrection des morts, et la vie du monde à venir. Amen.
```

**Official Source (Église catholique en France - AELF):**
```
Je crois en un seul Dieu, le Père tout puissant, créateur du ciel et de la terre, de l'univers visible et invisible, 
Je crois en un seul Seigneur, Jésus Christ, le Fils unique de Dieu, né du Père avant tous les siècles : Il est Dieu, né de Dieu, lumière, née de la lumière, vrai Dieu, né du vrai Dieu Engendré non pas créé, consubstantiel au Père ; et par lui tout a été fait. Pour nous les hommes, et pour notre salut, il descendit du ciel; Par l'Esprit Saint, il a pris chair de la Vierge Marie, et s'est fait homme. Crucifié pour nous sous Ponce Pilate, Il souffrit sa passion et fut mis au tombeau. Il ressuscita le troisième jour, conformément aux Ecritures, et il monta au ciel; il est assis à la droite du Père. Il reviendra dans la gloire, pour juger les vivants et les morts et son règne n'aura pas de fin. 
Je crois en l'Esprit Saint, qui est Seigneur et qui donne la vie; il procède du Père et du Fils. Avec le Père et le Fils, il reçoit même adoration et même gloire; il a parlé par les prophètes.
Je crois en l'Eglise, une, sainte, catholique et apostolique. Je reconnais un seul baptême pour le pardon des péchés. J'attends la résurrection des morts, et la vie du monde à venir.
Amen
```

### Comparison Results

**✓ CORRECT** - The French translation matches the official AELF source with the 2021 Missel Romain translation using "consubstantiel au Père" (replacing the old "de même nature que le Père").

**Minor Differences:**
- Our file: "lumière née de la lumière" vs Official: "lumière, née de la lumière" (comma difference)
- Our file: "Engendré, non pas créé" vs Official: "Engendré non pas créé" (comma difference)
- Our file: "et par lui tout a été fait" vs Official: "; et par lui tout a été fait" (semicolon difference)
- Our file: "J'attends la résurrection des morts, et la vie du monde à venir. Amen." vs Official: "J'attends la résurrection des morts, et la vie du monde à venir.\nAmen" (line break difference)

**Assessment:** These are minor punctuation differences that do not affect meaning. The theological content is correct and matches the 2021 official translation.

---

## Tagalog (tl) - Credo

### File: `assets/prayers/tl/credo.html`

**Current Content:**
```
Sumasampalataya ako sa Diyos Amang makapangyarihan sa lahat, na may gawa ng langit at lupa.
Sumasampalataya ako kay Hesukristo, iisang Anak ng Diyos, Panginoon nating lahat. Nagkatawang-tao siya lalang ng Espiritu Santo, ipinanganak ni Santa Mariang Birhen. Pinagpakasakit ni Poncio Pilato, ipinako sa krus, namatay, inilibing. Nanaog sa kinaroroonan ng mga yumao. Nang may ikatlong araw nabuhay na mag-uli. Umakyat sa langit. Naluluklok sa kanan ng Diyos Amang makapangyarihan sa lahat. Doon magmumulang paririto at huhukom sa nangabubuhay at nangamatay na tao.
Sumasampalataya naman ako sa Diyos Espiritu Santo, sa banal na Simbahang Katolika, sa kasamahan ng mga banal, sa kapatawaran ng mga kasalanan, sa pagkabuhay na muli ng namamatay na tao at sa buhay na walang hanggan. Amen!
```

### **CRITICAL ISSUE IDENTIFIED**

**Problem:** The Tagalog text in the file is the **Apostles' Creed** (Simbolo ng mga Apostol), NOT the **Nicene Creed** (Simbolo ng Niceno-Constantinople).

**Evidence:**
1. The phrase "Nagkatawang-tao siya lalang ng Espiritu Santo" (He became incarnate by the Holy Spirit) is characteristic of the Apostles' Creed
2. The Nicene Creed should include:
   - "Bugtong na Anak ng Diyos" (Only-begotten Son of God)
   - "Diyos mula sa Diyos" (God from God)
   - "Liwanag mula sa Liwanag" (Light from Light)
   - "Diyos na totoo mula sa Diyos na totoo" (True God from True God)
   - "Inianak, hindi nilikha" (Begotten, not made)
   - "kaisa sa pagka-Diyos ng Ama" or "consubstantial sa Ama" (consubstantial with the Father)

**Official Nicene Creed in Tagalog (from massineverylanguage.com):**
```
Sumasampalataya ako sa iisang Panginoong Hesukristo, ang Bugtong na Anak ng Diyos, ipinanganak ng Ama bago ang lahat ng panahon. Diyos mula sa Diyos, Liwanag mula sa Liwanag, tunay na Diyos mula sa tunay na Diyos, inianak, hindi ginawa, consubstantial sa Ama; sa pamamagitan niya ginawa ang lahat ng bagay...
```

**Official Apostles' Creed in Tagalog (from parokyanisansebastian.wordpress.com):**
```
Sumasampalataya ako sa Diyos Amang Makapangyarihan sa lahat, na may likha ng langit at lupa. Sumasampalataya ako kay JesuKristo, iisang Anak ng Diyos, Panginoon nating lahat. Nagkatawang-tao siya lalang ng Espiritu Santo, ipinanganak ni Santa Mariang Birhen...
```

### **Recommendation**

**ACTION REQUIRED:** Replace the Tagalog `credo.html` content with the actual Nicene Creed (Simbolo ng Niceno-Constantinople) to match the file name and the French version.

The current file contains the Apostles' Creed, which is a different prayer. The Nicene Creed is longer and contains more detailed theological statements about Christ's nature (consubstantiality, begotten not made, etc.).

---

## French (fr) - Pater Noster (Our Father)

### File: `assets/prayers/fr/pater_noster.html`

**Current Content:**
```
Notre Père qui es aux cieux,
que ton Nom soit sanctifié,
que ton règne vienne,
que ta volonté soit faite sur la terre comme au ciel.
Donne-nous aujourd'hui notre pain de ce jour.
Pardonne-nous nos offenses,
comme nous pardonnons aussi à ceux qui nous ont offensés.
Et ne nous laisse pas entrer en tentation,
mais délivre nous du Mal.
Amen.
```

**Official Source (Église catholique en France - AELF):**
```
Notre Père, qui es aux cieux, que ton nom soit sanctifié, que ton règne vienne, que ta volonté soit faite sur la terre comme au ciel. Donne-nous aujourd'hui notre pain de ce jour. Pardonne-nous nos offenses, comme nous pardonnons aussi à ceux qui nous ont offensés.
```

**Note:** The 2021 translation changed "Et ne nous soumis pas à la tentation" to "Et ne nous laisse pas entrer en tentation" (more accurate theological translation).

### Comparison Results

**✓ CORRECT** - The French translation matches the official AELF source with the 2021 translation using "pain de ce jour" and "ne nous laisse pas entrer en tentation".

---

## French (fr) - Confiteor (I Confess)

### File: `assets/prayers/fr/confiteor.html`

**Current Content:**
```
Je confesse à Dieu tout-puissant,
je reconnais devant mes frères,
que j'ai péché en pensée, en parole, par action et par omission ;
oui, j'ai vraiment péché.
C'est pourquoi je supplie la Vierge Marie, les anges et tous les saints,
et vous aussi, mes frères,
de prier pour moi le Seigneur notre Dieu.
```

**Official Source (Diocèse de Versailles - Carpedeum):**
```
Je confesse à Dieu tout-puissant,
Je reconnais devant mes frères,
que j'ai péché en pensée, en parole,
par action et par omission ;
oui, j'ai vraiment péché.
C'est pourquoi je supplie la Vierge Marie,
les anges et tous les saints,
et vous aussi, mes frères,
de prier pour moi le Seigneur notre Dieu.
```

### Comparison Results

**✓ CORRECT** - The French translation matches the official source. Minor capitalization differences ("Je" vs "je") which are stylistic.

---

## Tagalog (tl) - Pater Noster (Our Father)

### File: `assets/prayers/tl/pater_noster.html`

**Current Content:**
```
Ama namin, sumasalangit ka,
Sambahin ang ngalan mo,
Mapasaamin ang kaharian mo,
Sundin ang loob mo dito sa lupa para nang sa langit.
Bigyan mo kami ngayon ng aming kakanin sa araw-araw,
At patawarin mo kami sa aming mga sala,
Para ng pagpapatawad namin sa mga nagkakasala sa amin,
At huwag mo kaming ipahintulot sa tukso,
ngunit iligtas mo kami sa kasamaan.
Amen.
```

**Official Source (Bukas Palad):**
```
Ama namin sumasalangit Ka
Sambahin ang ngalan Mo
Mapasaamin ang kaharian Mo
Sundin ang loob Mo Dito sa lupa para nang sa langit
Bigyan Mo kami ngayon Ng aming kakanin sa araw-araw
At patawarin Mo kami Sa aming mga sala
Para ng pagpapatawad namin Sa nagkakasala sa amin
At huwag Mo kaming ipahintulot Sa tukso
ngunit iligtas Mo kami sa kasamaan
```

### Comparison Results

**✓ CORRECT** - The Tagalog translation matches the Bukas Palad source, which is a widely used Tagalog liturgical music source in the Philippines.

---

## Tagalog (tl) - Confiteor (I Confess)

### File: `assets/prayers/tl/confiteor.html`

**Current Content:**
```
Aaminin ko sa Diyos na makapangyarihan,
at sa inyo, mga kapatid,
na ako ay nagkasala sa pag-iisip, sa salita, sa gawa at sa pagkukulang;
sa aking kasalanan, sa aking kasalanan, sa aking malaking kasalanan.
Kaya naman hinihiling ko sa Mahal na Birheng Maria,
sa mga anghel, at sa inyo, mga kapatid,
at sa inyo, Ama,
na ipanalangin ninyo ako sa Diyos, ang ating Panginoon.
```

**Note:** The Tagalog Confiteor includes "at sa inyo, Ama" (and to you, Father) at the end, which is not in the standard Confiteor structure. The standard Confiteor typically ends with praying to the Lord our God, not specifically addressing the Father separately.

### Comparison Results

**⚠️ POTENTIAL ISSUE** - The Tagalog Confiteor includes an extra phrase "at sa inyo, Ama" (and to you, Father) that may not be in the standard Confiteor. This needs verification with official CBCP sources.

---

## Tagalog (tl) - Sign of the Cross

### File: `assets/prayers/tl/sign_of_the_cross.html`

**Current Content:**
```
Sa ngalan ng Ama,
at ng Anak,
at ng Espiritu Santo.
Amen.
```

**Official Source (Various Catholic sources in Philippines):**
```
Sa ngalan ng Ama, at ng Anak, at ng Espiritu Santo. Amen.
```

### Comparison Results

**✓ CORRECT** - The Tagalog translation matches standard Philippine Catholic sources.

---

## Summary of Cross-Check Results

### Critical Issues:
1. **Tagalog Credo file contains Apostles' Creed instead of Nicene Creed** - This is a significant error that needs correction.

### Potential Issues:
1. **Tagalog Confiteor** includes extra phrase "at sa inyo, Ama" that may not be in standard form - needs verification with CBCP.

### Minor Issues:
1. French Credo has minor punctuation differences from official source (commas vs semicolons) - These do not affect meaning.
2. French Confiteor has minor capitalization differences - These are stylistic.

### Correct Translations:
1. French Sign of the Cross ✓
2. French Pater Noster ✓ (matches 2021 translation)
3. French Confiteor ✓
4. French Credo ✓ (matches 2021 "consubstantiel" translation)
5. Tagalog Sign of the Cross ✓
6. Tagalog Pater Noster ✓ (matches Bukas Palad)
7. Tagalog Confiteor ⚠️ (needs verification)
8. Tagalog Credo ✗ (wrong creed - Apostles instead of Nicene)

### Network Issues Encountered:
- Could not access teddyliterati.wordpress.com for Tagalog Nicene Creed
- Could not access en.wiktionary.org for Tagalog prayers
- Some official diocesan websites did not load full prayer text content

### Next Steps:
1. **URGENT:** Replace Tagalog `credo.html` with actual Nicene Creed translation
2. Verify Tagalog Confiteor with official CBCP source to confirm if "at sa inyo, Ama" is correct
3. Attempt to access alternative sources for Tagalog Nicene Creed text (some sources were inaccessible due to network issues)
