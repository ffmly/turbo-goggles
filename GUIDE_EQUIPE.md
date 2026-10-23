# Guide d'integration de l'equipe

Ce document fixe les fichiers attendus par `run.sh`. Chaque membre travaille
uniquement dans les fichiers indiques, puis remet son travail a l'etudiant 1
pour integration et test final.

## Etudiant 1 - orchestration

Fichiers geres :

- `run.sh`
- `scripts/filter_hcm_submissions.sh`
- `config/dataset.env` (structure seulement)
- arborescence du projet et integration finale

Le pipeline relie les livrables des autres membres. Il filtre d'abord les
soumissions qui concernent la cardiomyopathie hypertrophique, puis appelle le
script Python de l'etudiant 3.

## Etudiant 2 - sources des donnees

Fichiers a completer :

- `SOURCES.md`
- `config/dataset.env`

Travail demande :

1. verifier l'URL ClinVar et la version d'octobre 2026 ;
2. noter la taille exacte et la date de telechargement dans `SOURCES.md` ;
3. calculer la somme SHA-256 du fichier ;
4. remplacer `TODO_ETUDIANT_2` dans `config/dataset.env` ;
5. indiquer la licence ou les conditions de reutilisation de ClinVar.

Commande possible pour une empreinte :

```bash
sha256sum data/raw/nom_du_fichier.txt.gz
```

## Etudiant 3 - analyse Python

Fichiers a creer :

- `scripts/analyze_genes.py`
- un test automatique dans `tests/`

Interface obligatoire :

```text
python3 scripts/analyze_genes.py \
  --submissions data/processed/hcm_submissions.tsv \
  --output-dir results \
  --top 15
```

Le script doit fonctionner avec Python 3. `run.sh` essaie `python3`, puis
`python`; la variable d'environnement `PYTHON_BIN` permet d'imposer un chemin
si necessaire.

Regles d'analyse :

1. utiliser uniquement les soumissions germinales qui contribuent a la
   classification agregee ;
2. conserver `Pathogenic`, `Likely pathogenic` et
   `Pathogenic/Likely pathogenic` ;
3. si des soumissions HCM du meme `VariationID` portent des classifications
   incompatibles, exclure ce variant du classement principal ;
4. normaliser `SubmittedGeneSymbol` (espaces, casse et valeurs manquantes) ;
5. exclure du classement les variants sans symbole de gene exploitable ;
6. compter chaque paire `VariationID`-gene une seule fois, meme si plusieurs
   laboratoires ont soumis le meme variant.

Fichiers de sortie obligatoires :

- `results/gene_ranking.csv`
- `results/variants_hcm.csv`
- `results/excluded_conflicting_variants.csv`
- `results/summary.json`
- `results/top_genes.png`

## Etudiant 4 - environnement et administration

Fichiers a creer :

- `requirements.txt` ou `environment.yml`
- `cron/clinvar_pipeline.cron`
- une section technique a transmettre pour le README

Travail demande : verifier l'installation sur une machine propre, documenter
la tache planifiee, verifier les journaux dans `logs/`, les scripts executables
et les donnees brutes en lecture seule.

## Etudiant 5 - documentation et validation utilisateur

Fichiers a creer :

- `README.md`
- brouillon du rapport et support de presentation

Le README doit expliquer l'installation, `./run.sh -h`, un lancement complet,
les dossiers et chaque fichier produit. L'etudiant 5 doit ensuite tester le
projet en suivant uniquement ce README et signaler toute etape implicite.

## Integration finale

Quand les quatre livrables sont remis, l'etudiant 1 execute :

```bash
./run.sh -h
./run.sh -n
./run.sh
```

Il verifie ensuite les cinq fichiers de resultats, le journal, l'archive datee
et le test automatique avant de fixer le commit final.
