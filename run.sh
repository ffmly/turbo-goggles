#!/usr/bin/env bash

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DEFAULT_CONFIG="$PROJECT_ROOT/config/dataset.env"
readonly RAW_DIR="$PROJECT_ROOT/data/raw"
readonly PROCESSED_DIR="$PROJECT_ROOT/data/processed"
readonly RESULTS_DIR="$PROJECT_ROOT/results"
readonly LOG_DIR="$PROJECT_ROOT/logs"
readonly TMP_ROOT="$PROJECT_ROOT/tmp"

CONFIG_FILE="$DEFAULT_CONFIG"
TOP_N=15
FORCE_DOWNLOAD=0
DRY_RUN=0
TEMP_DIR=""
LOG_FILE=""
PYTHON_CMD=""

usage() {
    cat <<'EOF'
Usage: ./run.sh [options]

Pipeline ClinVar - cardiomyopathie hypertrophique.

Options:
  -c FILE   Fichier de configuration (defaut: config/dataset.env)
  -t N      Nombre de genes dans la figure finale (defaut: 15)
  -f        Retelercharger les donnees meme si elles existent deja
  -n        Afficher le plan d'execution sans telecharger ni analyser
  -h        Afficher cette aide

Exemples:
  ./run.sh -h
  ./run.sh -n
  ./run.sh -t 20
EOF
}

log() {
    local level="$1"
    shift
    printf '[%s] [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$*"
}

die() {
    log "ERREUR" "$*" >&2
    exit 1
}

cleanup() {
    local exit_code=$?
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf -- "$TEMP_DIR"
    fi
    if (( exit_code != 0 )); then
        log "ERREUR" "Pipeline interrompu (code $exit_code). Consultez le journal: ${LOG_FILE:-non cree}." >&2
    fi
    exit "$exit_code"
}

on_signal() {
    log "ERREUR" "Signal recu; nettoyage des fichiers temporaires."
    exit 130
}

require_command() {
    local command_name="$1"
    command -v "$command_name" >/dev/null 2>&1 || die "Commande requise introuvable: $command_name"
}

resolve_python() {
    if [[ -n "${PYTHON_BIN:-}" ]]; then
        command -v "$PYTHON_BIN" >/dev/null 2>&1 || die "Interpreteur Python introuvable: $PYTHON_BIN"
        "$PYTHON_BIN" --version >/dev/null 2>&1 || die "Interpreteur Python inutilisable: $PYTHON_BIN"
        PYTHON_CMD="$PYTHON_BIN"
    elif command -v python3 >/dev/null 2>&1 && python3 --version >/dev/null 2>&1; then
        PYTHON_CMD="python3"
    elif command -v python >/dev/null 2>&1 && python --version >/dev/null 2>&1; then
        PYTHON_CMD="python"
    else
        die "Python 3 est requis mais aucun interpreteur utilisable n'a ete trouve."
    fi
}

ensure_directories() {
    mkdir -p "$RAW_DIR" "$PROCESSED_DIR" "$RESULTS_DIR" "$LOG_DIR" "$TMP_ROOT"
    TEMP_DIR="$(mktemp -d "$TMP_ROOT/run.XXXXXX")"
}

load_config() {
    [[ -f "$CONFIG_FILE" ]] || die "Fichier de configuration introuvable: $CONFIG_FILE"

    # shellcheck disable=SC1090
    source "$CONFIG_FILE"

    local required_vars=(
        CLINVAR_RELEASE
        SUBMISSION_FILENAME SUBMISSION_URL SUBMISSION_SHA256
    )
    local variable
    for variable in "${required_vars[@]}"; do
        [[ -n "${!variable:-}" ]] || die "Variable vide dans la configuration: $variable"
    done
}

validate_config_ready() {
    [[ "$SUBMISSION_SHA256" != TODO_* ]] || die "SUBMISSION_SHA256 doit etre complete par l'etudiant 2 dans config/dataset.env."
    [[ "$SUBMISSION_SHA256" =~ ^[[:xdigit:]]{64}$ ]] || die "SUBMISSION_SHA256 doit contenir exactement 64 caracteres hexadecimaux."
}

validate_positive_integer() {
    [[ "$TOP_N" =~ ^[1-9][0-9]*$ ]] || die "L'option -t attend un entier strictement positif."
}

sha256_of() {
    local file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | awk '{print $1}'
    else
        die "Impossible de calculer SHA-256: installez sha256sum ou shasum."
    fi
}

