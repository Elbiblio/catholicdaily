# Functional Mass Structure - Data-Driven Implementation

This document outlines the complete data structure for implementing a full Mass flow that integrates with the liturgical calendar.

## Overview

The Mass structure is divided into two categories:
1. **Ordinary (Fixed)**: Parts that are always the same text (Sign of Cross, Our Father, etc.)
2. **Proper (Variable)**: Parts that change based on the liturgical calendar (Collect, Readings, Gospel, etc.)

## Insertion Points

The Mass is organized by insertion points that define where each part appears:

```json
{
  "introductory_rites": "Before the Liturgy of the Word",
  "before_first_reading": "Before the First Reading",
  "between_readings": "Between Readings (Psalm)",
  "before_gospel": "Before the Gospel",
  "after_gospel": "After the Gospel",
  "before_offertory": "Before the Presentation of Gifts",
  "offertory": "Presentation of Gifts",
  "preface": "Eucharistic Prayer - Preface",
  "sanctus": "Eucharistic Prayer - Sanctus",
  "eucharistic_prayer": "Eucharistic Prayer - Institution Narrative",
  "acclamation": "Eucharistic Prayer - Acclamation",
  "lords_prayer": "The Lord's Prayer",
  "sign_of_peace": "Sign of Peace",
  "fraction": "Fraction of the Bread (Lamb of God)",
  "communion": "Holy Communion",
  "after_communion": "Prayer after Communion",
  "concluding_rites": "Concluding Rites"
}
```

## Complete JSON Structure

### 1. Introductory Rites

