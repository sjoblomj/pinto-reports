# pinto-reports
Scripts to turn [beancount files](https://beancount.github.io/) into PDF reports using [Typst](https://typst.app/).

## What is included?

- Sample Beancount file for a made up association.
- Scripts to turn the beancount data into PDF reports using Typst.
- Scripts to turn the beancount data into JSON format for importing elsewhere.

## Usage

Modify config.yaml and then run `./generate-reports`.

A config file elsewhere can be given as an argument: `./generate-reports path/to/config.yaml`. Paths in the config file are relative to the directory of the config file, and the reports are written to the directory `reports` there. That way, the bookkeeping can be kept apart from these scripts.

The organisation number and the logo of the reports are set with `organisation-number` and `logo` in config.yaml. Without an organisation number, that line is left out of the reports. The rest of the look (currency, number formatting, fonts) is configured at the top of `report-scripts/report.typ`.

Notes in config.yaml are written in Typst markup. In addition, `$123.45$` is formatted as an amount, and `@1920@` is replaced by the name of that account.

### Period and opening balance

The reports cover the period from `start-of-period` to `end-of-period` in config.yaml. The opening balance of an account is everything booked on it before the start of the period, together with the transactions tagged `#opening-balance` on the first day of the period, if there are any. A ledger can thus either start with a transaction tagged `#opening-balance` (as `example.beancount` does), or contain the earlier years as well - but not both.

Other transactions on the first day of the period are part of the period.

### Verification numbers

The verification number of a transaction is taken from its `id` metadata: it is the first part of the id that is a number, when the id is split on underscores (`nordea_16_2025-01-31_1038` is verification 16). Only the transactions of the period are numbered. Transactions without an id get number 0 (e.g. the opening of the year), except the transaction closing the year (the one booking the result on 8999), which continues the numbering. A transaction thus has the same number whatever the period of the reports is. No reports are generated if two transactions get the same number, and there is a warning if more than one transaction gets number 0.

### Closing the year

The year is closed in the beancount file, by booking the result between accounts 2069 and 8999 (see the end of `example.beancount`). Before any reports are made, it is checked that the amount booked on 8999 is the same as the result according to the income and expenses, and that the balance report balances. If not, no reports are generated. If nothing is booked on 8999 in the period, there is only a warning, so that reports can be made during the year. The result that is not booked yet is then shown as a row of its own in the balance report, so that it balances. The row is named "Beräknat resultat", which can be changed with `calculated-result` in the config of the balance report.

## Tests

`tests/run-tests` generates reports from `example.beancount` and compares their data with the expected data in `tests/expected`. It also checks that ledgers and config files with mistakes are caught. After a change that is meant to change the reports, update the expected data with `tests/run-tests --update` and look through the changes with `git diff`.

## Limitations

The scripts are made with the assumption that [BAS](https://en.wikipedia.org/wiki/BAS_(accounting)) will be used. It should be fairly trivial to change this assumption to work with any account naming strategies though.

The first part of an account name must match its account number: `Assets` for 1xxx, `Liabilities` for 2xxx (equity included), and `Income` or `Expenses` for 3xxx-8xxx. No reports are generated otherwise.

All amounts in the ledger must be in the same currency.

## Required software

- beancount
- jq
- yq
- typst
- bash

## Acknowledgements
The layout of the Typst template (`report-scripts/report.typ`) is based on the [Minimal Invoice Template](https://www.latextemplates.com/template/minimal-invoice) from latextemplates.com
