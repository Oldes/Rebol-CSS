Rebol [
	title: "CSS utilities"
	type: module
	name: css
	Date:    14-Mar-2025
	Version: 0.1.1
	Author:  @Oldes
	Home:    https://github.com/Oldes/Rebol-CSS
	Rights:  MIT
	Purpose: {Tokenize CSS content and minify it}
	Exports: [css-tokenize css-minify]
]

rules: context [
	;; bitsets
	*nonascii:  complement charset [0 - 177]
	*hexa:      charset [#"a"-#"f" #"A"-#"F" #"0"-#"9"]
	*notesc:    complement charset [#"a"-#"f" #"A"-#"F" #"0"-#"9" "^-^/^M^L"]
	*nmstart:   charset [#"_" #"a"-#"z" #"A"-#"Z"]
	*nmchar:    charset [#"_" #"a"-#"z" #"A"-#"Z" #"0"-#"9" #"-"]
	*num:       charset [#"0"-#"9"]
	*str:       complement charset "^/^M^L\"
	*n: charset "nN"
	*o: charset "oO"
	*t: charset "tT"
	*combinator: charset "+>~"
	*token-char: charset "{}:@;(),"
	*whitespace: charset " ^-^/^M^L"
	;; rules
	=escape:    [#"\" [*notesc | 1 6 *hexa]]
	=nmchar:    [some [*nmchar | *nonascii | =escape]]
	=number:    [opt [#"+" | #"-"] any *num #"." some *num | some *num]
	=newline:   [lf | crlf | cr | 12] ;= 12 = form feed char
	=str:       [*str | *nonascii | #"\" =newline | =escape]
	=string1:   [#"^"" some [#"^"" break | =str]]
	=string2:   [#"'"  some [#"'"  break | =str]]
	=string:    [=string1 | =string2]
	=invalid1:  [#"^"" any str]
	=invalid2:  [#"'" any str]
	=invalid:   [=invalid1 | =invalid2]
	=ws:        [any WHITESPACE]
	=nmstart:   [*nmstart | *nonascii | =escape]
	=name:      [some *nmchar]
	=ident:     [opt #"-" =nmstart any =nmchar]
	=hash: [#"#" =name] 
	=namespace_prefix: [opt [=ident | #"*"] #"|"]            ;; e.g. svg| in: svg|circle {...} 
	=type_selector:    [opt =namespace_prefix =ident]
	=universal:        [opt =namespace_prefix #"*"]
	=class:            [#"." =ident]
	=attrib: [
		#"[" =ws opt =namespace_prefix =ident =ws
		opt [
			[
				"^=" | ;; PREFIXMATCH
				"$=" | ;; SUFFIXMATCH
				"*=" | ;; SUBSTRINGMATCH
				#"=" |
				"~=" | ;; INCLUDES
				"|=" | ;; DASHMATCH
			] =ws [=ident | =string] =ws
		]
		#"]"
	]
	=pseudo: [#":" opt #":" [ =ident | functional_pseudo ]] ;; e.g. :hover or ::before
;	negation: [#":" *n *o *t #"(" =ws [=type_selector | =universal | =hash | =class | =attrib | =pseudo] =ws #")"]
;	simple_selector_sequence: [
;		;; A `simple_selector_sequence` is a sequence of simple selectors that are not separated
;		;; by combinators (like spaces, > , +, or ~). It always starts with a type selector or
;		;; a universal selector, and then can be followed by other simple selectors.
;		[=type_selector | =universal] ;; e.g. div or *
;		any [=hash | =class | =attrib | =pseudo | negation]
;		|
;		some [=hash | =class | =attrib | =pseudo | negation]
;	]
;	expression: [
;		some [ =ws [#"+" | #"-" | =number =ident | =number | =string | =ident] =ws ]
;	]
;	functional_pseudo: [
;		=ident #"(" =ws expression #")"
;	]
;	combinator: [=ws [#"+" | #">" | #"~"] =ws]
;	selector: [simple_selector_sequence any [ combinator simple_selector_sequence ]]
;	selectors_group: [selector any [ =ws #";" =ws selector]]
]

css-tokenize: function/with [
	;@@ https://www.w3.org/TR/css-syntax-3/#tokenizer-algorithms
	css [string! binary! url! file!]
][
	case [
		any [file? css url? css] [css: read/string css]
		binary? css [css: to string! css]
	]
	parse/case css [
		any *whitespace
		collect any [
			  "<!--" thru "-->"
			| "/*" thru "*/"
			| keep [
				  *token-char
				| *combinator
				| =string
				| =type_selector
				| =universal
				| =hash
				| =class
				| =attrib
				| =pseudo
				| =ident
			]
			| copy tmp: =number keep (transcode/one tmp) opt [keep ["%" | =name] ]
			| some *whitespace keep (SP)
			| keep skip
		]
	]
] :rules

css-minify: function [tokens][
	unless block? tokens [tokens: css-tokenize tokens]
	ajoin parse tokens [collect any [
		  #";" opt #" " ahead #"}" ;== removes ; in front of }
		| #"{" #" " keep (#"{")
		| #"}" #" " keep (#"}")
		| #":" #" " keep (#":")
		| #";" #" " keep (#";")
		| #"(" (expr?: on ) #" " keep (#"(")
		| #")" (expr?: off) #" " keep (#")")
		| #"," #" " keep (#",")
		| #" " [
			  ahead [#"{" | #"}" | #"(" | #")" | #":" | #";" | #","]
			| keep [#">" | #"~"] opt #" "
			| if (not expr?) keep #"+" opt #" "
			| end
		]
		| quote 0 [
			"ms" keep ("0s") |        ;== 0ms -> 0s
			[#"%" | string!] not #"," keep (0) ;== zero percent/dimension
		]
		| #"+" ahead number!
		| #"-" ahead quote 0
		;= and in a media query must be separated with a space
		| "and" #" " ahead #"(" keep ("and ")
		| keep skip
	]]
]

register-codec [
	name:  'css
	type:  'text
	title: "Cascading Style Sheets"
	suffixes: [%.css]

	decode: function [
		data [binary! file! url!]
	][
		css-tokenize data
	]
	encode: function[data [block!]][
		css-minify data
	]
]