```json
{
  "id": "entrance_antiphon",
  "title": "Entrance Antiphon",
  "insertionPoint": "introductory_rites",
  "order": 1,
  "type": "variable",
  "source": "liturgical_calendar",
  "sourceField": "entranceAntiphon",
  "availableLanguages": ["en", "la", "es", "pt", "fr", "tl", "it", "pl", "vi", "ko"],
  "conditions": ["always"],
  "isOptional": false,
  "role": "choir"
},
{
  "id": "greeting",
  "title": "Greeting",
  "insertionPoint": "introductory_rites",
  "order": 2,
  "type": "fixed",
  "dialogue": [
    {
      "speaker": "priest",
      "text": "In the name of the Father, and of the Son, and of the Holy Spirit."
    },
    {
      "speaker": "people",
      "text": "Amen."
    },
    {
      "speaker": "priest",
      "text": "The Lord be with you."
    },
    {
      "speaker": "people",
      "text": "And with your spirit."
    }
  ],
  "contentByLanguage": {
    "en": ["In the name of the Father, and of the Son, and of the Holy Spirit.", "Amen.", "The Lord be with you.", "And with your spirit."],
    "la": ["In nómine Patris, et Fílii, et Spíritus Sancti.", "Amen.", "Dóminus vobíscum.", "Et cum spíritu tuo."]
  },
  "availableLanguages": ["en", "la", "es", "pt", "fr", "tl", "it", "pl", "vi", "ko"],
  "conditions": ["always"],
  "isOptional": false,
  "isDialogue": true
},
{
  "id": "penitential_act_form_a",
  "title": "Penitential Act - Confiteor",
  "insertionPoint": "introductory_rites",
  "order": 3,
  "type": "fixed",
  "prayerSlug": "confiteor",
  "availableLanguages": ["en", "la", "es", "pt", "fr", "tl", "it", "pl", "vi", "ko"],
  "conditions": ["always"],
  "isOptional": true,
  "alternativeGroup": "penitential_act"
},
{
  "id": "penitential_act_form_b",
  "title": "Penitential Act - Have Mercy",
  "insertionPoint": "introductory_rites",
  "order": 3,
  "type": "fixed",
  "dialogue": [
    {"speaker": "priest", "text": "Have mercy on us, Lord."},
    {"speaker": "people", "text": "For we have sinned against you."},
    {"speaker": "priest", "text": "Show us, O Lord, your mercy."},
    {"speaker": "people", "text": "And grant us your salvation."}
  ],
  "contentByLanguage": {
    "en": ["Have mercy on us, Lord.", "For we have sinned against you.", "Show us, O Lord, your mercy.", "And grant us your salvation."],
    "la": ["Miserére nostri, Dómine.", "Quia peccávimus tibi.", "Osténde nobis, Dómine, misericórdiam tuam.", "Et salutáre tuum da nobis."]
  },
  "availableLanguages": ["en", "la", "es", "pt", "fr", "tl", "it", "pl", "vi", "ko"],
  "conditions": ["always"],
  "isOptional": true,
  "isDialogue": true,
  "alternativeGroup": "penitential_act"
},
{
  "id": "kyrie",
  "title": "Kyrie Eleison",
  "insertionPoint": "introductory_rites",
  "order": 4,
  "type": "fixed",
  "dialogue": [
    {"speaker": "all", "text": "Lord, have mercy."},
    {"speaker": "all", "text": "Lord, have mercy."},
    {"speaker": "all", "text": "Christ, have mercy."},
    {"speaker": "all", "text": "Christ, have mercy."},
    {"speaker": "all", "text": "Lord, have mercy."},
    {"speaker": "all", "text": "Lord, have mercy."}
  ],
  "contentByLanguage": {
    "en": ["Lord, have mercy.", "Lord, have mercy.", "Christ, have mercy.", "Christ, have mercy.", "Lord, have mercy.", "Lord, have mercy."],
    "la": ["Kýrie, eléison.", "Kýrie, eléison.", "Christe, eléison.", "Christe, eléison.", "Kýrie, eléison.", "Kýrie, eléison."]
  },
  "availableLanguages": ["en", "la", "es", "pt", "fr", "tl", "it", "pl", "vi", "ko"],
  "conditions": ["always"],
  "isOptional": true,
  "isDialogue": true
},
{
  "id": "gloria",
  "title": "Gloria",
  "insertionPoint": "introductory_rites",
  "order": 5,
  "type": "fixed",
  "prayerSlug": "gloria",
  "availableLanguages": ["en", "la", "es", "pt", "fr", "tl", "it", "pl", "vi", "ko"],
  "conditions": ["not_advent", "not_lent", "sunday_or_solemnity"],
  "isOptional": false
},
{
  "id": "collect",
  "title": "Collect (Opening Prayer)",
  "insertionPoint": "introductory_rites",
  "order": 6,
  "type": "variable",
  "source": "liturgical_calendar",
  "sourceField": "collect",
  "availableLanguages": ["en", "la", "es", "pt", "fr", "tl", "it", "pl", "vi", "ko"],
  "conditions": ["always"],
  "isOptional": false,
  "role": "priest"
}
```

### 2. Liturgy of the Word

