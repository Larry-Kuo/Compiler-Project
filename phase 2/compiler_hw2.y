/* Definition section */
%{
    #include "compiler_hw_common.h" //Extern variables that communicate with lex
    // #define YYDEBUG 1
    // int yydebug = 1;

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;
    int yylex_destroy ();
    void yyerror (char const *s)
    {
        printf("error:%d: %s\n", yylineno, s);
    }
    /* Symbol table function - you can add new functions if needed. */
    /* parameters and return type can be changed */
    static void create_symbol();
    static void insert_symbol(int, char*, char*);
    static char* lookup_symbol(char*);
    static void lookup_function(char*);
    static void dump_symbol();
    static void init_funcSig();
    static void append_funcSig(char*);
    static int Redeclaration(char *);
    /* Global variables */
    Symbol *SymbolTable[5];
    int addr = 0;
    int scope = -1;
    int table_index[5];
    bool HAS_ERROR = false;
    char *func_sig;
    int func_para_lineno = 0;
%}
%error-verbose

/* Use variable or self-defined structure to represent
 * nonterminal and token type
 *  - you can add new fields if needed.
 */
%union {
    int i_val;
    float f_val;
    char *s_val;
}

/* Token without return */
%token VAR NEWLINE
%token INT FLOAT BOOL STRING
%token INC DEC GEQ LOR LAND GTR LSS LEQ NEQ EQL
%token ADD_ASSIGN SUB_ASSIGN MUL_ASSIGN QUO_ASSIGN REM_ASSIGN
%token IF ELSE FOR SWITCH CASE DEFAULT 
%token PRINT PRINTLN PACKAGE FUNC RETURN 

/* Token with return, which need to sepcify type */
%token <i_val> INT_LIT
%token <f_val> FLOAT_LIT
%token <s_val> STRING_LIT BOOL_LIT
%token <s_val> IDENT
/* Nonterminal with return, which need to sepcify type */
%type <s_val> Type 
%type <s_val> Literal Operand ConversionExpression 
%type <s_val> cmp_op add_op mul_op unary_op
%type <s_val> assign_op  more_assign_op inc_dec
%type <s_val> Expression MulExpression CmpExpression UnaryExpression PrimaryExpression AddExpression
%type <s_val> AndExpression
%type <s_val> Condition
%type <s_val> LOR LAND

/* Yacc will start at this nonterminal */
%start Program

/* Grammar section */
%%

Program
    : {create_symbol();} 
    GlobalStatementList
    {dump_symbol();}
;

PackageStmt
    : PACKAGE IDENT {printf("package: %s\n", $2);}
;

GlobalStatementList 
    : GlobalStatementList GlobalStatement
    | GlobalStatement
;

GlobalStatement
    : PackageStmt NEWLINE
    | FunctionDeclStmt
    | NEWLINE
;

FunctionDeclStmt
    : FUNC IDENT {init_funcSig(); printf("func: %s\n", $2); create_symbol();} 
    FuncParameter ReturnType {printf("func_signature: %s\n", func_sig); insert_symbol(--scope, $2, "func");} FuncBlock
;

FuncParameter   
    : '(' ParameterList ')'
    | '(' ')'
;

ParameterList
    : ParameterList ',' Parameter
    | Parameter
;

Parameter
    : IDENT Type {
        if(strcmp($2,"int32")==0)   printf("param %s, type: I\n", $1);
        else if(strcmp($2, "float32")==0)   printf("param %s, type: F\n", $1);
        else    printf("error type: %s ", $2);
        append_funcSig($2);
        func_para_lineno=1;
        insert_symbol(scope, $1, $2);
        func_para_lineno=0;
        }
;

Type
    : STRING {$$ = strdup("string");}
    | BOOL {$$ = strdup("bool");}
    | INT {$$ = strdup("int32");} 
    | FLOAT {$$ = strdup("float32");}
;
//ReturnType -> non-terminal with return
ReturnType 
    : Type {append_funcSig(")"); append_funcSig($1);}
    | {append_funcSig(")"); append_funcSig("V");}
;

