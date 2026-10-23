# Fiche de validation du sujet

**Groupe :** Groupe n° A_COMPLETER

**Membres :**

1. A_COMPLETER
2. A_COMPLETER
3. A_COMPLETER
4. A_COMPLETER
5. A_COMPLETER

**Titre du projet :** Analyse des variants genetiques pathogenes associes a la
cardiomyopathie hypertrophique dans les soumissions ClinVar.

**Maladie et question :** Cardiomyopathie hypertrophique. Parmi les variants
distincts rapportes dans ClinVar pour la cardiomyopathie hypertrophique et
classes « Pathogenic » ou « Likely pathogenic », quels genes sont les plus
representes ?

**Jeu de donnees :** base publique NCBI ClinVar, export archive d'octobre 2026 :
`submission_summary_2026-10.txt.gz`.

**Lien :**
https://ftp.ncbi.nlm.nih.gov/pub/clinvar/tab_delimited/archive/submission_summary_2026-10.txt.gz

**Taille telechargee :** environ 394,2 Mo au format compresse `.gz`.

**Date de telechargement :** 23/10/2026 (a confirmer par l'etudiant 2).

**Methode prevue :** les champs de phenotype permettront de verifier que chaque
soumission concerne specifiquement la cardiomyopathie hypertrophique. Les
classifications contradictoires seront signalees separement. Les genes seront
obtenus depuis `SubmittedGeneSymbol` et chaque paire `VariationID`-gene sera
comptee une seule fois.