```json
{
  "id": "first_reading",
  "title": "First Reading",
  "insertionPoint": "before_first_reading",
  "order": 1,
  "type": "variable",
  "source": "readings",
  "sourceField": "first_reading",
  "availableLanguages": ["en", "la", "es", "pt", "fr", "tl", "it", "pl", "vi", "ko"],
  "conditions": ["always"],
  "isOptional": false,
  "role": "lector",
  "response": "Thanks be to God."
},
{
  "id": "responsorial_psalm",
  "title": "Responsorial Psalm",
  "insertionPoint": "between_readings",
  "order": 1,
  "type": "variable",
  "source": "readings",
  "sourceField": "psalm",
  "availableLanguages": ["en", "la", "es", "pt", "fr", "tl", "it", "pl", "vi", "ko"],
  "conditions": ["always"],
  "isOptional": false,
  "role": "cantor",
  "isResponsive": true
},
{
  "id": "second_reading",
  "title": "Second Reading",
  "insertionPoint": "between_readings",
  "order": 2,
  "type": "variable",
  "source": "readings",
  "sourceField": "second_reading",
  "availableLanguages": ["en", "la", "es", "pt", "fr", "tl", "it", "pl", "vi", "ko"],
  "conditions": ["sunday_only", "solemnity"],
  "isOptional": false,
  "role": "lector",
  "response": "Thanks be to God."
},
{
  "id": "gospel_acclamation",
  "title": "Gospel Acclamation",
  "insertionPoint": "before_gospel",
  "order": 1,
  "type": "variable",
  "source": "readings",
  "sourceField": "gospel_acclamation",
  "availableLanguages": ["en", "la", "es", "pt", "fr", "tl", "it", "pl", "vi", "ko"],
  "conditions": ["always"],
  "isOptional": false,
  "role": "cantor"
},
{
  "id": "gospel",
  "title": "Gospel",
  "insertionPoint": "before_gospel",
  "order": 2,
  "type": "variable",
  "source": "readings",
  "sourceField": "gospel",
  "availableLanguages": ["en", "la", "es", "pt", "fr", "tl", "it", "pl", "vi", "ko"],
  "conditions": ["always"],
  "isOptional": false,
  "role": "deacon_or_priest",
  "dialogue": [
    {"speaker": "deacon", "text": "The Lord be with you."},
    {"speaker": "people", "text": "And with your spirit."},
    {"speaker": "deacon", "text": "A reading from the holy Gospel according to [N]."},
    {"speaker": "people", "text": "Glory to you, O Lord."}
  ],
  "response": "Praise to you, Lord Jesus Christ."
},
{
  "id": "homily",
  "title": "Homily",
  "insertionPoint": "after_gospel",
  "order": 1,
  "type": "variable",
  "source": "liturgical_calendar",
  "sourceField": "homily",
  "availableLanguages": ["en", "la", "es", "pt", "fr", "tl", "it", "pl", "vi", "ko"],
  "conditions": ["always"],
  "isOptional": false,
  "role": "priest_or_deacon"
},
{
  "id": "creed_nicene",
  "title": "Nicene Creed",
  "insertionPoint": "after_gospel",
  "order": 2,
  "type": "fixed",
  "prayerSlug": "creed_nicene",
  "availableLanguages": ["en", "la", "es", "pt", "fr", "tl", "it", "pl", "vi", "ko"],
  "conditions": ["sunday_only", "solemnity"],
  "isOptional": false,
  "alternativeGroup": "creed"
},
{
  "id": "creed_apostles",
  "title": "Apostles' Creed",
  "insertionPoint": "after_gospel",
  "order": 2,
  "type": "fixed",
  "prayerSlug": "creed_apostles",
  "availableLanguages": ["en", "la", "es", "pt", "fr", "tl", "it", "pl", "vi", "ko"],
  "conditions": ["sunday_only", "solemnity"],
  "isOptional": false,
  "alternativeGroup": "creed"
},
{
  "id": "prayer_of_the_faithful",
  "title": "Prayer of the Faithful",
  "insertionPoint": "after_gospel",
  "order": 3,
  "type": "variable",
  "source": "liturgical_calendar",
  "sourceField": "prayers_of_the_faithful",
  "availableLanguages": ["en", "la", "es", "pt", "fr", "tl", "it", "pl", "vi", "ko"],
  "conditions": ["always"],
  "isOptional": false,
  "role": "deacon",
  "response": "Lord, hear our prayer."
}
```

### 3. Liturgy of the Eucharist

