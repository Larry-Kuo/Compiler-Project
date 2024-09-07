#ifndef COMPILER_HW_COMMON_H
#define COMPILER_HW_COMMON_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

/* Add what you need */
typedef struct Symbol{
    int Index;
    char *Name;
    char *Type;
    int Addr;
    int Lineno;
    char *FuncSig;
    struct Symbol *next;
} Symbol;

#endif /* COMPILER_HW_COMMON_H */