FuncBlock
    : '{' {scope++;} StatementList '}' {dump_symbol();}
;

StatementList
    : StatementList Statement
    | Statement
;

Statement
    : DeclarationStmt NEWLINE 
    | SimpleStmt NEWLINE 
    | Block 
    | IfStmt 
    | ForStmt 
    | SwitchStmt 
    | CaseStmt 
    | PrintStmt NEWLINE 
    | ReturnStmt NEWLINE 
    | NEWLINE
;

DeclarationStmt
    : VAR IDENT Type Assign 
    {
        if(Redeclaration($2)>0)
         printf("error:%d: %s redeclared in this block. previous declaration at line %d\n", yylineno, $2, Redeclaration($2));
        func_para_lineno = 0;
        insert_symbol(scope, $2, $3);
    }
        
;
// Used in declaration
Assign
    : '=' Expression | ;

SimpleStmt
    : AssignmentStmt | Expression | IncDecStmt 
;

AssignmentStmt
    : Expression assign_op Expression 
    {
        if(strcmp($1, $3)!=0){
        printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n", yylineno, $2, $1, $3);
        }
        printf("%s\n", $2);}
;

assign_op
    : '=' {$$ = strdup("ASSIGN");}
    | more_assign_op
;

more_assign_op
    : MUL_ASSIGN {$$ = strdup("MUL");}
    | QUO_ASSIGN {$$ = strdup("QUO");}
    | ADD_ASSIGN {$$ = strdup("ADD");}
    | REM_ASSIGN {$$ = strdup("REM");}
    | SUB_ASSIGN {$$ = strdup("SUB");}
;

IncDecStmt
    : Expression inc_dec {printf("%s\n", $2);}
;

inc_dec
    : INC {$$ = strdup("INC");}
    | DEC {$$ = strdup("DEC");}
;

Block
    : '{' {create_symbol();}
     StatementList '}' { dump_symbol();}
;
//If Statement
IfStmt
    : IF Condition Block ElseStmt
;

ElseStmt
    : ELSE IfStmt
    | ELSE Block
    |
;

Condition
    : Expression
    {  
        if (strcmp($1, "bool")!=0) {
            printf("error:%d: non-bool (type %s) used as for condition\n", yylineno + 1, $1);
        }
    } 
;

//For Statement
ForStmt
    : FOR  ForClause Block
;

ForClause
    : Condition
    | InitStmt ';' Condition ';' PostStmt
;

InitStmt
    : SimpleStmt
;

PostStmt
    : SimpleStmt
;

//Switch Statement
SwitchStmt
    : SWITCH Expression Block
;

CaseStmt
    : NumDefault ':' Block
;

NumDefault 
    : CASE INT_LIT {printf("case %d\n", $2);}
    | DEFAULT
;
//Print Statement
PrintStmt
    : PRINT '(' Expression ')' {printf("PRINT %s\n", $3);}
    | PRINTLN '(' Expression ')' {printf("PRINTLN %s\n", $3);}
;
//Return Statement
ReturnStmt
    : RETURN { printf("return\n");} 
    | RETURN Expression { printf("%creturn\n", $2[0]);}
;
//Expression
Expression
    : Expression LOR {$2 = strdup("LOR");} AndExpression
    {
        if(strcmp($1, "bool")!=0)
            printf("error:%d: invalid operation: (operator LOR not defined on %s)\n", yylineno, $1);
        else if(strcmp($4, "bool")!=0)
            printf("error:%d: invalid operation: (operator LOR not defined on %s)\n", yylineno, $4);
        printf("%s\n", $2);
        $$ = strdup("bool");
    }
    | AndExpression
;

AndExpression
    : AndExpression LAND {$2 = strdup("LAND");} CmpExpression
    {
        if(strcmp($1, "bool")!=0)
            printf("error:%d: invalid operation: (operator LAND not defined on %s)\n", yylineno, $1);
        else if(strcmp($4, "bool")!=0)
            printf("error:%d: invalid operation: (operator LAND not defined on %s)\n", yylineno, $4);
        printf("%s\n", $2);
        $$ = strdup("bool");
    }
    | CmpExpression