```json
{
  "id": "presentation_of_gifts",
  "title": "Presentation of the Gifts",
  "insertionPoint": "offertory",
  "order": 1,
  "type": "fixed",
  "dialogue": [
    {"speaker": "priest", "text": "Blessed are you, Lord God of all creation, for through your goodness we have received the bread we offer you: fruit of the earth and work of human hands, it will become for us the bread of life."},
    {"speaker": "people", "text": "Blessed be God for ever."},
    {"speaker": "priest", "text": "Blessed are you, Lord God of all creation, for through your goodness we have received the wine we offer you: fruit of the vine and work of human hands, it will become our spiritual drink."},
    {"speaker": "people", "text": "Blessed be God for ever."}
  ],
  "contentByLanguage": {
    "en": ["Blessed are you, Lord God of all creation, for through your goodness we have received the bread we offer you: fruit of the earth and work of human hands, it will become for us the bread of life.", "Blessed be God for ever.", "Blessed are you, Lord God of all creation, for through your goodness we have received the wine we offer you: fruit of the vine and work of human hands, it will become our spiritual drink.", "Blessed be God for ever."],
    "la": ["Benedíctus es, Dómine, Deus univérsi, quia de tua largitáte accépimus panem, quem tibi offérimus, fructum terræ et óperis mánuum hóminum: ex quo nobis fiet panis vitæ.", "Benedíctus Deus in sæcula.", "Benedíctus es, Dómine, Deus univérsi, quia de tua largitáte accépimus vinum, quod tibi offérimus, fructum vitis et óperis mánuum hóminum: ex quo nobis fiet potus spiritális.", "Benedíctus Deus in sæcula."]
  },
  "availableLanguages": ["en", "la", "es", "pt", "fr", "tl", "it", "pl", "vi", "ko"],
  "conditions": ["always"],
  "isOptional": false,
  "isDialogue": true
},
{
  "id": "prayer_over_offerings",
  "title": "Prayer over the Offerings",
  "insertionPoint": "offertory",
  "order": 2,
  "type": "variable",
  "source": "liturgical_calendar",
  "sourceField": "prayer_over_offerings",
  "availableLanguages": ["en", "la", "es", "pt", "fr", "tl", "it", "pl", "vi", "ko"],
  "conditions": ["always"],
  "isOptional": false,
  "role": "priest",
  "response": "Amen."
},
{
  "id": "preface_dialogue",
  "title": "Preface Dialogue",
  "insertionPoint": "preface",
  "order": 1,
  "type": "fixed",
  "dialogue": [
    {"speaker": "priest", "text": "The Lord be with you."},
    {"speaker": "people", "text": "And with your spirit."},
    {"speaker": "priest", "text": "Lift up your hearts."},
    {"speaker": "people", "text": "We lift them up to the Lord."},
    {"speaker": "priest", "text": "Let us give thanks to the Lord our God."},
    {"speaker": "people", "text": "It is right and just."}
  ],
  "contentByLanguage": {
    "en": ["The Lord be with you.", "And with your spirit.", "Lift up your hearts.", "We lift them up to the Lord.", "Let us give thanks to the Lord our God.", "It is right and just."],
    "la": ["Dóminus vobíscum.", "Et cum spíritu tuo.", "Sursum corda.", "Habémus ad Dóminum.", "Grátias agámus Dómino Deo nostro.", "Dignum et iustum est."]
  },
  "availableLanguages": ["en", "la", "es", "pt", "fr", "tl", "it", "pl", "vi", "ko"],
  "conditions": ["always"],
  "isOptional": false,
  "isDialogue": true
},
{
  "id": "preface",
  "title": "Preface",
  "insertionPoint": "preface",
  "order": 2,
  "type": "variable",
  "source": "liturgical_calendar",
  "sourceField": "preface",
  "availableLanguages": ["en", "la", "es", "pt", "fr", "tl", "it", "pl", "vi", "ko"],
  "conditions": ["always"],
  "isOptional": false,
  "role": "priest"
},
{
  "id": "sanctus",
  "title": "Sanctus",
  "insertionPoint": "sanctus",
  "order": 1,
  "type": "fixed",
  "prayerSlug": "sanctus",
  "availableLanguages": ["en", "la", "es", "pt", "fr", "tl", "it", "pl", "vi", "ko"],
  "conditions": ["always"],
  "isOptional": false
},
{
  "id": "eucharistic_prayer",
  "title": "Eucharistic Prayer",
  "insertionPoint": "eucharistic_prayer",
  "order": 1,
  "type": "variable",
  "source": "liturgical_calendar",
  "sourceField": "eucharistic_prayer",
  "availableLanguages": ["en", "la", "es", "pt", "fr", "tl", "it", "pl", "vi", "ko"],
  "conditions": ["always"],
  "isOptional": false,
  "role": "priest",
  "sections": ["epiclesis", "institution_narrative", "anamnesis", "intercessions"]
},
{
  "id": "mystery_of_faith_acclamation",
  "title": "Mystery of Faith Acclamation",
  "insertionPoint": "acclamation",
  "order": 1,
  "type": "fixed",
  "dialogue": [
    {"speaker": "priest", "text": "The mystery of faith."},
    {"speaker": "people", "text": "We proclaim your Death, O Lord, and profess your Resurrection until you come again."}
  ],
  "contentByLanguage": {
    "en": ["The mystery of faith.", "We proclaim your Death, O Lord, and profess your Resurrection until you come again."],
    "la": ["Mystérium fídei.", "Annuntiamus mortem tuam, Dómine, confitémur resurrectiónem tuam, donec venias."]
  },
  "availableLanguages": ["en", "la", "es", "pt", "fr", "tl", "it", "pl", "vi", "ko"],
  "conditions": ["always"],
  "isOptional": false,
  "isDialogue": true,
  "alternativeGroup": "acclamation"
},
{
  "id": "final_doxology",
  "title": "Final Doxology",
  "insertionPoint": "acclamation",
  "order": 2,
  "type": "fixed",
  "dialogue": [
    {"speaker": "priest", "text": "Through him, and with him, and in him, O God, almighty Father, in the unity of the Holy Spirit, all glory and honor is yours, for ever and ever."},
    {"speaker": "people", "text": "Amen."}
  ],
  "contentByLanguage": {
    "en": ["Through him, and with him, and in him, O God, almighty Father, in the unity of the Holy Spirit, all glory and honor is yours, for ever and ever.", "Amen."],
    "la": ["Per ipsum, et cum ipso, et in ipso, Dómine, Deus Pater omnípotens, in unitáte Spíritus Sancti, omnis honor et glória tua, per ómnia sæcula sæculórum.", "Amen."]
  },
  "availableLanguages": ["en", "la", "es", "pt", "fr", "tl", "it", "pl", "vi", "ko"],
  "conditions": ["always"],
  "isOptional": false,
  "isDialogue": true
},
{
  "id": "lords_prayer",
  "title": "The Lord's Prayer",
  "insertionPoint": "lords_prayer",
  "order": 1,
  "type": "fixed",
  "prayerSlug": "pater_noster",
  "availableLanguages": ["en", "la", "es", "pt", "fr", "tl", "it", "pl", "vi", "ko"],
  "conditions": ["always"],
  "isOptional": false
},
{
  "id": "embolism",
  "title": "Embolism",
  "insertionPoint": "lords_prayer",
  "order": 2,
  "type": "fixed",
  "dialogue": [
    {"speaker": "priest", "text": "Deliver us, Lord, we pray, from every evil, graciously grant peace in our days, that, by the help of your mercy, we may be always free from sin and safe from all distress, as we await the blessed hope and the coming of our Savior, Jesus Christ."},
    {"speaker": "people", "text": "For the kingdom, the power and the glory are yours now and for ever."}
  ],
  "contentByLanguage": {
    "en": ["Deliver us, Lord, we pray, from every evil, graciously grant peace in our days, that, by the help of your mercy, we may be always free from sin and safe from all distress, as we await the blessed hope and the coming of our Savior, Jesus Christ.", "For the kingdom, the power and the glory are yours now and for ever."],
    "la": ["Líbera nos, quæsumus, Dómine, ab ómnibus malis, da propítius pacem in diébus nostris, ut, ope misericórdiæ tuæ adiúti, et a peccáto simus semper líberi et ab omni perturbatióne secúri, exspectántes beátam spem et advéntum Salvatóris nostri Iesu Christi.", "Tuum est regnum, et potéstas, et glória in sæcula."]
  },
  "availableLanguages": ["en", "la", "es", "pt", "fr", "tl", "it", "pl", "vi", "ko"],
  "conditions": ["always"],
  "isOptional": false,
  "isDialogue": true
},
{
  "id": "sign_of_peace",
  "title": "Sign of Peace",
  "insertionPoint": "sign_of_peace",
  "order": 1,
  "type": "fixed",
  "dialogue": [
    {"speaker": "priest", "text": "Lord Jesus Christ, who said to your Apostles: Peace I leave you, my peace I give you; look not on our sins, but on the faith of your Church, and graciously grant her peace and unity in accordance with your will. Who live and reign for ever and ever."},
    {"speaker": "people", "text": "Amen."},
    {"speaker": "priest", "text": "The Peace of the Lord be with you always."},
    {"speaker": "people", "text": "And with your spirit."},
    {"speaker": "deacon", "text": "Let us offer each other the sign of peace."}
  ],
  "contentByLanguage": {
    "en": ["Lord Jesus Christ, who said to your Apostles: Peace I leave you, my peace I give you; look not on our sins, but on the faith of your Church, and graciously grant her peace and unity in accordance with your will. Who live and reign for ever and ever.", "Amen.", "The Peace of the Lord be with you always.", "And with your spirit.", "Let us offer each other the sign of peace."],
    "la": ["Dómine Iesu Christe, qui dixísti Apóstolis tuis: Pacem relínquo vobis, pacem meam do vobis: ne respícias peccáta nostra, sed fidém Ecclésiæ tuæ, eámque secúndum voluntátem tuam pacíficáre et coadunáre dignéris. Qui vivis et regnas in sæcula sæculórum.", "Amen.", "Pax Dómini sit semper vobíscum.", "Et cum spíritu tuo.", "Offérte vobis pacem."]
  },
  "availableLanguages": ["en", "la", "es", "pt", "fr", "tl", "it", "pl", "vi", "ko"],
  "conditions": ["always"],
  "isOptional": false,
  "isDialogue": true
},
{
  "id": "agnus_dei",
  "title": "Lamb of God",
  "insertionPoint": "fraction",
  "order": 1,
  "type": "fixed",
  "prayerSlug": "agnus_dei",
  "availableLanguages": ["en", "la", "es", "pt", "fr", "tl", "it", "pl", "vi", "ko"],
  "conditions": ["always"],
  "isOptional": false
},
{
  "id": "communion_invitation",
  "title": "Communion Invitation",
  "insertionPoint": "communion",
  "order": 1,
  "type": "fixed",
  "dialogue": [
    {"speaker": "priest", "text": "Behold the Lamb of God, behold him who takes away the sins of the world."},
    {"speaker": "people", "text": "Lord, I am not worthy that you should enter under my roof, but only say the word and my soul shall be healed."}
  ],
  "contentByLanguage": {
    "en": ["Behold the Lamb of God, behold him who takes away the sins of the world.", "Lord, I am not worthy that you should enter under my roof, but only say the word and my soul shall be healed."],
    "la": ["Ecce Agnus Dei, ecce qui tollit peccáta mundi.", "Dómine, non sum dignus ut intres sub tectum meum, sed tantum dic verbo et sanábitur ánima mea."]
  },
  "availableLanguages": ["en", "la", "es", "pt", "fr", "tl", "it", "pl", "vi", "ko"],
  "conditions": ["always"],
  "isOptional": false,
  "isDialogue": true
},
{
  "id": "communion_antiphon",
  "title": "Communion Antiphon",
  "insertionPoint": "communion",
  "order": 2,
  "type": "variable",
  "source": "liturgical_calendar",
  "sourceField": "communion_antiphon",
  "availableLanguages": ["en", "la", "es", "pt", "fr", "tl", "it", "pl", "vi", "ko"],
  "conditions": ["always"],
  "isOptional": false,
  "role": "choir"
},
{
  "id": "prayer_after_communion",
  "title": "Prayer after Communion",
  "insertionPoint": "after_communion",
  "order": 1,
  "type": "variable",
  "source": "liturgical_calendar",
  "sourceField": "prayer_after_communion",
  "availableLanguages": ["en", "la", "es", "pt", "fr", "tl", "it", "pl", "vi", "ko"],
  "conditions": ["always"],
  "isOptional": false,
  "role": "priest",
  "response": "Amen."
}
```

