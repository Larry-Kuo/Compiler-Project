/* Please feel free to modify any content */

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

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;

    /* Used to generate code */
    /* As printf; the usage: CODEGEN("%d - %s\n", 100, "Hello world"); */
    /* We do not enforce the use of this macro */
    #define CODEGEN(...) \
        do { \
            for (int i = 0; i < g_indent_cnt; i++) { \
                fprintf(fout, "\t"); \
            } \
            fprintf(fout, __VA_ARGS__); \
        } while (0)

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

    Symbol *SymbolTable[5];
    int switchNum, caseNum;
    int addr = 0;
    int scope = -1;
    int table_index[5];
    bool HAS_ERROR = false;
    char *func_sig;
    int func_para_lineno = 0;
    int searchedAddr;
    int Cmp_count = 0;
    int assAddr=0;
    /* Global variables */
    bool g_has_error = false;
    FILE *fout = NULL;
    int g_indent_cnt = 0;
    int Cases[10];

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
    /* ... */
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
    FuncParameter ReturnType {
        printf("func_signature: %s\n", func_sig);
        insert_symbol(--scope, $2, "func");
        if(strcmp($2, "main") == 0) {                
                CODEGEN(".method public static main([Ljava/lang/String;)V\n.limit stack 100\n.limit locals 100\n");
            }
            else {
                CODEGEN(".method public static %s%s\n.limit stack 100\n.limit locals 100\n", $2, func_sig);
            }
    }
    FuncBlock {CODEGEN("return\n.end method\n\n");}
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
    : VAR IDENT Type '=' Expression
    {
        if(Redeclaration($2)>0){
            printf("error:%d: %s redeclared in this block. previous declaration at line %d\n", yylineno, $2, Redeclaration($2));
            HAS_ERROR = true;
        }
        func_para_lineno = 0;
        insert_symbol(scope, $2, $3);
        if(strcmp($3, "string")==0){   
            CODEGEN("astore %d\n", addr-1); 
        }
        else if(strcmp($3, "bool")==0){
            CODEGEN("istore %d\n", addr-1); 
        }
        else{
             CODEGEN("%cstore %d\n", $3[0], addr-1);
        }
        // CODEGEN("%cstore %d\n", $3[0]=='s'? 'a': $3[0]=='b'? 'i':$3[0], addr-1);
    }
    | VAR IDENT Type
    {
        if(Redeclaration($2)>0){
            printf("error:%d: %s redeclared in this block. previous declaration at line %d\n", yylineno, $2, Redeclaration($2));
            HAS_ERROR = true;
        }
        insert_symbol(scope, $2, $3);
        if(strcmp($3, "float32")==0){   
            CODEGEN("ldc 0.0\n"); 
        }
        else if(strcmp($3, "int32")==0){
            CODEGEN("ldc 0\n");
        }
        else{
             CODEGEN("ldc \"\"\n");
        }
        if(strcmp($3, "string")==0){   
            CODEGEN("astore %d\n", addr-1); 
        }
        else if(strcmp($3, "bool")==0){
            CODEGEN("istore %d\n", addr-1); 
        }
        else{
             CODEGEN("%cstore %d\n", $3[0], addr-1);
        }
        // CODEGEN("%cstore %d\n", $3[0]=='s'? 'a': $3[0]=='b'? 'i':$3[0], addr-1);
    }
        
;

SimpleStmt
    : AssignmentStmt | Expression | IncDecStmt 
;

AssignmentStmt
    : Expression
    {
        assAddr = searchedAddr;
    }
    assign_op
    {  
        if($3[0]!='=')  CODEGEN("%cload %d\n", $1[0], assAddr);
    }
    Expression 
    {
        if(strcmp($1, $5)!=0){
            printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n", yylineno, $3, $1, $5);
            HAS_ERROR = true;
        }
        printf("%s\n", $3);
        if($3[0] != '=') CODEGEN("%c%s\n", $1[0], $3);
         if(strcmp($1, "string")==0){   
            CODEGEN("astore %d\n", assAddr); 
        }
        else if(strcmp($1, "bool")==0){
            CODEGEN("istore %d\n", assAddr); 
        }
        else{
            CODEGEN("%cstore %d\n", $1[0], assAddr);
        }
    }
