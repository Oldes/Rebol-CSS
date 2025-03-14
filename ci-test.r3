Rebol [title: "CSS Test script"]

;; make sure that we load a fresh extension
try [system/modules/css: none unset 'css-minify unset 'css-tokenize]
try [system/codecs/css:  none]
;; use current directory as a modules location
system/options/modules: what-dir

import css
test-css: function[css [file! binary! url! string!]][
	case [
		any [file? css url? css] [css: read/string css]
		binary? css [css: to string! css]
	]
	css: deline css
	num: 0
	failed: 0
	parse css [
		opt [any [SP | CR | LF | TAB] "<!--" some #"-" #">"]
		any [
		copy src: to "^/<!--==-->" thru #">" any [SP | CR | LF | TAB]
		copy exp: to ["^/<!---"] thru #">" any [SP | CR | LF | TAB]
		(
			++ num
			tokens: css-tokenize src
			res: css-minify tokens
			? res
			if res != exp [
				++ failed
				? exp
				print as-red "FAILED"
				?? src
				?? tokens
				print-horizontal-line
			]

		)
	]]
	print ["Tests done:" num]
	if failed > 0 [
		print ["Failed:" as-red failed]
		quit/return failed
	]
]

test-css read %tests.css

;system/options/log/http: 0
;
;print-horizontal-line
;print as-yellow "Minify external CSS..."
;print minified: css-minify https://rebol.tech/css/main.css
;print ["Original size:" size? https://rebol.tech/css/main.css ]
;print ["Minified size:" length? minified]
;print-horizontal-line
;probe  minified: encode 'css tokens