### 4. Concluding Rites

```json
{
  "id": "announcements",
  "title": "Announcements",
  "insertionPoint": "concluding_rites",
  "order": 1,
  "type": "variable",
  "source": "liturgical_calendar",
  "sourceField": "announcements",
  "availableLanguages": ["en", "la", "es", "pt", "fr", "tl", "it", "pl", "vi", "ko"],
  "conditions": ["always"],
  "isOptional": true,
  "role": "deacon"
},
{
  "id": "final_blessing",
  "title": "Final Blessing",
  "insertionPoint": "concluding_rites",
  "order": 2,
  "type": "fixed",
  "dialogue": [
    {"speaker": "priest", "text": "The Lord be with you."},
    {"speaker": "people", "text": "And with your spirit."}
  ],
  "contentByLanguage": {
    "en": ["The Lord be with you.", "And with your spirit."],
    "la": ["Dóminus vobíscum.", "Et cum spíritu tuo."]
  },
  "availableLanguages": ["en", "la", "es", "pt", "fr", "tl", "it", "pl", "vi", "ko"],
  "conditions": ["always"],
  "isOptional": false,
  "isDialogue": true
},
{
  "id": "dismissal",
  "title": "Dismissal",
  "insertionPoint": "concluding_rites",
  "order": 3,
  "type": "fixed",
  "dialogue": [
    {"speaker": "deacon", "text": "Go forth, the Mass is ended."},
    {"speaker": "people", "text": "Thanks be to God."}
  ],
  "contentByLanguage": {
    "en": ["Go forth, the Mass is ended.", "Thanks be to God."],
    "la": ["Ite, missa est.", "Deo grátias."]
  },
  "availableLanguages": ["en", "la", "es", "pt", "fr", "tl", "it", "pl", "vi", "ko"],
  "conditions": ["always"],
  "isOptional": false,
  "isDialogue": true,
  "alternativeGroup": "dismissal"
}
```