;

assign_op
    : '=' {$$ = strdup("=");}
    | more_assign_op
;

more_assign_op
    : MUL_ASSIGN {$$ = strdup("mul");}
    | QUO_ASSIGN {$$ = strdup("div");}
    | ADD_ASSIGN {$$ = strdup("add");}
    | REM_ASSIGN {$$ = strdup("rem");}
    | SUB_ASSIGN {$$ = strdup("sub");}
;

IncDecStmt
    : Expression inc_dec 
    {
        printf("%s\n", $2);
        if($1[0]=='i')  CODEGEN("ldc 1\n");
        else CODEGEN("ldc 1.0\n");
        if(strcmp($2, "INC")==0){
            CODEGEN("%cadd\n", $1[0]);
        }
        else{
            CODEGEN("%csub\n", $1[0]);
        }
        CODEGEN("%cstore %d\n", $1[0], searchedAddr);
    }
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
    : IF Expression
    {
        if (strcmp($2, "bool")!=0) {
            printf("error:%d: non-bool (type %s) used as for condition\n", yylineno + 1, $2);
            HAS_ERROR = true;
        }
        CODEGEN("ifeq if_false\n");
    }
    Block
    {
        CODEGEN("goto if_exit\nif_false:\n");
    }
    ElseStmt
    {
        CODEGEN("if_exit:\n");
    }
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
            HAS_ERROR = true;
        }
        CODEGEN("ifeq if_false\n");
    } 
;

//For Statement
ForStmt
    : FOR
    {
        CODEGEN("For_Loop:\n");
    }
    ForClause 
    {
        CODEGEN("ifeq For_Loop_Exit\n");
    }
    Block
    {
        CODEGEN("goto For_Loop\n"); 
        CODEGEN("For_Loop_Exit:\n");
    }
;

ForClause
    : Expression
    | InitStmt ';' Expression ';' PostStmt
;

InitStmt
    : SimpleStmt
;

PostStmt
    : SimpleStmt
;

//Switch Statement
SwitchStmt
    : SWITCH 
    Expression
    {
        CODEGEN("goto Switch_begin_%d\n", switchNum);
    }
    Block
    {
        CODEGEN("Switch_begin_%d:\nlookupswitch\n", switchNum);
        for(int i = 0; i < caseNum-1; i++){
            CODEGEN("%d: Case_%d_%d\n", Cases[i], switchNum, i);
        }
        CODEGEN("default: Case_%d_%d\n", switchNum, caseNum-1);
        CODEGEN("Switch_end_%d:\n", switchNum);
        caseNum = 0;
        switchNum++;
    }
;

CaseStmt
    : NumDefault ':' Block
    {
        CODEGEN("goto Switch_end_%d\n", switchNum);
    }
;

NumDefault 
    : CASE INT_LIT 
    {
        printf("case %d\n", $2);
        CODEGEN("Case_%d_%d:\n",switchNum, caseNum); 
        caseNum++;
        Cases[caseNum-1] = $2;
    }
    | DEFAULT
    {
        CODEGEN("Case_%d_%d:\n", switchNum, caseNum);
        caseNum++;
    }
;
//Print Statement
PrintStmt
    : PRINTLN '(' Expression ')' 
    {
        printf("PRINTLN %s\n", $3);
        if(strcmp($3,"bool")==0)
        {
            CODEGEN("ifne L%d_cmp_0\nldc \"false\"\ngoto L%d_cmp_1\nL%d_cmp_0:\nldc \"true\"\nL%d_cmp_1:\n", Cmp_count, Cmp_count, Cmp_count, Cmp_count);
            Cmp_count++;
        }
        CODEGEN("getstatic java/lang/System/out Ljava/io/PrintStream;\nswap\n");
        CODEGEN("invokevirtual java/io/PrintStream/println("); 
        if(strcmp($3, "string")==0 || strcmp($3, "bool")==0)
        {
            CODEGEN("Ljava/lang/String;");
        }
        else
        {
            CODEGEN("%c", toupper($3[0]));
        }
        CODEGEN(")V\n");
    }
    | PRINT '(' Expression ')' 
    {
        printf("PRINT %s\n", $3);
        if(strcmp($3,"bool")==0)
        {
            CODEGEN("iconst_1\nifne L%d_cmp_0\nldc \"false\"\ngoto L%d_cmp_1\nL%d_cmp_0:\nldc \"true\"\nL%d_cmp_1:\n", Cmp_count, Cmp_count, Cmp_count, Cmp_count);
            Cmp_count++;
        }
        CODEGEN("getstatic java/lang/System/out Ljava/io/PrintStream;\n");
        CODEGEN("swap\n");
        CODEGEN("invokevirtual java/io/PrintStream/print("); 
        if(strcmp($3, "string")==0 || strcmp($3, "bool")==0)
        {
            CODEGEN("Ljava/lang/String;");
        }
        else
        {
            CODEGEN("%c", toupper($3[0]));
        }
        CODEGEN(")V\n");
    }