;

CmpExpression
    : CmpExpression cmp_op AddExpression
    {
        if(strcmp($1, $3)!=0){
        printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n", yylineno, $2, $1, $3);
        }
        printf("%s\n", $2);
        $$ = strdup("bool");
    }
    | AddExpression
;

AddExpression
    : AddExpression add_op MulExpression
    { 
        if(strcmp($1, $3)!=0){
        printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n", yylineno, $2, $1, $3);
        }
        printf("%s\n", $2);
    }
    | MulExpression
;

MulExpression
    : MulExpression mul_op UnaryExpression
    {
        if(strcmp($2,"REM")==0){
            if(strcmp($1, "int32")!=0 ||strcmp($3, "int32")!=0)
                printf("error:%d: invalid operation: (operator REM not defined on float32)\n", yylineno);
        }
        printf("%s\n", $2);
    }
    | UnaryExpression
;

UnaryExpression
    : unary_op UnaryExpression { 
        $$ = $2;
        printf("%s\n", $1);
    }
    | PrimaryExpression
;

PrimaryExpression
    : Operand {$$ = $1;}
    | FuncCall {$$ = strdup("int32");}
    | ConversionExpression
;

cmp_op
    : GEQ {$$ = strdup("GEQ");}
    | LEQ {$$ = strdup("LEQ");}
    | GTR {$$ = strdup("GTR");}
    | LSS {$$ = strdup("LSS");}
    | NEQ {$$ = strdup("NEQ");}
    | EQL {$$ = strdup("EQL");}
;

mul_op
    : '*' {$$ = strdup("MUL");}
    | '/' {$$ = strdup("QUO");}
    | '%' {$$ = strdup("REM");}
;

unary_op
    : '+' {$$ = strdup("POS");}
    | '-' {$$ = strdup("NEG");}
    | '!' {$$ = strdup("NOT");}
;

add_op
    : '+' {$$ = strdup("ADD"); }
    | '-' {$$ = strdup("SUB");}
;


Operand
    : Literal { $$ = $1; }
    | IDENT {$$ = lookup_symbol($1); }
    | '(' Expression ')' { $$ = $2; }
;

Literal
    : FLOAT_LIT {printf("FLOAT_LIT %f\n", $1); $$ = strdup("float32");}
    | INT_LIT  {printf("INT_LIT %d\n", $1); $$ = strdup("int32");}
    | '\"' STRING_LIT '\"' {printf("STRING_LIT %s\n", $2); $$ = strdup("string");}
    | BOOL_LIT {
        if(strcmp($1, "true")==0) printf("TRUE 1\n");
        else   printf("FALSE 0\n");
        $$ = strdup("bool");
    }
;

FuncCallParam
    : FuncCallParameters |
;

FuncCallParameter
    : Expression
;

FuncCallParameters
    : FuncCallParameter ',' FuncCallParameters | FuncCallParameter
;

FuncCall
    : IDENT '(' FuncCallParam ')' 
    { 
        lookup_function($1); }
;

ConversionExpression
    : Type '(' Expression ')' { printf("%c2%c\n", $3[0], $1[0]); }
;
%%

/* C code section */
int main(int argc, char *argv[])
{
    if (argc == 2) {
        yyin = fopen(argv[1], "r");
    } else {
        yyin = stdin;
    }
    for(int i=0; i<5; ++i){
        table_index[i] = 0;
        SymbolTable[i] = NULL;
    }
    yylineno = 0;
    yyparse();

	printf("Total lines: %d\n", yylineno);
    fclose(yyin);
    return 0;
}
//function signal
void init_funcSig(){
    //Initialize function signal to "("
    func_sig = realloc(func_sig, sizeof(char));
    strcpy(func_sig, "(");
}
void append_funcSig(char* type){
    //Append parameter type and return type
    func_sig = realloc(func_sig,sizeof(char)*strlen(func_sig)+1);
    if(strcmp(type, "int32")==0){
        strncat(func_sig, "I", strlen(func_sig)+1);
    }
    else if(strcmp(type, "float32")==0){
        strncat(func_sig, "F", strlen(func_sig)+1);
    }
    else{
        strncat(func_sig, type, strlen(func_sig)+strlen(type));
    }
}