## Condition Logic

The `conditions` array supports the following values:

- `always`: Always shown
- `sunday_only`: Only on Sundays
- `solemnity`: Only on solemnities
- `sunday_or_solemnity`: Sundays or solemnities
- `not_advent`: Not during Advent
- `not_lent`: Not during Lent
- `lent`: Only during Lent
- `easter_vigil`: Only on Easter Vigil
- `weekday_only`: Only on weekdays

## Data Source Fields

For `type: "variable"` items, the `source` and `sourceField` define where to get the content:

- `source: "liturgical_calendar"`: From the liturgical calendar service
  - `entranceAntiphon`: Entrance antiphon text
  - `collect`: Collect prayer
  - `homily`: Homily/reflection
  - `prayers_of_the_faithful`: Universal prayer intentions
  - `prayer_over_offerings`: Prayer over the offerings
  - `preface`: Preface text
  - `eucharistic_prayer`: Complete Eucharistic Prayer
  - `communion_antiphon`: Communion antiphon
  - `prayer_after_communion`: Post-communion prayer
  - `announcements`: Parish announcements

- `source: "readings"`: From the readings service
  - `first_reading`: First reading text and reference
  - `psalm`: Responsorial psalm with response
  - `second_reading`: Second reading text and reference
  - `gospel_acclamation`: Gospel acclamation verse
  - `gospel`: Gospel reading text and reference

