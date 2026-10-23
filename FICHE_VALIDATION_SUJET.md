# Fiche de validation du sujet

**Groupe :** Groupe n° A_COMPLETER

**Membres :**

1. A_COMPLETER
2. A_COMPLETER
3. A_COMPLETER
4. A_COMPLETER
5. A_COMPLETER

**Titre du projet :** Analyse des variants genetiques pathogenes associes a la
cardiomyopathie hypertrophique dans ClinVar.

**Maladie et question :** Cardiomyopathie hypertrophique. Parmi les variants
genetiques distincts classes « Pathogenic » ou « Likely pathogenic »
specifiquement pour la cardiomyopathie hypertrophique dans ClinVar, quels genes
en concentrent le plus ?

**Jeu de donnees :** base publique NCBI ClinVar, version archivee d'octobre
2026, composee de deux exports complementaires :

- `variant_summary_2026-10.txt.gz` :
  https://ftp.ncbi.nlm.nih.gov/pub/clinvar/tab_delimited/archive/variant_summary_2026-10.txt.gz
  (environ 450,7 Mo compresses) ;
- `submission_summary_2026-10.txt.gz` :
  https://ftp.ncbi.nlm.nih.gov/pub/clinvar/tab_delimited/archive/submission_summary_2026-10.txt.gz
  (environ 394,2 Mo compresses).

**Taille totale telechargee :** environ 844,9 Mo au format compresse `.gz`.

**Date de telechargement :** 23/10/2026 (a confirmer par l'etudiant 2).

**Methode prevue :** `submission_summary` permettra de verifier que la
classification concerne specifiquement la cardiomyopathie hypertrophique. Le
fichier sera relie a `variant_summary` par `VariationID` pour identifier le
gene. Les classifications contradictoires seront signalees separement. Chaque
paire `VariationID`-gene sera comptee une seule fois.
