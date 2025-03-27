# pinto-reports
Scripts to turn [beancount files](https://beancount.github.io/) into LaTeX reports.

## What is included?

- Sample Beancount file for a made up association.
- Scripts to turn the beancount data into PDF reports using LaTeX.
- Scripts to turn the beancount data into JSON format for importing elsewhere.

## Usage

Modify config.yaml and then run `./generate-reports`.

## Limitations

The scripts are made with the assumption that [BAS](https://en.wikipedia.org/wiki/BAS_(accounting)) will be used. It should be fairly trivial to change this assumption to work with any account naming strategies though.

## Required software

- beancount
- jq
- yq
- latex
- bash

## Acknowledgements
The LaTeX template is a modified version of the [Minimal Invoice Template](https://www.latextemplates.com/template/minimal-invoice) from latextemplates.com
