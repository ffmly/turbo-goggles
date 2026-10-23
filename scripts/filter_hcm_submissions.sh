#!/usr/bin/env bash

set -Eeuo pipefail
export LC_ALL=C

usage() {
    printf 'Usage: %s submission_summary.txt.gz output.tsv\n' "$(basename "$0")"
}

[[ $# -eq 2 ]] || { usage >&2; exit 2; }

input_file="$1"
output_file="$2"

[[ -f "$input_file" ]] || { printf 'Fichier introuvable: %s\n' "$input_file" >&2; exit 1; }
[[ "$input_file" == *.gz ]] || { printf 'Le fichier source doit etre au format .gz\n' >&2; exit 1; }

output_dir="$(dirname "$output_file")"
mkdir -p "$output_dir"
body_file="$(mktemp "${TMPDIR:-/tmp}/hcm-filter.XXXXXX")"

cleanup() {
    rm -f -- "$body_file"
}
trap cleanup EXIT INT TERM HUP

# Pipeline Shell impose: decompression | selection AWK | tri | suppression des doublons.
# La selection se fait sur les champs de condition d'une soumission, et non sur
# PhenotypeList dans variant_summary.
gzip -cd "$input_file" \
    | awk -F '\t' -v OFS='\t' '
        /^##/ { next }

        $1 == "#VariationID" {
            for (i = 1; i <= NF; i++) index_of[$i] = i

            required[1] = "#VariationID"
            required[2] = "ClinicalSignificance"
            required[3] = "SubmittedPhenotypeInfo"
            required[4] = "ReportedPhenotypeInfo"
            required[5] = "ReviewStatus"
            required[6] = "OriginCounts"
            required[7] = "SCV"
            required[8] = "SubmittedGeneSymbol"
            required[9] = "ContributesToAggregateClassification"

            for (j = 1; j <= 9; j++) {
                if (!(required[j] in index_of)) {
                    print "Colonne manquante: " required[j] > "/dev/stderr"
                    exit 3
                }
            }
            header_seen = 1
            next
        }

        header_seen && NF > 1 {
            submitted = $(index_of["SubmittedPhenotypeInfo"])
            reported = $(index_of["ReportedPhenotypeInfo"])
            condition = tolower(submitted "|" reported)

            if (condition ~ /hypertrophic[[:space:]-]+cardiomyopathy/ ||
                condition ~ /cardiomyopathy[^|;\t]*hypertrophic/) {
                print \
                    $(index_of["#VariationID"]), \
                    $(index_of["ClinicalSignificance"]), \
                    submitted, \
                    reported, \
                    $(index_of["ReviewStatus"]), \
                    $(index_of["OriginCounts"]), \
                    $(index_of["SCV"]), \
                    $(index_of["SubmittedGeneSymbol"]), \
                    $(index_of["ContributesToAggregateClassification"])
            }
        }

        END {
            if (!header_seen) {
                print "En-tete ClinVar introuvable" > "/dev/stderr"
                exit 4
            }
        }
    ' \
    | sort -t $'\t' -k1,1n -k7,7 \
    | uniq > "$body_file"

printf '%s\n' $'VariationID\tClinicalSignificance\tSubmittedPhenotypeInfo\tReportedPhenotypeInfo\tReviewStatus\tOriginCounts\tSCV\tSubmittedGeneSymbol\tContributesToAggregateClassification' > "$output_file"
cat "$body_file" >> "$output_file"

row_count="$(awk 'END { print NR - 1 }' "$output_file")"
printf 'Soumissions HCM conservees: %s\n' "$row_count"
