/*
    filename: compiler_hw1.l
*/

/* Definition section */
%{
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>

    #define YY_NO_UNPUT
    #define YY_NO_INPUT
    #define print_token(token) \
        printf("%-8s \t %s\n", strcmp(token, "NEWLINE")? yytext: "", token)
	/* Delimiters */
	#define LPAREN 		100
	#define RPAREN		101
	#define LBRACK		102
	#define RBRACK		103
	#define	LBRACE		104
	#define RBRACE		105
	#define SEMICOLON	106
	#define COMMA		107
	#define QUOTA		108
	#define NEWLINE		109
	#define COLON		110

	/* Arithmetic, Relational, Logical Operators */
	#define ADD			200
	#define SUB			201
	#define MUL			202
	#define QUO			203
	#define	REM			204
	#define	INC			205
	#define	DEC			206
	//Relational
	#define GTR			210
	#define	LSS			211
	#define	GEQ			212
	#define	LEQ			213
	#define	EQL			214
	#define	NEQ			215
	//Assign
	#define ASSIGN		220
	#define ADD_ASSIGN	221
	#define SUB_ASSIGN	222
	#define MUL_ASSIGN	223
	#define	QUO_ASSIGN	224
	#define REM_ASSIGN	225
	//Logical
	#define LAND		230
	#define LOR			231
	#define NOT			232

	/* Keywords */
	#define	INT_LIT		300
	#define	FLOAT_LIT	301
	#define STRING_LIT	302
	#define IDENT		303
	#define COMMENT		304
	
	#define	PRINT		310
	#define PRINTLN		311
	#define	IF			312
	#define	ELSE		313
	#define	FOR			314
	#define	INT			315
	#define	FLOAT		316
	#define	STRING		317
	#define	BOOL		318
	#define	TRUE		319
	#define	FALSE		320
	#define	VAR			321
	#define FUNC		322
	#define	PACKAGE		323
	#define	RETURN		324
	#define SWITCH		325
	#define CASE		326
	#define	DEFAULT		327
    int line_num = 0;
    int comment_num = 0;
    int last_comment_line = -1;
%}


/* Define regular expression label */
letter [a-zA-Z_]
digit [0-9]
id {letter}+({letter}|{digit})*
inumber {digit}+
fnumber ({digit}*\.{digit}+)
string \"([^"]|\"\")*\"
cppcomment  \/\/.+

%x C_COMMENT



/* Rules section */
%%
"+"         { print_token("ADD"); } 
"-"         { print_token("SUB"); } 
"*"			{ print_token("MUL"); }
"\/"		{ print_token("QUO"); } 
"%"         { print_token("REM"); } 
"++"        { print_token("INC"); } 
"--"		{ print_token("DEC"); }
">"         { print_token("GTR"); } 
"<"         { print_token("LSS"); } 
">="		{ print_token("GEQ"); }
"<="        { print_token("LEQ"); } 
"=="        { print_token("EQL"); } 
"!="		{ print_token("NEQ"); }
"="			{ print_token("ASSIGN"); }
"+="		{ print_token("ADD_ASSIGN"); }
"-="		{ print_token("SUB_ASSIGN"); }
"*="		{ print_token("MUL_ASSIGN"); }
"/="		{ print_token("QUO_ASSIGN"); }
"%="		{ print_token("REM_ASSIGN"); }
"&&"		{ print_token("LAND"); }
"||"		{ print_token("LOR"); }
"!"			{ print_token("NOT"); }
"("			{ print_token("LPAREN"); }
")"			{ print_token("RPAREN"); }
"["			{ print_token("LBRACK"); }
"]"			{ print_token("RBRACK"); }
"{"			{ print_token("LBRACE"); }
"}"			{ print_token("RBRACE"); }
";"			{ print_token("SEMICOLON"); }
","			{ print_token("COMMA"); }
"\n"		{ print_token("NEWLINE"); line_num++;}
":"			{ print_token("COLON"); }
"print"		{ print_token("PRINT"); }
"println"	{ print_token("PRINTLN"); }
"if"		{ print_token("IF"); }
"else"		{ print_token("ELSE"); }
"for"		{ print_token("FOR"); }
"int32"		{ print_token("INT"); }
"float32"	{ print_token("FLOAT"); }
"string"	{ print_token("STRING"); }
"bool"		{ print_token("BOOL"); }
"true"		{ print_token("TRUE"); }
"false"		{ print_token("FALSE"); }
"var"		{ print_token("VAR"); }
"func"		{ print_token("FUNC"); }

"package"	{ print_token("PACKAGE"); }
"return"	{ print_token("RETURN"); }
"switch"	{ print_token("SWITCH"); }
"case"		{ print_token("CASE"); }
"default"	{ print_token("DEFAULT"); }
{inumber}   { print_token("INT_LIT"); }
{fnumber}   { print_token("FLOAT_LIT"); }
{string}    { 
              printf("%-8s \t %s\n", "\"", "QUOTA");
              yytext[strlen(yytext) - 1] = '\0';
              printf("%-8s \t %s\n", &yytext[1], "STRING_LIT");
              printf("%-8s \t %s\n", "\"", "QUOTA");
            }

{id}        { print_token("IDENT"); }
"/*"                      { printf("%s" , yytext); BEGIN C_COMMENT; }
<C_COMMENT>"*/"           { print_token("C Comment"); BEGIN 0; comment_num++; }
<C_COMMENT>"\n"           { print_token("C Comment"); comment_num++; line_num++; }
<C_COMMENT>.              { printf("%s" , yytext); }
{cppcomment}   { print_token("C++ Comment"); comment_num++;}
<<EOF>>		{ line_num++; yyterminate(); }
.           {;}
%%

/*  C Code section */
int yywrap(void)
{
    return 1;
}

int main(int argc, char *argv[])
{
    if (argc == 2) {
        yyin = fopen(argv[1], "r");
    } else {
        yyin = stdin;
    }
    yylex();
    printf("\nFinish scanning,\n");
    printf("total line: %d\n", line_num);
    printf("comment line: %d\n", comment_num);
    fclose(yyin);
    return 0;
}