;
//Return Statement
ReturnStmt
    : RETURN { printf("return\n");} 
    | RETURN Expression 
    { 
        printf("%creturn\n", $2[0]);
        CODEGEN("%c", $2[0]); 
    }
;
//Expression
Expression
    : Expression LOR AndExpression
    {
        $2 = strdup("LOR");
        if(strcmp($1, "bool")!=0){
            printf("error:%d: invalid operation: (operator LOR not defined on %s)\n", yylineno, $1);
            HAS_ERROR = true;
        }
        else if(strcmp($3, "bool")!=0){
            printf("error:%d: invalid operation: (operator LOR not defined on %s)\n", yylineno, $3);
            HAS_ERROR = true;
        }
        printf("%s\n", $2);
        $$ = strdup("bool");
        CODEGEN("ior\n");
    }
    | AndExpression
;

AndExpression
    : AndExpression LAND CmpExpression
    {
        $2 = strdup("LAND"); 
        CODEGEN("iand\n");
        if(strcmp($1, "bool")!=0)
            printf("error:%d: invalid operation: (operator LAND not defined on %s)\n", yylineno, $1);
        else if(strcmp($3, "bool")!=0)
            printf("error:%d: invalid operation: (operator LAND not defined on %s)\n", yylineno, $3);
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
            HAS_ERROR = true;
        }
        printf("%s\n", $2);
        $$ = strdup("bool");
        if(strcmp($3,"float32")==0){
            if(strcmp($2, "GTR") == 0) {
                CODEGEN("fcmpl\nifgt L%d_cmp_0\niconst_0\ngoto L%d_cmp_1\nL%d_cmp_0:\niconst_1\nL%d_cmp_1:\n",Cmp_count,Cmp_count,Cmp_count,Cmp_count);
                Cmp_count++;
            }
            else if(strcmp($2, "LSS") == 0) {
                CODEGEN("fcmpg\niflt L%d_cmp_0\niconst_0\ngoto L%d_cmp_1\nL%d_cmp_0:\niconst_1\nL%d_cmp_1:\n",Cmp_count,Cmp_count,Cmp_count,Cmp_count);
                Cmp_count++;
            }
        }
        else if(strcmp($3,"int32")==0){
            if(strcmp($2, "GTR") == 0) {
                CODEGEN("if_icmpgt L%d_cmp_0\niconst_0\ngoto L%d_cmp_1\nL%d_cmp_0:\niconst_1\nL%d_cmp_1:\n",Cmp_count,Cmp_count,Cmp_count,Cmp_count);
                Cmp_count++;
            }
            else if(strcmp($2, "LSS") == 0) {
                    CODEGEN("if_icmplt L%d_cmp_0\niconst_0\ngoto L%d_cmp_1\nL%d_cmp_0:\niconst_1\nL%d_cmp_1:\n",Cmp_count,Cmp_count,Cmp_count,Cmp_count);
                    Cmp_count++;
                }
            else if (strcmp($2, "EQL") == 0) {
                    CODEGEN("if_icmpeq L%d_cmp_0\niconst_0\ngoto L%d_cmp_1\nL%d_cmp_0:\niconst_1\nL%d_cmp_1:\n",Cmp_count,Cmp_count,Cmp_count,Cmp_count);
                    Cmp_count++;
                }
        }
    }
    | AddExpression
;