## Role-Based Display

The `role` field indicates who typically speaks/sings this part:
- `priest`: Presiding priest
- `deacon`: Deacon assisting
- `deacon_or_priest`: Either deacon or priest
- `lector`: Lector/reader
- `cantor`: Cantor/psalmist
- `choir`: Choir/schola
- `all`: Entire assembly

## Dialogue Structure

For items with `isDialogue: true`, the content is structured as alternating speaker/line pairs. The UI can display this with visual distinction between priest and people parts.

## Implementation Notes

1. **Service Extension**: Extend `OrderOfMassService` to handle the new insertion points and data sources
2. **Reading Integration**: The readings service should provide data in the expected format for variable items
3. **Calendar Integration**: The liturgical calendar service should provide proper prayers (collect, preface, etc.)
4. **UI Enhancement**: The reading screen can display the complete Mass flow with navigation between parts
5. **Language Support**: All fixed prayers should have content in the supported languages
6. **Condition Evaluation**: The service should evaluate conditions based on the resolved liturgical day

## Migration Path

1. Update `order_of_mass.json` with the complete structure
2. Extend `OrderOfMassService` to handle new insertion points
3. Add data fetching for variable parts from calendar and readings services
4. Update UI to display dialogue format and role indicators
5. Add navigation through the complete Mass flow
6. Test with various liturgical days to ensure condition logic works correctly