static void create_symbol() {
    printf("> Create symbol table (scope level %d)\n", ++scope);
}

static void insert_symbol(int scope, char *name , char *type) {
    // Create a new row of symbol table
    Symbol *temp = (Symbol*) malloc(sizeof(Symbol));
    temp->Index = table_index[scope]++;
    temp->Name = malloc(sizeof(char)*strlen(name));
    strcpy(temp->Name, name);
    if(strcmp(type, "func")!=0){
        printf("> Insert `%s` (addr: %d) to scope level %d\n", name, addr, scope);
        temp->Type = malloc(sizeof(char)*strlen(type));
        strcpy(temp->Type, type);
        temp->FuncSig = malloc(sizeof(char)*strlen("-"));
        strcpy(temp->FuncSig, "-"); 
        temp->Addr = addr++;
        temp->Lineno = yylineno + func_para_lineno;
    }
    else{
        printf("> Insert `%s` (addr: -1) to scope level %d\n", name, scope);
        temp->Type = malloc(sizeof(char)*strlen(type));
        strcpy(temp->Type, type);
        temp->FuncSig = malloc(sizeof(char)*strlen(func_sig));
        strcpy(temp->FuncSig, func_sig);
        temp->Addr = -1;
        temp->Lineno = yylineno+1;
    }
    temp->next = NULL;
    // Insert it into the original symbol table
    if(SymbolTable[scope]){
        Symbol *ptr = SymbolTable[scope];
        while(ptr->next){
            ptr = ptr->next;
        }
        ptr->next = temp;
        temp->next = NULL;
    }
    else{
        SymbolTable[scope] = temp;
    }
}
static int Redeclaration(char *name){
    Symbol *ptr = SymbolTable[scope];
    while(ptr){
        if(strcmp(name, ptr->Name)==0){
            return ptr->Lineno;
        }
        ptr = ptr->next;
    }
    return -1;
}
static char* lookup_symbol(char *name) {
    int original_scope = scope;
    while(scope>=0){
        Symbol *ptr = SymbolTable[scope];
        while(ptr){
            if(strcmp(name, ptr->Name)==0){
                printf("IDENT (name=%s, address=%d)\n", ptr->Name, ptr->Addr);
                scope = original_scope;
                return strdup(ptr->Type);
            }
            ptr = ptr->next;
        }
        scope --;
    }
    printf("error:%d: undefined: %s\n", yylineno+1, name);
    scope = original_scope;
    return strdup("ERROR");
}

static void lookup_function(char *name) {
    int original_scope = scope;
    while(scope>=0){
        Symbol *ptr = SymbolTable[scope];
        while(ptr){
            if(strcmp(name, ptr->Name)==0){
                printf("call: %s%s\n", ptr->Name, ptr->FuncSig);
                scope = original_scope;
                return;
            }
            ptr = ptr->next;
        }
        scope--;
    }
    scope = original_scope;
}

static void dump_symbol() {
    table_index[scope] = 0; // Decrement scope and reset table_index
    printf("\n> Dump symbol table (scope level: %d)\n", scope);
    printf("%-10s%-10s%-10s%-10s%-10s%-10s\n",
           "Index", "Name", "Type", "Addr", "Lineno", "Func_sig");
    Symbol *ptr = SymbolTable[scope];
    Symbol *temp =  (Symbol*) malloc(sizeof(Symbol));
    if(ptr==NULL){
        scope--;
        printf("\n");
        return;
    }
    else{   
        while(ptr!=NULL){
            printf("%-10d%-10s%-10s%-10d%-10d%-10s", ptr->Index, ptr->Name, ptr->Type, ptr->Addr, ptr->Lineno, ptr->FuncSig);
            printf("\n");
            temp = ptr;
            ptr = ptr->next;
            free(temp);
        }
        // Destruct the entire symbol table
        free(ptr);
        SymbolTable[scope] = NULL;
        scope--;
        printf("\n");
        return;
    }
}