AddExpression
    : AddExpression add_op MulExpression
    { 
        if(strcmp($1, $3)!=0){
            printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n", yylineno, $2, $1, $3);
            HAS_ERROR = true;
        }
        printf("%s\n", $2);
        CODEGEN("%c%s\n", $1[0], $2); 
    }
    | MulExpression
;

MulExpression
    : MulExpression mul_op UnaryExpression
    {
        if(strcmp($2,"REM")==0){
            if(strcmp($1, "int32")!=0 ||strcmp($3, "int32")!=0){
                printf("error:%d: invalid operation: (operator REM not defined on float32)\n", yylineno);
                HAS_ERROR = true;
            }
        }
        printf("%s\n", $2);
        CODEGEN("%c%s\n", $1[0], $2);
    }
    | UnaryExpression
;

UnaryExpression
    : unary_op UnaryExpression { 
        $$ = $2;
        printf("%s\n", $1);
        if($1[0]!='p') CODEGEN("%c%s\n", $2[0], $1); 
    }
    | PrimaryExpression
    | '!' UnaryExpression {$$ = $2; CODEGEN("iconst_1\n");  CODEGEN("ixor\n");}
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
    : '*' {$$ = strdup("mul");}
    | '/' {$$ = strdup("div");}
    | '%' {$$ = strdup("rem");}
;

unary_op
    : '+' {$$ = strdup("pos");}
    | '-' {$$ = strdup("neg");}
;

add_op
    : '+' {$$ = strdup("add"); }
    | '-' {$$ = strdup("sub");}
;


Operand
    : Literal { $$ = $1; }
    | IDENT 
    {
        $$ = lookup_symbol($1); 
        if(strcmp($$,"string")==0){
            CODEGEN("aload %d\n", searchedAddr);
        }
        else if(strcmp($$,"bool")==0){
            CODEGEN("iload %d\n", searchedAddr);
        }
        else{
            CODEGEN("%cload %d\n",$$[0], searchedAddr);
        }
        // CODEGEN("%cload %d\n", $$[0]=='s'? 'a':$$[0]=='b'?'i':$$[0], searchedAddr);
    }
    | '(' Expression ')' { $$ = $2; }
;

Literal
    : FLOAT_LIT {printf("FLOAT_LIT %f\n", $1); $$ = strdup("float32"); CODEGEN("ldc %f\n", $1);}
    | INT_LIT  {printf("INT_LIT %d\n", $1); $$ = strdup("int32"); CODEGEN("ldc %d\n", $1);}
    | '\"' STRING_LIT '\"' {printf("STRING_LIT %s\n", $2); $$ = strdup("string"); CODEGEN("ldc \"%s\"\n", $2);}
    | BOOL_LIT {
        if(strcmp($1, "true")==0) printf("TRUE 1\n");
        else   printf("FALSE 0\n");
        $$ = strdup("bool");
        CODEGEN("ldc %d\n", $1[0] == 't' ? 1 : 0);
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
    : Type '(' Expression ')' 
    {
        printf("%c2%c\n", $3[0], $1[0]); 
        CODEGEN("%c2%c\n", $3[0], $1[0]);
    }
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
    if (!yyin) {
        printf("file `%s` doesn't exists or cannot be opened\n", argv[1]);
        exit(1);
    }
    for(int i=0; i<5; ++i){
        table_index[i] = 0;
        SymbolTable[i] = NULL;
    }
    /* Codegen output init */
    char *bytecode_filename = "hw3.j";
    fout = fopen(bytecode_filename, "w");
    CODEGEN(".source hw3.j\n");
    CODEGEN(".class public Main\n");
    CODEGEN(".super java/lang/Object\n");

    /* Symbol table init */
    // Add your code

    yylineno = 0;
    yyparse();

    /* Symbol table dump */
    // Add your code

	printf("Total lines: %d\n", yylineno);
    fclose(fout);
    fclose(yyin);
    printf("\n%s\n", HAS_ERROR ? "true" : "false");
    if (HAS_ERROR) {
        remove(bytecode_filename);
    }
    yylex_destroy();
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
                searchedAddr = ptr->Addr;
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
                CODEGEN("invokestatic Main/%s%s\n", ptr->Name, ptr->FuncSig);
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