#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "$SCRIPT_DIR"/account_mapping.sh
source "$SCRIPT_DIR"/typst.sh
source "$SCRIPT_DIR"/sheets.sh
source "$SCRIPT_DIR"/transactions.sh

config_file="$1"
start_of_period=$(     jq -r    '.["start-of-period"]' "$config_file")
end_of_period=$(       jq -r      '.["end-of-period"]' "$config_file")
ledger_file=$(         jq -r             '.["ledger"]' "$config_file")
account_mappings_src=$(jq -r   '.["account-mappings"]' "$config_file")
report_type=$(         jq -r        '.["report-type"] // "Balansrapport"' "$config_file")
report_output_file=$(  jq -r '.["report-output-file"]' "$config_file")
calculated_result=$(   jq -r '.["calculated-result"] // "Beräknat resultat"' "$config_file")

start_of_period_file=$(mktemp)
end_of_period_file=$(  mktemp)
report_file=$(         mktemp)
headers_file=$(        mktemp)
notes_file=$(          mktemp)
trap 'rm -f "$start_of_period_file" "$end_of_period_file" "$report_file" "$headers_file" "$notes_file"' EXIT

jq -r '.["report-headers"] // [] | map({"key": (keys | .[0]), "value": .[]})' "$config_file" > "$headers_file"
jq -c          '.["notes"] // [] | map({"key": (keys | .[0]), "value": .[]})' "$config_file" | parse_notes "$account_mappings_src" > "$notes_file"

# The result that has not been booked on the balance accounts yet, i.e. the income and expenses of
# a year that has not been closed. It is added as a row of its own among the liabilities, since
# the balance report doesn't balance without it. There is no such row when the amounts are zero.
function add_calculated_result() {
  local start_amount end_amount
  start_amount=$(query_ledger "$ledger_file" "SELECT sum(number) AS amount WHERE $(opening_condition "$start_of_period") AND account ~ '$RESULT_ACCOUNTS'" | jq 'map(.amount) | add // 0')
  end_amount=$(  query_ledger "$ledger_file" "SELECT sum(number) AS amount WHERE date <= $end_of_period AND account ~ '$RESULT_ACCOUNTS'" | jq 'map(.amount) | add // 0')

  jq --arg name "$calculated_result" --arg category "$LIABILITIES_ACCOUNT_TYPE" --slurpfile headers "$headers_file" --argjson start_amount "$start_amount" --argjson end_amount "$end_amount" '
    def cents: . * 100 | round;
    {
      "account": $name,
      "account_internal": null,
      "start_amount": ($start_amount | cents / 100),
      "end_amount": ($end_amount | cents / 100),
      "diff": (($end_amount | cents) - ($start_amount | cents) | . / 100),
      "note": ""
    } as $row
    | if $row.start_amount == 0 and $row.end_amount == 0 then .
      elif any(.[]; .category_num == $category) then
        map(if .category_num == $category then .accounts += [$row] else . end)
      else
        . + [{
          "category": (($headers[0] | map(select(.key == $category)) | first | .value) // $category),
          "category_num": $category,
          "accounts": [$row]
        }]
      end'
}

for startend in start end; do
  # Get ledger from start or end of period
  output_file="${startend}_of_period_file"
  if [ "$startend" = "start" ]; then
    condition=$(opening_condition "$start_of_period")
  else
    # The closing balance is everything up until the end of the period
    condition="date <= $end_of_period"
  fi
  query_ledger "$ledger_file" "SELECT account, sum(number) AS amount WHERE $condition AND account ~ '$BALANCE_ACCOUNTS' ORDER BY account" | jq "map(. + {\"${startend}_amount\": .amount} | del(.amount))" > "${!output_file}"
done

# Combine to one array
jq -s '.[0] + .[1]' "$start_of_period_file" "$end_of_period_file" > "$report_file"

# Group accounts together; explicitly set .start_amount and .end_amount if missing; filter away where both .start_amount and .end_amount == 0; calculate diff
jq '[group_by(.account)[] | add]' "$report_file" |
  jq 'map(. + {"start_amount": (if .start_amount == null then 0 else .start_amount end), "end_amount": (if .end_amount == null then 0 else .end_amount end)})
  | [.[] | select(.start_amount != 0 or .end_amount != 0)]
  | map(. + {"diff": (((.end_amount - .start_amount) * 100 | round) / 100)})' |
  create_json_sheet "$account_mappings_src" "$headers_file" "$notes_file" |
  add_calculated_result > "$report_output_file.json"
warn_about_unused_notes "$notes_file" "$report_output_file.json"

# Create Typst report
print_typst_report "$report_type" "balance-table" "$report_output_file.json"