verify_file() {
    local file="$1"
    local expected_sha="$2"
    local actual_sha

    [[ -f "$file" ]] || die "Fichier manquant: $file"
    [[ "$expected_sha" != TODO_* ]] || die "Empreinte SHA-256 non renseignee pour $(basename "$file"). L'etudiant 2 doit completer config/dataset.env."

    actual_sha="$(sha256_of "$file")"
    [[ "${actual_sha,,}" == "${expected_sha,,}" ]] || die "Somme SHA-256 incorrecte pour $(basename "$file")."
    gzip -t "$file" || die "Archive gzip invalide: $file"
    log "OK" "Integrite verifiee: $(basename "$file")"
}

download_file() {
    local url="$1"
    local destination="$2"
    local expected_sha="$3"
    local partial="$destination.part"

    if [[ -f "$destination" && "$FORCE_DOWNLOAD" -eq 0 ]]; then
        log "INFO" "Fichier deja present: $(basename "$destination")"
        verify_file "$destination" "$expected_sha"
        return
    fi

    if [[ -f "$destination" ]]; then
        chmod u+w "$destination" 2>/dev/null || true
        rm -f -- "$destination"
    fi
    rm -f -- "$partial"
    log "INFO" "Telechargement de $(basename "$destination")"
    curl --fail --location --retry 3 --retry-delay 5 \
        --output "$partial" "$url"
    mv -- "$partial" "$destination"
    verify_file "$destination" "$expected_sha"
    chmod a-w "$destination"
}

run_shell_filter() {
    local submission_file="$1"
    local filtered_file="$PROCESSED_DIR/hcm_submissions.tsv"

    log "INFO" "Filtrage des soumissions associees a la cardiomyopathie hypertrophique"
    "$PROJECT_ROOT/scripts/filter_hcm_submissions.sh" \
        "$submission_file" "$filtered_file"
    [[ -s "$filtered_file" ]] || die "Le filtrage n'a produit aucune donnee."
}

run_python_analysis() {
    local analysis_script="$PROJECT_ROOT/scripts/analyze_genes.py"
    local filtered_file="$PROCESSED_DIR/hcm_submissions.tsv"

    [[ -f "$analysis_script" ]] || die "Analyse Python manquante: scripts/analyze_genes.py (livrable de l'etudiant 3)."

    log "INFO" "Analyse Python et creation des resultats"
    "$PYTHON_CMD" "$analysis_script" \
        --submissions "$filtered_file" \
        --output-dir "$RESULTS_DIR" \
        --top "$TOP_N"
}

archive_results() {
    local timestamp archive
    local expected_outputs=(
        gene_ranking.csv
        variants_hcm.csv
        excluded_conflicting_variants.csv
        summary.json
        top_genes.png
    )
    local output

    for output in "${expected_outputs[@]}"; do
        [[ -s "$RESULTS_DIR/$output" ]] || die "Resultat attendu manquant: results/$output"
    done

    timestamp="$(date '+%Y%m%d_%H%M%S')"
    archive="$RESULTS_DIR/resultats_${timestamp}.tar.gz"
    tar -czf "$archive" -C "$RESULTS_DIR" "${expected_outputs[@]}"
    log "OK" "Resultats archives: $archive"
}

print_plan() {
    cat <<EOF
Version ClinVar : $CLINVAR_RELEASE
Configuration   : $CONFIG_FILE
Donnees         :
  - $SUBMISSION_URL
Etapes          : telechargement -> verification -> filtrage Shell -> analyse Python -> archive
Top genes       : $TOP_N
EOF
}

while getopts ":c:t:fnh" option; do
    case "$option" in
        c) CONFIG_FILE="$OPTARG" ;;
        t) TOP_N="$OPTARG" ;;
        f) FORCE_DOWNLOAD=1 ;;
        n) DRY_RUN=1 ;;
        h) usage; exit 0 ;;
        :) die "L'option -$OPTARG exige une valeur." ;;
        \?) die "Option inconnue: -$OPTARG. Utilisez -h pour l'aide." ;;
    esac
done

shift $((OPTIND - 1))
(( $# == 0 )) || die "Argument inattendu: $1"

trap cleanup EXIT
trap on_signal INT TERM HUP

validate_positive_integer
load_config

if (( DRY_RUN == 1 )); then
    print_plan
    exit 0
fi

validate_config_ready
ensure_directories
LOG_FILE="$LOG_DIR/run_$(date '+%Y%m%d_%H%M%S').log"
exec > >(tee -a "$LOG_FILE") 2>&1

require_command curl
require_command gzip
require_command awk
require_command sort
require_command uniq
require_command tar
require_command tee
require_command mktemp
resolve_python

log "INFO" "Demarrage du pipeline ClinVar $CLINVAR_RELEASE"

submission_path="$RAW_DIR/$SUBMISSION_FILENAME"

download_file "$SUBMISSION_URL" "$submission_path" "$SUBMISSION_SHA256"
run_shell_filter "$submission_path"
run_python_analysis
archive_results

log "OK" "Pipeline termine avec succes."
