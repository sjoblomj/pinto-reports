#!/bin/bash

# Checks that the config file has what is needed to make the reports, and
# exits with a message about what is wrong otherwise.
function check_config() {
  local config_file="$1"
  local errors=()
  local key value report

  for key in start-of-period end-of-period ledger account-mappings; do
    value=$(yq ".$key // \"\"" "$config_file")
    if [ -z "$value" ]; then
      errors+=("\"$key\" is missing.")
    fi
  done

  for key in start-of-period end-of-period; do
    value=$(yq ".$key // \"\"" "$config_file")
    if [ -n "$value" ] && ! date -d "$value" +%F 2> /dev/null | grep -qx -- "$value"; then
      errors+=("\"$key\" is not a date on the form YYYY-MM-DD: $value")
    fi
  done

  for key in ledger account-mappings logo; do
    value=$(yq ".$key // \"\"" "$config_file")
    if [ -n "$value" ] && [ ! -f "$value" ]; then
      errors+=("The file given as \"$key\" does not exist: $value")
    fi
  done

  if [ ${#errors[@]} -eq 0 ] && [[ "$(yq '.start-of-period' "$config_file")" > "$(yq '.end-of-period' "$config_file")" ]]; then
    errors+=("\"start-of-period\" is after \"end-of-period\".")
  fi

  if [ "$(yq -oj '.unused-verification-numbers // [] | (type == "!!seq" and all_c(type == "!!int"))' "$config_file")" != "true" ]; then
    errors+=("\"unused-verification-numbers\" is not a list of numbers.")
  fi

  if [ "$(yq '.reports-to-generate | length' "$config_file")" -eq 0 ]; then
    errors+=("\"reports-to-generate\" is missing or empty.")
  fi
  for report in $(yq -r '.reports-to-generate // [] | .[]' "$config_file"); do
    case "$report" in
      balansrapport|resultatrapport|verifikationslista|huvudbok) ;;
      *) errors+=("Unknown report in \"reports-to-generate\": $report") ;;
    esac
  done

  if [ ${#errors[@]} -gt 0 ]; then
    echo "Error in $config_file:" >&2
    printf '  %s\n' "${errors[@]}" >&2
    return 1
  fi
}

# Checks that the year has been closed correctly in the ledger, i.e. that
# the result booked on the closing account is the same as the result in the result
# report, and that the balance report balances. Uses the same selections of
# the ledger as the reports do. Expects transactions.sh to be sourced.
#
#   - The year is closed, but with another amount than the result: error.
#   - The balance report doesn't balance: error.
#   - The year hasn't been closed yet: a warning only, so that reports can
#     be made during the year.
function check_year_end() {
  local ledger_file="$1"
  local start_of_period="$2"
  local end_of_period="$3"
  local result_accounts balance_accounts closing messages earlier opening

  # An opening balance transaction would be counted on top of the balances from the earlier years
  earlier=$(query_ledger "$ledger_file" "SELECT count(*) AS postings WHERE date < $start_of_period" | jq "$TO_NUMBER"' map(.postings | to_number) | add // 0')
  opening=$(query_ledger "$ledger_file" "SELECT count(*) AS postings WHERE $(opening_transaction_condition "$start_of_period")" | jq "$TO_NUMBER"' map(.postings | to_number) | add // 0')
  if [ "$earlier" -gt 0 ] && [ "$opening" -gt 0 ]; then
    echo "Error: $ledger_file has both transactions before $start_of_period and a transaction tagged #opening-balance on that date. The opening balance is the sum of those, so remove one of them." >&2
    return 1
  fi
  if [ "$earlier" -eq 0 ] && [ "$opening" -eq 0 ]; then
    echo "Warning: $ledger_file has no transaction tagged #opening-balance on $start_of_period, and nothing before that date. All opening balances will be zero." >&2
  fi


  # Everything up until the end of the period, so that the checks also work for a part of a year
  result_accounts=$(query_ledger "$ledger_file" "SELECT account, sum(number) AS amount WHERE date <= $end_of_period AND account ~ '$RESULT_ACCOUNTS' ORDER BY account")
  balance_accounts=$(query_ledger "$ledger_file" "SELECT account, sum(number) AS amount WHERE date <= $end_of_period AND account ~ '$BALANCE_ACCOUNTS' ORDER BY account")
  closing=$(query_ledger "$ledger_file" "SELECT account, sum(number) AS amount WHERE $(period_condition "$start_of_period" "$end_of_period") AND account ~ '^$CLOSING_ACCOUNT' ORDER BY account")

  messages=$(jq -rn --arg closing_account "$CLOSING_ACCOUNT" --arg opening_balance_account "$OPENING_BALANCE_ACCOUNT" --argjson result_accounts "$result_accounts" --argjson balance_accounts "$balance_accounts" --argjson closing "$closing" '
    def total: map(.amount | tonumber) | add // 0;
    def cents: . * 100 | round;
    def money: cents as $c
      | (if $c < 0 then "-" else "" end)
        + (($c | fabs) / 100 | floor | tostring) + "."
        + (($c | fabs) % 100 | tostring | if length < 2 then "0" + . else . end);

    ($closing | length > 0) as $closed
    | ($closing | total) as $booked
    # The result that is not booked on the closing account. Zero when the year is closed correctly.
    | ($result_accounts | total * -1) as $unbooked
    | ($balance_accounts | total) as $balance

    | (if $closed and ($unbooked | cents) != 0 then
        "Error: the result booked on \($closing_account) in the period is \($booked | money), but it should be \($booked + $unbooked | money) according to the income and expenses. The difference is \($unbooked * -1 | money)."
      elif ($closed | not) and ($unbooked | cents) != 0 then
        "Warning: the year has not been closed - nothing is booked on \($closing_account) in the period. The result that is not booked is \($unbooked | money), which is shown as a calculated result in the balance report."
      else empty end),
      (if ($balance - $unbooked | cents) != 0 then
        "Error: the balance report does not balance - it is off by \($balance - $unbooked | money). Is something booked on an account that is not in the reports (e.g. \($opening_balance_account))?"
      else empty end)')

  if [ -n "$messages" ]; then
    echo "$messages" >&2
  fi
  if echo "$messages" | grep -q '^Error:'; then
    return 1
  fi
}

# Checks the verification numbers of the period (see get_transaction_list):
#   - Several transactions with the same number: error.
#   - Several transactions without an id that get number 0: a warning, since
#     only the opening of the year is expected to lack an id.
#   - Numbers that are missing between the first and the last number of the
#     period: a warning, since the numbers are to be an unbroken series. The
#     numbers in the given JSON array are known to be unused, and are not
#     warned about.
function check_verification_numbers() {
  local ledger_file="$1"
  local start_of_period="$2"
  local end_of_period="$3"
  local unused_numbers="${4:-[]}"
  local messages

  messages=$(get_transaction_list "$ledger_file" "$start_of_period" "$end_of_period" |
    jq -r --argjson unused "$unused_numbers" '
      # [8, 9, 10, 14] -> "8-10, 14"
      def ranges: reduce .[] as $n ([];
          if length > 0 and last[1] + 1 == $n then last[1] = $n else . + [[$n, $n]] end)
        | map(if .[0] == .[1] then "\(.[0])" else "\(.[0])-\(.[1])" end) | join(", ");

      def describe: map("  \(.date) \(.description)" + (if .id then " (id: \(.id))" else "" end)) | join("\n");

      [group_by(.seq)[] | first] as $transactions
      | ($transactions | map(select(.vernr != 0)) | group_by(.vernr) | map(select(length > 1))) as $duplicates
      | ($transactions | map(select(.vernr == 0))) as $unnumbered
      | ($transactions | map(.vernr | select(. != 0)) | unique) as $numbers
      | (if ($numbers | length) > 0 then [range($numbers[0]; $numbers[-1])] - $numbers - $unused else [] end) as $missing
      | ($duplicates[] | "Error: several transactions have verification number \(.[0].vernr):\n" + describe),
        (if ($missing | length) > 0 then
          "Warning: there are no transactions with these verification numbers: \($missing | ranges). If that is as it should be, list them as \"unused-verification-numbers\" in the config file."
        else empty end),
        (if ($unnumbered | length) > 1 then
          "Warning: several transactions have no id, and get verification number 0:\n" + ($unnumbered | describe)
        else empty end)')

  if [ -n "$messages" ]; then
    echo "$messages" >&2
  fi
  if echo "$messages" | grep -q '^Error:'; then
    return 1
  fi
}

# The reports sum the amounts without regard to their currency, so the
# ledger can only have one.
function check_single_currency() {
  local ledger_file="$1"
  local currencies
  currencies=$(query_ledger "$ledger_file" "SELECT DISTINCT currency ORDER BY currency" | jq -r 'map(.currency) | join(", ")')
  if [[ "$currencies" == *,* ]]; then
    echo "Error: $ledger_file has several currencies ($currencies), but the reports can only handle one." >&2
    return 1
  fi
}
