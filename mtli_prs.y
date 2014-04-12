/*X Memory Test Verification and Generation
  Copyright 1994, 1995, A. Offerman (offerman@einstein.et.tudelft.nl),
                        H.I. Schanstra (ivo@duteca.et.tudelft.nl),
                        Section Computer Architecture & Digital Systems,
                        Department of Electrical Engineering,
                        Delft University of Technology, The Netherlands
  All rights reserved*/




%{
//MTL interpreter declarations
#include "mtl_decl.h"
#include "mtl_dstr.h"
#include "memchip.h"
%}


%{
//C/C++
#include <assert.h>
extern "C" {
  #include <stdlib.h>
  #include <string.h>
  }
%}


%{
//Tcl/Tk
extern "C" {
  #include "tcl.h"
  #include "tk.h"
  }
%}


%{
//xmtvg
#include "mess_il.h"
%}


%{
//bison declarations
extern char *mtlitext;
#define YYERROR_VERBOSE 1
int yyerror (char *error_message);
int yylex (void);
%}


//YYSTYPE declaration
%union {Addressing_specifier addressing_specifier;
       unsigned int unsigned_integer;
       char *string; //dynamically allocated
       Tile_size tile_size;
       Location location;
       }

//tokens
%token ALLPORTS
%token <unsigned_integer> PORT
%token DOWN UP UP_DOWN
%token SOUTH NORTH NORTH_SOUTH EAST WEST EAST_WEST
%token <unsigned_integer> OPERATOR
%token <string> DECIMAL_WORD
%token NOP

//non-terminals
%type <addressing_specifier> addressing_specifier
%type <unsigned_integer> addressing_direction
%type <unsigned_integer> _1_dimensional_addressing_direction
%type <unsigned_integer> row_addressing_direction
%type <unsigned_integer> column_addressing_direction
%type <unsigned_integer> addressing_id
%type <tile_size> tile_size
%type <unsigned_integer> number_of_rows
%type <unsigned_integer> number_of_columns
%type <location> location
%type <unsigned_integer> row_offset
%type <unsigned_integer> column_offset
%type <unsigned_integer> integer
%type <string> data

%{
//MTL interpreter declarations & data structures

//xmtvg
#include "datastr.h"
#include "memtype.h"

//chip operation list
struct mtli_Addressing_identifier {unsigned int status;
                                  int row;
                                  int column;
                                  };
enum mtli_Operation_type {mtli_read_operation, mtli_write_operation,
    mtli_no_operation};
struct mtli_Port_operation_list_element {
  mtli_Port_operation_list_element *previous_element;
  mtli_Port_operation_list_element *next_element;
  unsigned int row_address;
  unsigned int column_address;
  mtli_Operation_type operation_type;
  char *data; //dynamically allocated
  };
struct mtli_Operation_list_element {
  mtli_Operation_list_element *previous_element;
  mtli_Operation_list_element *next_element;
  mtli_Port_operation_list_element *port_operation_list;
  mtli_Port_operation_list_element *port_operation_list_last_element;
  };
struct mtli_Chip_operation_list_element {
  mtli_Chip_operation_list_element *previous_element;
  mtli_Chip_operation_list_element *next_element;
  mtli_Addressing_identifier addressing_identifier [27];
  mtli_Operation_list_element *operation_list;
  mtli_Operation_list_element *operation_list_last_element;
  };
static mtli_Chip_operation_list_element *mtli_chip_operation_list = NULL;
static mtli_Chip_operation_list_element *mtli_chip_operation_list_last_element
    = NULL;

//chip operation list recursion stack
struct mtli_Recursion_stack_element_list_element {
  mtli_Recursion_stack_element_list_element *previous_element;
  mtli_Recursion_stack_element_list_element *next_element;
  mtli_Chip_operation_list_element *chip_operation_list_element;
  };
struct mtli_Recursion_stack_element {
  mtli_Recursion_stack_element *previous_element;
  mtli_Recursion_stack_element *next_element;
  mtli_Recursion_stack_element_list_element *list_element_list;
  mtli_Recursion_stack_element_list_element *list_element_list_last_element;
  };
static mtli_Recursion_stack_element *mtli_recursion_stack = NULL;
static mtli_Recursion_stack_element *mtli_recursion_stack_last_element = NULL;
%}

%{
//MTL interpreter functions
static void mtli_garbage_collection (void);
static void mtli_fresh_environment (void);
static unsigned int mtli_execute_chip_operation_list (void);
%}


%%

%start MTL_test
MTL_test: test_type test_algorithm {
  mtli_fault_found = 0;
  };

test_type: port_list {
  yyerror ("MTL internal error: port_list not preprocessed");
  mtli_garbage_collection ();
  return 1;
  }      | ALLPORTS {
  yyerror ("MTL internal error: ALLPORTS not preprocessed");
  mtli_garbage_collection ();
  return 1;
  }      | {
  };

port_list: PORT {
  }      | PORT port_list {
  };

test_algorithm: '{' {
  mtli_garbage_collection ();
  mtli_fresh_environment ();
  } march_element_list '}' {
  mtli_garbage_collection ();
  };

march_element_list: march_element {
  }               | march_element ';' march_element_list {
  };

march_element: normal_march_element {
  if (mtli_execute_chip_operation_list () == 0) {
    mtli_garbage_collection ();
    mtli_fresh_environment ();
    }
  else {
    return 1;
    }
  }          | tile_march_element {
  if (mtli_execute_chip_operation_list () == 0) {
    mtli_garbage_collection ();
    mtli_fresh_environment ();
    }
  else {
    return 1;
    }
  }          | global_march_element {
  if (mtli_execute_chip_operation_list () == 0) {
    mtli_garbage_collection ();
    mtli_fresh_environment ();
    }
  else {
    return 1;
    }
  };

normal_march_element: _1_dimensional_addressing_direction '(' {
  if (mtli_recursion_stack_last_element != NULL) {
    mtli_recursion_stack_last_element->next_element =
        new mtli_Recursion_stack_element;
    assert (mtli_recursion_stack_last_element->next_element != NULL);
        //memory exhausted
    mtli_recursion_stack_last_element->next_element->previous_element =
        mtli_recursion_stack_last_element;
    mtli_recursion_stack_last_element->next_element->next_element = NULL;
    mtli_recursion_stack_last_element->next_element->list_element_list = NULL;
    mtli_recursion_stack_last_element->next_element->
        list_element_list_last_element = NULL;
    mtli_recursion_stack_last_element =
        mtli_recursion_stack_last_element->next_element;
    mtli_Recursion_stack_element_list_element
        *tmp_recursion_stack_element_list_element =
        mtli_recursion_stack_last_element->previous_element->list_element_list;
    unsigned int tmp_return = 0;
    while (tmp_recursion_stack_element_list_element != NULL) {
      switch ($1) {
        case mtl_down: {
          if (current_memory_type.address_order == column_first) {
            if (current_memory_type.row_order == top_first) {
              if (current_memory_type.column_order == left_first) {
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int row = mtli_memory_chip.number_of_rows () - 1;
                    row >= 0; row--) {
                  for (int column = mtli_memory_chip.number_of_columns () - 1;
                      column >= 0; column--) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              else { //right_first
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int row = mtli_memory_chip.number_of_rows () - 1;
                    row >= 0; row--) {
                  for (int column = 0;
                      column < mtli_memory_chip.number_of_columns ();
                      column++) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              }
            else { //bottom_first
              if (current_memory_type.column_order == left_first) {
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int row = 0; row < mtli_memory_chip.number_of_rows ();
                    row++) {
                  for (int column = mtli_memory_chip.number_of_columns () - 1;
                      column >= 0; column--) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              else { //right_first
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int row = 0; row < mtli_memory_chip.number_of_rows ();
                    row++) {
                  for (int column = 0;
                      column < mtli_memory_chip.number_of_columns ();
                      column++) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              }
            }
          else { //row_first
            if (current_memory_type.row_order == top_first) {
              if (current_memory_type.column_order == left_first) {
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int column = mtli_memory_chip.number_of_columns () - 1;
                    column >= 0; column--)
                    {
                  for (int row = mtli_memory_chip.number_of_rows () - 1;
                      row >= 0; row--) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              else { //right_first
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int column = 0;
                    column < mtli_memory_chip.number_of_columns (); column++)
                    { 
                  for (int row = mtli_memory_chip.number_of_rows () - 1;
                      row >= 0; row--) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              }
            else { //bottom_first
              if (current_memory_type.column_order == left_first) {
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int column = mtli_memory_chip.number_of_columns () - 1;
                    column >= 0; column--)
                    {
                  for (int row = 0; row < mtli_memory_chip.number_of_rows ();
                      row++) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              else { //right_first
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int column = 0;
                    column < mtli_memory_chip.number_of_columns (); column++)
                    {
                  for (int row = 0;
                      row < mtli_memory_chip.number_of_rows (); row++) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              }
            }
          break;
          }
        case mtl_up: {
          if (current_memory_type.address_order == column_first) {
            if (current_memory_type.row_order == top_first) {
              if (current_memory_type.column_order == left_first) {
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int row = 0; row < mtli_memory_chip.number_of_rows ();
                    row++) {
                  for (int column = 0;
                      column < mtli_memory_chip.number_of_columns ();
                      column++) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              else { //right_first
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int row = 0; row < mtli_memory_chip.number_of_rows ();
                    row++) {
                  for (int column = mtli_memory_chip.number_of_columns () - 1;
                      column >= 0; column--) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              }
            else { //bottom_first
              if (current_memory_type.column_order == left_first) {
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int row = mtli_memory_chip.number_of_rows () - 1;
                    row >= 0; row--) {
                  for (int column = 0;
                      column < mtli_memory_chip.number_of_columns ();
                      column++) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              else { //right_first
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int row = mtli_memory_chip.number_of_rows () - 1;
                    row >= 0; row--) {
                  for (int column = mtli_memory_chip.number_of_columns () - 1;
                      column >= 0; column--) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              }
            }
          else { //row_first
            if (current_memory_type.row_order == top_first) {
              if (current_memory_type.column_order == left_first) {
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int column = 0;
                    column < mtli_memory_chip.number_of_columns (); column++)
                    {
                  for (int row = 0; row < mtli_memory_chip.number_of_rows ();
                      row++) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              else { //right_first
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int column = mtli_memory_chip.number_of_columns () - 1;
                    column >= 0; column--) {
                  for (int row = 0; row < mtli_memory_chip.number_of_rows ();
                      row++) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              }
            else { //bottom_first
              if (current_memory_type.column_order == left_first) {
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int column = 0;
                    column < mtli_memory_chip.number_of_columns (); column++)
                    {
                  for (int row = mtli_memory_chip.number_of_rows () - 1;
                      row >= 0; row--) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              else { //right_first
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int column = mtli_memory_chip.number_of_columns () - 1;
                    column >= 0; column--) {
                  for (int row = mtli_memory_chip.number_of_rows () - 1;
                      row >= 0; row--) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              }
            }
          break;
          }
        default: {
          yyerror ("MTL internal error: 1_dimensional_addressing_direction "
              "not recognized");
          mtli_garbage_collection ();
          tmp_return = 1; //return from yyparse
          break;
          }
        }
      if (tmp_return == 1) {
        return 1;
        }
      tmp_recursion_stack_element_list_element =
          tmp_recursion_stack_element_list_element->next_element;
      }
    }
  else {
    yyerror ("MTL internal error: empty recursion stack pop");
    mtli_garbage_collection ();
    return 1;
    }
  } sub_march_element_list ')' {
  if (mtli_recursion_stack_last_element != NULL) {
    mtli_Recursion_stack_element_list_element
       *tmp_recursion_stack_element_list_element =
       mtli_recursion_stack_last_element->list_element_list;
    while (tmp_recursion_stack_element_list_element != NULL) {
      if (tmp_recursion_stack_element_list_element->next_element == NULL) {
        delete tmp_recursion_stack_element_list_element;
        tmp_recursion_stack_element_list_element = NULL;
        }
      else {
        tmp_recursion_stack_element_list_element =
            tmp_recursion_stack_element_list_element->next_element;
        delete tmp_recursion_stack_element_list_element->previous_element;
        }
      }
    if (mtli_recursion_stack_last_element->previous_element != NULL) {
      mtli_recursion_stack_last_element =
          mtli_recursion_stack_last_element->previous_element;
      delete mtli_recursion_stack_last_element->next_element;
      mtli_recursion_stack_last_element->next_element = NULL;
      }
    else {
      yyerror ("MTL internal error: empty recursion stack pop");
      mtli_garbage_collection ();
      return 1;
      }
    }
  else {
    yyerror ("MTL internal error: empty recursion stack pop");
    mtli_garbage_collection ();
    return 1;
    }
  }              | _1_dimensional_addressing_direction addressing_id '(' {
  if (mtli_recursion_stack_last_element != NULL) {
    mtli_recursion_stack_last_element->next_element =
        new mtli_Recursion_stack_element;
    assert (mtli_recursion_stack_last_element->next_element != NULL);
        //memory exhausted
    mtli_recursion_stack_last_element->next_element->previous_element =
        mtli_recursion_stack_last_element;
    mtli_recursion_stack_last_element->next_element->next_element = NULL;
    mtli_recursion_stack_last_element->next_element->list_element_list = NULL;
    mtli_recursion_stack_last_element->next_element->
        list_element_list_last_element = NULL;
    mtli_recursion_stack_last_element =
        mtli_recursion_stack_last_element->next_element;
    mtli_Recursion_stack_element_list_element
        *tmp_recursion_stack_element_list_element =
        mtli_recursion_stack_last_element->previous_element->list_element_list;
    unsigned int tmp_return = 0;
    while (tmp_recursion_stack_element_list_element != NULL) {
      switch ($1) {
        case mtl_down: {
          if (current_memory_type.address_order == column_first) {
            if (current_memory_type.row_order == top_first) {
              if (current_memory_type.column_order == left_first) {
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int row = mtli_memory_chip.number_of_rows () - 1;
                    row >= 0; row--) {
                  for (int column = mtli_memory_chip.number_of_columns () - 1;
                      column >= 0; column--) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              else { //right_first
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int row = mtli_memory_chip.number_of_rows () - 1;
                    row >= 0; row--) {
                  for (int column = 0;
                      column < mtli_memory_chip.number_of_columns ();
                      column++) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              }
            else { //bottom_first
              if (current_memory_type.column_order == left_first) {
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int row = 0; row < mtli_memory_chip.number_of_rows ();
                    row++) {
                  for (int column = mtli_memory_chip.number_of_columns () - 1;
                      column >= 0; column--) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              else { //right_first
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int row = 0; row < mtli_memory_chip.number_of_rows ();
                    row++) {
                  for (int column = 0;
                      column < mtli_memory_chip.number_of_columns ();
                      column++) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              }
            }
          else { //row_first
            if (current_memory_type.row_order == top_first) {
              if (current_memory_type.column_order == left_first) {
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int column = mtli_memory_chip.number_of_columns () - 1;
                    column >= 0; column--)
                    {
                  for (int row = mtli_memory_chip.number_of_rows () - 1;
                      row >= 0; row--) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              else { //right_first
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int column = 0;
                    column < mtli_memory_chip.number_of_columns (); column++)
                    { 
                  for (int row = mtli_memory_chip.number_of_rows () - 1;
                      row >= 0; row--) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              }
            else { //bottom_first
              if (current_memory_type.column_order == left_first) {
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int column = mtli_memory_chip.number_of_columns () - 1;
                    column >= 0; column--)
                    {
                  for (int row = 0; row < mtli_memory_chip.number_of_rows ();
                      row++) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              else { //right_first
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int column = 0;
                    column < mtli_memory_chip.number_of_columns (); column++)
                    {
                  for (int row = 0;
                      row < mtli_memory_chip.number_of_rows (); row++) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              }
            }
          break;
          }
        case mtl_up: {
          if (current_memory_type.address_order == column_first) {
            if (current_memory_type.row_order == top_first) {
              if (current_memory_type.column_order == left_first) {
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int row = 0; row < mtli_memory_chip.number_of_rows ();
                    row++) {
                  for (int column = 0;
                      column < mtli_memory_chip.number_of_columns ();
                      column++) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              else { //right_first
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int row = 0; row < mtli_memory_chip.number_of_rows ();
                    row++) {
                  for (int column = mtli_memory_chip.number_of_columns () - 1;
                      column >= 0; column--) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              }
            else { //bottom_first
              if (current_memory_type.column_order == left_first) {
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int row = mtli_memory_chip.number_of_rows () - 1;
                    row >= 0; row--) {
                  for (int column = 0;
                      column < mtli_memory_chip.number_of_columns ();
                      column++) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              else { //right_first
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int row = mtli_memory_chip.number_of_rows () - 1;
                    row >= 0; row--) {
                  for (int column = mtli_memory_chip.number_of_columns () - 1;
                      column >= 0; column--) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              }
            }
          else { //row_first
            if (current_memory_type.row_order == top_first) {
              if (current_memory_type.column_order == left_first) {
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int column = 0;
                    column < mtli_memory_chip.number_of_columns (); column++)
                    {
                  for (int row = 0; row < mtli_memory_chip.number_of_rows ();
                      row++) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              else { //right_first
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int column = mtli_memory_chip.number_of_columns () - 1;
                    column >= 0; column--) {
                  for (int row = 0; row < mtli_memory_chip.number_of_rows ();
                      row++) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              }
            else { //bottom_first
              if (current_memory_type.column_order == left_first) {
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int column = 0;
                    column < mtli_memory_chip.number_of_columns (); column++)
                    {
                  for (int row = mtli_memory_chip.number_of_rows () - 1;
                      row >= 0; row--) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              else { //right_first
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int column = mtli_memory_chip.number_of_columns () - 1;
                    column >= 0; column--) {
                  for (int row = mtli_memory_chip.number_of_rows () - 1;
                      row >= 0; row--) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$2].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              }
            }
          break;
          }
        default: {
          yyerror ("MTL internal error: 1_dimensional_addressing_direction "
              "not recognized");
          mtli_garbage_collection ();
          tmp_return = 1; //return from yyparse
          break;
          }
        }
      if (tmp_return == 1) {
        return 1;
        }
      tmp_recursion_stack_element_list_element =
          tmp_recursion_stack_element_list_element->next_element;
      }
    }
  else {
    yyerror ("MTL internal error: empty recursion stack pop");
    mtli_garbage_collection ();
    return 1;
    }
  } sub_march_element_list ')' {
  if (mtli_recursion_stack_last_element != NULL) {
    mtli_Recursion_stack_element_list_element
       *tmp_recursion_stack_element_list_element =
       mtli_recursion_stack_last_element->list_element_list;
    while (tmp_recursion_stack_element_list_element != NULL) {
      if (tmp_recursion_stack_element_list_element->next_element == NULL) {
        delete tmp_recursion_stack_element_list_element;
        tmp_recursion_stack_element_list_element = NULL;
        }
      else {
        tmp_recursion_stack_element_list_element =
            tmp_recursion_stack_element_list_element->next_element;
        delete tmp_recursion_stack_element_list_element->previous_element;
        }
      }
    if (mtli_recursion_stack_last_element->previous_element != NULL) {
      mtli_recursion_stack_last_element =
          mtli_recursion_stack_last_element->previous_element;
      delete mtli_recursion_stack_last_element->next_element;
      mtli_recursion_stack_last_element->next_element = NULL;
      }
    else {
      yyerror ("MTL internal error: empty recursion stack pop");
      mtli_garbage_collection ();
      return 1;
      }
    }
  else {
    yyerror ("MTL internal error: empty recursion stack pop");
    mtli_garbage_collection ();
    return 1;
    }
  }              | row_addressing_direction '(' {
  if (mtli_recursion_stack_last_element != NULL) {
    mtli_recursion_stack_last_element->next_element =
        new mtli_Recursion_stack_element;
    assert (mtli_recursion_stack_last_element->next_element != NULL);
        //memory exhausted
    mtli_recursion_stack_last_element->next_element->previous_element =
        mtli_recursion_stack_last_element;
    mtli_recursion_stack_last_element->next_element->next_element = NULL;
    mtli_recursion_stack_last_element->next_element->list_element_list = NULL;
    mtli_recursion_stack_last_element->next_element->
        list_element_list_last_element = NULL;
    mtli_recursion_stack_last_element =
        mtli_recursion_stack_last_element->next_element;
    mtli_Recursion_stack_element_list_element
        *tmp_recursion_stack_element_list_element =
        mtli_recursion_stack_last_element->previous_element->list_element_list;
    unsigned int tmp_return = 0;
    while (tmp_recursion_stack_element_list_element != NULL) {
      switch ($1) {
        case mtl_south: {
          unsigned int first_inserted_chip_operation_list_element = 1;
          for (int row = 0; row < mtli_memory_chip.number_of_rows (); row++) {
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element =
                new mtli_Chip_operation_list_element;
            assert (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element !=
                NULL); //memory exhausted
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                next_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element;
            for (unsigned int i = 0; i < 27; i++) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier [i] =
                  tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  previous_element->addressing_identifier [i];
              }
            if (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_column ||
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_row_column) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_row_column;
              }
            else {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_row;
              }
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].row = row;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list = NULL;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list_last_element = NULL;
            if (mtli_recursion_stack_last_element->list_element_list == NULL)
                {
              mtli_recursion_stack_last_element->list_element_list =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->list_element_list !=
                  NULL); //memory exhausted
              mtli_recursion_stack_last_element->list_element_list->
                  previous_element = NULL;
              mtli_recursion_stack_last_element->list_element_list->
                  next_element = NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->list_element_list;
              }
            else {
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element != NULL);
                  //memory exhausted
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->
                  previous_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element;
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->next_element =
                  NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element;
              }
            first_inserted_chip_operation_list_element = 0;
            }
          break;
          }
        case mtl_north: {
          unsigned int first_inserted_chip_operation_list_element = 1;
          for (int row = mtli_memory_chip.number_of_rows () - 1; row >= 0;
              row--) {
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element =
                new mtli_Chip_operation_list_element;
            assert (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element !=
                NULL); //memory exhausted
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                next_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element;
            for (unsigned int i = 0; i < 27; i++) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier [i] =
                  tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  previous_element->addressing_identifier [i];
              }
            if (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_column ||
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_row_column) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_row_column;
              }
            else {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_row;
              }
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].row = row;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list = NULL;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list_last_element = NULL;
            if (mtli_recursion_stack_last_element->list_element_list == NULL)
                {
              mtli_recursion_stack_last_element->list_element_list =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->list_element_list !=
                  NULL); //memory exhausted
              mtli_recursion_stack_last_element->list_element_list->
                  previous_element = NULL;
              mtli_recursion_stack_last_element->list_element_list->
                  next_element = NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->list_element_list;
              }
            else {
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element != NULL);
                  //memory exhausted
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->
                  previous_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element;
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->
                  next_element = NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element;
              }
            first_inserted_chip_operation_list_element = 0;
            }
          break;
          }
        default: {
          yyerror ("MTL internal error: row_addressing_direction not "
              "recognized");
          mtli_garbage_collection ();
          tmp_return = 1; //return from yyparse
          break;
          }
        }
      if (tmp_return == 1) {
        return 1;
        }
      tmp_recursion_stack_element_list_element =
          tmp_recursion_stack_element_list_element->next_element;
      }
    }
  else {
    yyerror ("MTL internal error: empty recursion stack pop");
    mtli_garbage_collection ();
    return 1;
    }
  } column_sub_march_element_list ')' {
  if (mtli_recursion_stack_last_element != NULL) {
    mtli_Recursion_stack_element_list_element
       *tmp_recursion_stack_element_list_element =
       mtli_recursion_stack_last_element->list_element_list;
    while (tmp_recursion_stack_element_list_element != NULL) {
      if (tmp_recursion_stack_element_list_element->next_element == NULL) {
        delete tmp_recursion_stack_element_list_element;
        tmp_recursion_stack_element_list_element = NULL;
        }
      else {
        tmp_recursion_stack_element_list_element =
            tmp_recursion_stack_element_list_element->next_element;
        delete tmp_recursion_stack_element_list_element->previous_element;
        }
      }
    if (mtli_recursion_stack_last_element->previous_element != NULL) {
      mtli_recursion_stack_last_element =
          mtli_recursion_stack_last_element->previous_element;
      delete mtli_recursion_stack_last_element->next_element;
      mtli_recursion_stack_last_element->next_element = NULL;
      }
    else {
      yyerror ("MTL internal error: empty recursion stack pop");
      mtli_garbage_collection ();
      return 1;
      }
    }
  else {
    yyerror ("MTL internal error: empty recursion stack pop");
    mtli_garbage_collection ();
    return 1;
    }
  }              | row_addressing_direction addressing_id '(' {
  if (mtli_recursion_stack_last_element != NULL) {
    mtli_recursion_stack_last_element->next_element =
        new mtli_Recursion_stack_element;
    assert (mtli_recursion_stack_last_element->next_element != NULL);
        //memory exhausted
    mtli_recursion_stack_last_element->next_element->previous_element =
        mtli_recursion_stack_last_element;
    mtli_recursion_stack_last_element->next_element->next_element = NULL;
    mtli_recursion_stack_last_element->next_element->list_element_list = NULL;
    mtli_recursion_stack_last_element->next_element->
        list_element_list_last_element = NULL;
    mtli_recursion_stack_last_element =
        mtli_recursion_stack_last_element->next_element;
    mtli_Recursion_stack_element_list_element
        *tmp_recursion_stack_element_list_element =
        mtli_recursion_stack_last_element->previous_element->list_element_list;
    unsigned int tmp_return = 0;
    while (tmp_recursion_stack_element_list_element != NULL) {
      switch ($1) {
        case mtl_south: {
          unsigned int first_inserted_chip_operation_list_element = 1;
          for (int row = 0; row < mtli_memory_chip.number_of_rows (); row++) {
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element =
                new mtli_Chip_operation_list_element;
            assert (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element !=
                NULL); //memory exhausted
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                next_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element;
            for (unsigned int i = 0; i < 27; i++) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier [i] =
                  tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  previous_element->addressing_identifier [i];
              }
            if (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_column ||
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_row_column) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_row_column;
              }
            else {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_row;
              }
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].row = row;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[$2].status = mtl_row;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[$2].row = row;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list = NULL;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list_last_element = NULL;
            if (mtli_recursion_stack_last_element->list_element_list == NULL)
                {
              mtli_recursion_stack_last_element->list_element_list =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->list_element_list !=
                  NULL); //memory exhausted
              mtli_recursion_stack_last_element->list_element_list->
                  previous_element = NULL;
              mtli_recursion_stack_last_element->list_element_list->
                  next_element = NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->list_element_list;
              }
            else {
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element != NULL);
                  //memory exhausted
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->
                  previous_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element;
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->next_element =
                  NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element;
              }
            first_inserted_chip_operation_list_element = 0;
            }
          break;
          }
        case mtl_north: {
          unsigned int first_inserted_chip_operation_list_element = 1;
          for (int row = mtli_memory_chip.number_of_rows () - 1; row >= 0;
              row--) {
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element =
                new mtli_Chip_operation_list_element;
            assert (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element !=
                NULL); //memory exhausted
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                next_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element;
            for (unsigned int i = 0; i < 27; i++) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier [i] =
                  tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  previous_element->addressing_identifier [i];
              }
            if (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_column ||
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_row_column) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_row_column;
              }
            else {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_row;
              }
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].row = row;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[$2].status = mtl_row;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[$2].row = row;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list = NULL;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list_last_element = NULL;
            if (mtli_recursion_stack_last_element->list_element_list == NULL)
                {
              mtli_recursion_stack_last_element->list_element_list =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->list_element_list !=
                  NULL); //memory exhausted
              mtli_recursion_stack_last_element->list_element_list->
                  previous_element = NULL;
              mtli_recursion_stack_last_element->list_element_list->
                  next_element = NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->list_element_list;
              }
            else {
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element != NULL);
                  //memory exhausted
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->
                  previous_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element;
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->
                  next_element = NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element;
              }
            first_inserted_chip_operation_list_element = 0;
            }
          break;
          }
        default: {
          yyerror ("MTL internal error: row_addressing_direction not "
              "recognized");
          mtli_garbage_collection ();
          tmp_return = 1; //return from yyparse
          break;
          }
        }
      if (tmp_return == 1) {
        return 1;
        }
      tmp_recursion_stack_element_list_element =
          tmp_recursion_stack_element_list_element->next_element;
      }
    }
  else {
    yyerror ("MTL internal error: empty recursion stack pop");
    mtli_garbage_collection ();
    return 1;
    }
  } column_sub_march_element_list ')' {
  if (mtli_recursion_stack_last_element != NULL) {
    mtli_Recursion_stack_element_list_element
       *tmp_recursion_stack_element_list_element =
       mtli_recursion_stack_last_element->list_element_list;
    while (tmp_recursion_stack_element_list_element != NULL) {
      if (tmp_recursion_stack_element_list_element->next_element == NULL) {
        delete tmp_recursion_stack_element_list_element;
        tmp_recursion_stack_element_list_element = NULL;
        }
      else {
        tmp_recursion_stack_element_list_element =
            tmp_recursion_stack_element_list_element->next_element;
        delete tmp_recursion_stack_element_list_element->previous_element;
        }
      }
    if (mtli_recursion_stack_last_element->previous_element != NULL) {
      mtli_recursion_stack_last_element =
          mtli_recursion_stack_last_element->previous_element;
      delete mtli_recursion_stack_last_element->next_element;
      mtli_recursion_stack_last_element->next_element = NULL;
      }
    else {
      yyerror ("MTL internal error: empty recursion stack pop");
      mtli_garbage_collection ();
      return 1;
      }
    }
  else {
    yyerror ("MTL internal error: empty recursion stack pop");
    mtli_garbage_collection ();
    return 1;
    }
  }              | column_addressing_direction '(' {
  if (mtli_recursion_stack_last_element != NULL) {
    mtli_recursion_stack_last_element->next_element =
        new mtli_Recursion_stack_element;
    assert (mtli_recursion_stack_last_element->next_element != NULL);
        //memory exhausted
    mtli_recursion_stack_last_element->next_element->previous_element =
        mtli_recursion_stack_last_element;
    mtli_recursion_stack_last_element->next_element->next_element = NULL;
    mtli_recursion_stack_last_element->next_element->list_element_list = NULL;
    mtli_recursion_stack_last_element->next_element->
        list_element_list_last_element = NULL;
    mtli_recursion_stack_last_element =
        mtli_recursion_stack_last_element->next_element;
    mtli_Recursion_stack_element_list_element
        *tmp_recursion_stack_element_list_element =
        mtli_recursion_stack_last_element->previous_element->list_element_list;
    unsigned int tmp_return = 0;
    while (tmp_recursion_stack_element_list_element != NULL) {
      switch ($1) {
        case mtl_east: {
          unsigned int first_inserted_chip_operation_list_element = 1;
          for (int column = 0; column < mtli_memory_chip.number_of_columns ();
              column++) {
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element =
                new mtli_Chip_operation_list_element;
            assert (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element !=
                NULL); //memory exhausted
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                next_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element;
            for (unsigned int i = 0; i < 27; i++) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier [i] =
                  tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  previous_element->addressing_identifier [i];
              }
            if (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_row ||
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_row_column) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_row_column;
              }
            else {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_column;
              }
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].column = column;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list = NULL;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list_last_element = NULL;
            if (mtli_recursion_stack_last_element->list_element_list == NULL)
                {
              mtli_recursion_stack_last_element->list_element_list =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->list_element_list !=
                  NULL); //memory exhausted
              mtli_recursion_stack_last_element->list_element_list->
                  previous_element = NULL;
              mtli_recursion_stack_last_element->list_element_list->
                  next_element = NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->list_element_list;
              }
            else {
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element != NULL);
                  //memory exhausted
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->
                  previous_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element;
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->next_element =
                  NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element;
              }
            first_inserted_chip_operation_list_element = 0;
            }
          break;
          }
        case mtl_west: {
          unsigned int first_inserted_chip_operation_list_element = 1;
          for (int column = mtli_memory_chip.number_of_columns () - 1;
              column >= 0; column--) {
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element =
                new mtli_Chip_operation_list_element;
            assert (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element !=
                NULL); //memory exhausted
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                next_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element;
            for (unsigned int i = 0; i < 27; i++) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier [i] =
                  tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  previous_element->addressing_identifier [i];
              }
            if (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_row ||
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_row_column) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_row_column;
              }
            else {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_column;
              }
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].column = column;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list = NULL;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list_last_element = NULL;
            if (mtli_recursion_stack_last_element->list_element_list == NULL)
                {
              mtli_recursion_stack_last_element->list_element_list =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->list_element_list !=
                  NULL); //memory exhausted
              mtli_recursion_stack_last_element->list_element_list->
                  previous_element = NULL;
              mtli_recursion_stack_last_element->list_element_list->
                  next_element = NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->list_element_list;
              }
            else {
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element != NULL);
                  //memory exhausted
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->
                  previous_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element;
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->
                  next_element = NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element;
              }
            first_inserted_chip_operation_list_element = 0;
            }
          break;
          }
        default: {
          yyerror ("MTL internal error: column_addressing_direction not "
              "recognized");
          mtli_garbage_collection ();
          tmp_return = 1; //return from yyparse
          break;
          }
        }
      if (tmp_return == 1) {
        return 1;
        }
      tmp_recursion_stack_element_list_element =
          tmp_recursion_stack_element_list_element->next_element;
      }
    }
  else {
    yyerror ("MTL internal error: empty recursion stack pop");
    mtli_garbage_collection ();
    return 1;
    }
  } row_sub_march_element_list ')' {
  if (mtli_recursion_stack_last_element != NULL) {
    mtli_Recursion_stack_element_list_element
       *tmp_recursion_stack_element_list_element =
       mtli_recursion_stack_last_element->list_element_list;
    while (tmp_recursion_stack_element_list_element != NULL) {
      if (tmp_recursion_stack_element_list_element->next_element == NULL) {
        delete tmp_recursion_stack_element_list_element;
        tmp_recursion_stack_element_list_element = NULL;
        }
      else {
        tmp_recursion_stack_element_list_element =
            tmp_recursion_stack_element_list_element->next_element;
        delete tmp_recursion_stack_element_list_element->previous_element;
        }
      }
    if (mtli_recursion_stack_last_element->previous_element != NULL) {
      mtli_recursion_stack_last_element =
          mtli_recursion_stack_last_element->previous_element;
      delete mtli_recursion_stack_last_element->next_element;
      mtli_recursion_stack_last_element->next_element = NULL;
      }
    else {
      yyerror ("MTL internal error: empty recursion stack pop");
      mtli_garbage_collection ();
      return 1;
      }
    }
  else {
    yyerror ("MTL internal error: empty recursion stack pop");
    mtli_garbage_collection ();
    return 1;
    }
  }              | column_addressing_direction addressing_id '(' {
  if (mtli_recursion_stack_last_element != NULL) {
    mtli_recursion_stack_last_element->next_element =
        new mtli_Recursion_stack_element;
    assert (mtli_recursion_stack_last_element->next_element != NULL);
        //memory exhausted
    mtli_recursion_stack_last_element->next_element->previous_element =
        mtli_recursion_stack_last_element;
    mtli_recursion_stack_last_element->next_element->next_element = NULL;
    mtli_recursion_stack_last_element->next_element->list_element_list = NULL;
    mtli_recursion_stack_last_element->next_element->
        list_element_list_last_element = NULL;
    mtli_recursion_stack_last_element =
        mtli_recursion_stack_last_element->next_element;
    mtli_Recursion_stack_element_list_element
        *tmp_recursion_stack_element_list_element =
        mtli_recursion_stack_last_element->previous_element->list_element_list;
    unsigned int tmp_return = 0;
    while (tmp_recursion_stack_element_list_element != NULL) {
      switch ($1) {
        case mtl_east: {
          unsigned int first_inserted_chip_operation_list_element = 1;
          for (int column = 0; column < mtli_memory_chip.number_of_columns ();
              column++) {
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element =
                new mtli_Chip_operation_list_element;
            assert (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element !=
                NULL); //memory exhausted
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                next_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element;
            for (unsigned int i = 0; i < 27; i++) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier [i] =
                  tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  previous_element->addressing_identifier [i];
              }
            if (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_row ||
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_row_column) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_row_column;
              }
            else {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_column;
              }
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].column = column;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[$2].status = mtl_column;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[$2].column = column;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list = NULL;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list_last_element = NULL;
            if (mtli_recursion_stack_last_element->list_element_list == NULL)
                {
              mtli_recursion_stack_last_element->list_element_list =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->list_element_list !=
                  NULL); //memory exhausted
              mtli_recursion_stack_last_element->list_element_list->
                  previous_element = NULL;
              mtli_recursion_stack_last_element->list_element_list->
                  next_element = NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->list_element_list;
              }
            else {
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element != NULL);
                  //memory exhausted
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->
                  previous_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element;
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->next_element =
                  NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element;
              }
            first_inserted_chip_operation_list_element = 0;
            }
          break;
          }
        case mtl_west: {
          unsigned int first_inserted_chip_operation_list_element = 1;
          for (int column = mtli_memory_chip.number_of_columns () - 1;
              column >= 0; column--) {
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element =
                new mtli_Chip_operation_list_element;
            assert (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element !=
                NULL); //memory exhausted
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                next_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element;
            for (unsigned int i = 0; i < 27; i++) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier [i] =
                  tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  previous_element->addressing_identifier [i];
              }
            if (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_row ||
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_row_column) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_row_column;
              }
            else {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_column;
              }
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].column = column;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[$2].status = mtl_column;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[$2].column = column;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list = NULL;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list_last_element = NULL;
            if (mtli_recursion_stack_last_element->list_element_list == NULL)
                {
              mtli_recursion_stack_last_element->list_element_list =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->list_element_list !=
                  NULL); //memory exhausted
              mtli_recursion_stack_last_element->list_element_list->
                  previous_element = NULL;
              mtli_recursion_stack_last_element->list_element_list->
                  next_element = NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->list_element_list;
              }
            else {
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element != NULL);
                  //memory exhausted
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->
                  previous_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element;
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->
                  next_element = NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element;
              }
            first_inserted_chip_operation_list_element = 0;
            }
          break;
          }
        default: {
          yyerror ("MTL internal error: column_addressing_direction not "
              "recognized");
          mtli_garbage_collection ();
          tmp_return = 1; //return from yyparse
          break;
          }
        }
      if (tmp_return == 1) {
        return 1;
        }
      tmp_recursion_stack_element_list_element =
          tmp_recursion_stack_element_list_element->next_element;
      }
    }
  else {
    yyerror ("MTL internal error: empty recursion stack pop");
    mtli_garbage_collection ();
    return 1;
    }
  } row_sub_march_element_list ')' {
  if (mtli_recursion_stack_last_element != NULL) {
    mtli_Recursion_stack_element_list_element
       *tmp_recursion_stack_element_list_element =
       mtli_recursion_stack_last_element->list_element_list;
    while (tmp_recursion_stack_element_list_element != NULL) {
      if (tmp_recursion_stack_element_list_element->next_element == NULL) {
        delete tmp_recursion_stack_element_list_element;
        tmp_recursion_stack_element_list_element = NULL;
        }
      else {
        tmp_recursion_stack_element_list_element =
            tmp_recursion_stack_element_list_element->next_element;
        delete tmp_recursion_stack_element_list_element->previous_element;
        }
      }
    if (mtli_recursion_stack_last_element->previous_element != NULL) {
      mtli_recursion_stack_last_element =
          mtli_recursion_stack_last_element->previous_element;
      delete mtli_recursion_stack_last_element->next_element;
      mtli_recursion_stack_last_element->next_element = NULL;
      }
    else {
      yyerror ("MTL internal error: empty recursion stack pop");
      mtli_garbage_collection ();
      return 1;
      }
    }
  else {
    yyerror ("MTL internal error: empty recursion stack pop");
    mtli_garbage_collection ();
    return 1;
    }
  };

column_sub_march_element_list: column_sub_march_element {
  }                          | column_sub_march_element column_sub_march_element_list {
  };

column_sub_march_element: column_addressing_direction '(' {
  if (mtli_recursion_stack_last_element != NULL) {
    mtli_recursion_stack_last_element->next_element =
        new mtli_Recursion_stack_element;
    assert (mtli_recursion_stack_last_element->next_element != NULL);
        //memory exhausted
    mtli_recursion_stack_last_element->next_element->previous_element =
        mtli_recursion_stack_last_element;
    mtli_recursion_stack_last_element->next_element->next_element = NULL;
    mtli_recursion_stack_last_element->next_element->list_element_list = NULL;
    mtli_recursion_stack_last_element->next_element->
        list_element_list_last_element = NULL;
    mtli_recursion_stack_last_element =
        mtli_recursion_stack_last_element->next_element;
    mtli_Recursion_stack_element_list_element
        *tmp_recursion_stack_element_list_element =
        mtli_recursion_stack_last_element->previous_element->list_element_list;
    unsigned int tmp_return = 0;
    while (tmp_recursion_stack_element_list_element != NULL) {
      switch ($1) {
        case mtl_east: {
          unsigned int first_inserted_chip_operation_list_element = 1;
          for (int column = 0; column < mtli_memory_chip.number_of_columns ();
              column++) {
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element =
                new mtli_Chip_operation_list_element;
            assert (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element !=
                NULL); //memory exhausted
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                next_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element;
            for (unsigned int i = 0; i < 27; i++) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier [i] =
                  tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  previous_element->addressing_identifier [i];
              }
            if (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_row ||
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_row_column) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_row_column;
              }
            else {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_column;
              }
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].column = column;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list = NULL;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list_last_element = NULL;
            if (mtli_recursion_stack_last_element->list_element_list == NULL)
                {
              mtli_recursion_stack_last_element->list_element_list =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->list_element_list !=
                  NULL); //memory exhausted
              mtli_recursion_stack_last_element->list_element_list->
                  previous_element = NULL;
              mtli_recursion_stack_last_element->list_element_list->
                  next_element = NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->list_element_list;
              }
            else {
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element != NULL);
                  //memory exhausted
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->
                  previous_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element;
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->next_element =
                  NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element;
              }
            first_inserted_chip_operation_list_element = 0;
            }
          break;
          }
        case mtl_west: {
          unsigned int first_inserted_chip_operation_list_element = 1;
          for (int column = mtli_memory_chip.number_of_columns () - 1;
              column >= 0; column--) {
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element =
                new mtli_Chip_operation_list_element;
            assert (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element !=
                NULL); //memory exhausted
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                next_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element;
            for (unsigned int i = 0; i < 27; i++) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier [i] =
                  tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  previous_element->addressing_identifier [i];
              }
            if (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_row ||
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_row_column) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_row_column;
              }
            else {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_column;
              }
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].column = column;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list = NULL;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list_last_element = NULL;
            if (mtli_recursion_stack_last_element->list_element_list == NULL)
                {
              mtli_recursion_stack_last_element->list_element_list =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->list_element_list !=
                  NULL); //memory exhausted
              mtli_recursion_stack_last_element->list_element_list->
                  previous_element = NULL;
              mtli_recursion_stack_last_element->list_element_list->
                  next_element = NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->list_element_list;
              }
            else {
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element != NULL);
                  //memory exhausted
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->
                  previous_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element;
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->
                  next_element = NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element;
              }
            first_inserted_chip_operation_list_element = 0;
            }
          break;
          }
        default: {
          yyerror ("MTL internal error: column_addressing_direction not "
              "recognized");
          mtli_garbage_collection ();
          tmp_return = 1; //return from yyparse
          break;
          }
        }
      if (tmp_return == 1) {
        return 1;
        }
      tmp_recursion_stack_element_list_element =
          tmp_recursion_stack_element_list_element->next_element;
      }
    }
  else {
    yyerror ("MTL internal error: empty recursion stack pop");
    mtli_garbage_collection ();
    return 1;
    }
  } sub_march_element_list ')' {
  if (mtli_recursion_stack_last_element != NULL) {
    mtli_Recursion_stack_element_list_element
       *tmp_recursion_stack_element_list_element =
       mtli_recursion_stack_last_element->list_element_list;
    while (tmp_recursion_stack_element_list_element != NULL) {
      if (tmp_recursion_stack_element_list_element->next_element == NULL) {
        delete tmp_recursion_stack_element_list_element;
        tmp_recursion_stack_element_list_element = NULL;
        }
      else {
        tmp_recursion_stack_element_list_element =
            tmp_recursion_stack_element_list_element->next_element;
        delete tmp_recursion_stack_element_list_element->previous_element;
        }
      }
    if (mtli_recursion_stack_last_element->previous_element != NULL) {
      mtli_recursion_stack_last_element =
          mtli_recursion_stack_last_element->previous_element;
      delete mtli_recursion_stack_last_element->next_element;
      mtli_recursion_stack_last_element->next_element = NULL;
      }
    else {
      yyerror ("MTL internal error: empty recursion stack pop");
      mtli_garbage_collection ();
      return 1;
      }
    }
  else {
    yyerror ("MTL internal error: empty recursion stack pop");
    mtli_garbage_collection ();
    return 1;
    }
  }                     | column_addressing_direction addressing_id '(' {
  if (mtli_recursion_stack_last_element != NULL) {
    mtli_recursion_stack_last_element->next_element =
        new mtli_Recursion_stack_element;
    assert (mtli_recursion_stack_last_element->next_element != NULL);
        //memory exhausted
    mtli_recursion_stack_last_element->next_element->previous_element =
        mtli_recursion_stack_last_element;
    mtli_recursion_stack_last_element->next_element->next_element = NULL;
    mtli_recursion_stack_last_element->next_element->list_element_list = NULL;
    mtli_recursion_stack_last_element->next_element->
        list_element_list_last_element = NULL;
    mtli_recursion_stack_last_element =
        mtli_recursion_stack_last_element->next_element;
    mtli_Recursion_stack_element_list_element
        *tmp_recursion_stack_element_list_element =
        mtli_recursion_stack_last_element->previous_element->list_element_list;
    unsigned int tmp_return = 0;
    while (tmp_recursion_stack_element_list_element != NULL) {
      switch ($1) {
        case mtl_east: {
          unsigned int first_inserted_chip_operation_list_element = 1;
          for (int column = 0; column < mtli_memory_chip.number_of_columns ();
              column++) {
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element =
                new mtli_Chip_operation_list_element;
            assert (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element !=
                NULL); //memory exhausted
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                next_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element;
            for (unsigned int i = 0; i < 27; i++) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier [i] =
                  tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  previous_element->addressing_identifier [i];
              }
            if (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_row ||
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_row_column) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_row_column;
              }
            else {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_column;
              }
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].column = column;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[$2].status = mtl_column;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[$2].column = column;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list = NULL;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list_last_element = NULL;
            if (mtli_recursion_stack_last_element->list_element_list == NULL)
                {
              mtli_recursion_stack_last_element->list_element_list =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->list_element_list !=
                  NULL); //memory exhausted
              mtli_recursion_stack_last_element->list_element_list->
                  previous_element = NULL;
              mtli_recursion_stack_last_element->list_element_list->
                  next_element = NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->list_element_list;
              }
            else {
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element != NULL);
                  //memory exhausted
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->
                  previous_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element;
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->next_element =
                  NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element;
              }
            first_inserted_chip_operation_list_element = 0;
            }
          break;
          }
        case mtl_west: {
          unsigned int first_inserted_chip_operation_list_element = 1;
          for (int column = mtli_memory_chip.number_of_columns () - 1;
              column >= 0; column--) {
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element =
                new mtli_Chip_operation_list_element;
            assert (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element !=
                NULL); //memory exhausted
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                next_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element;
            for (unsigned int i = 0; i < 27; i++) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier [i] =
                  tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  previous_element->addressing_identifier [i];
              }
            if (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_row ||
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_row_column) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_row_column;
              }
            else {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_column;
              }
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].column = column;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[$2].status = mtl_column;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[$2].column = column;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list = NULL;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list_last_element = NULL;
            if (mtli_recursion_stack_last_element->list_element_list == NULL)
                {
              mtli_recursion_stack_last_element->list_element_list =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->list_element_list !=
                  NULL); //memory exhausted
              mtli_recursion_stack_last_element->list_element_list->
                  previous_element = NULL;
              mtli_recursion_stack_last_element->list_element_list->
                  next_element = NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->list_element_list;
              }
            else {
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element != NULL);
                  //memory exhausted
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->
                  previous_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element;
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->
                  next_element = NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element;
              }
            first_inserted_chip_operation_list_element = 0;
            }
          break;
          }
        default: {
          yyerror ("MTL internal error: column_addressing_direction not "
              "recognized");
          mtli_garbage_collection ();
          tmp_return = 1; //return from yyparse
          break;
          }
        }
      if (tmp_return == 1) {
        return 1;
        }
      tmp_recursion_stack_element_list_element =
          tmp_recursion_stack_element_list_element->next_element;
      }
    }
  else {
    yyerror ("MTL internal error: empty recursion stack pop");
    mtli_garbage_collection ();
    return 1;
    }
  } sub_march_element_list ')' {
  if (mtli_recursion_stack_last_element != NULL) {
    mtli_Recursion_stack_element_list_element
       *tmp_recursion_stack_element_list_element =
       mtli_recursion_stack_last_element->list_element_list;
    while (tmp_recursion_stack_element_list_element != NULL) {
      if (tmp_recursion_stack_element_list_element->next_element == NULL) {
        delete tmp_recursion_stack_element_list_element;
        tmp_recursion_stack_element_list_element = NULL;
        }
      else {
        tmp_recursion_stack_element_list_element =
            tmp_recursion_stack_element_list_element->next_element;
        delete tmp_recursion_stack_element_list_element->previous_element;
        }
      }
    if (mtli_recursion_stack_last_element->previous_element != NULL) {
      mtli_recursion_stack_last_element =
          mtli_recursion_stack_last_element->previous_element;
      delete mtli_recursion_stack_last_element->next_element;
      mtli_recursion_stack_last_element->next_element = NULL;
      }
    else {
      yyerror ("MTL internal error: empty recursion stack pop");
      mtli_garbage_collection ();
      return 1;
      }
    }
  else {
    yyerror ("MTL internal error: empty recursion stack pop");
    mtli_garbage_collection ();
    return 1;
    }
  }                     | time_operation {
  };

row_sub_march_element_list: row_sub_march_element {
  }                       | row_sub_march_element ',' row_sub_march_element_list {
  };

row_sub_march_element: row_addressing_direction '(' {
  if (mtli_recursion_stack_last_element != NULL) {
    mtli_recursion_stack_last_element->next_element =
        new mtli_Recursion_stack_element;
    assert (mtli_recursion_stack_last_element->next_element != NULL);
        //memory exhausted
    mtli_recursion_stack_last_element->next_element->previous_element =
        mtli_recursion_stack_last_element;
    mtli_recursion_stack_last_element->next_element->next_element = NULL;
    mtli_recursion_stack_last_element->next_element->list_element_list = NULL;
    mtli_recursion_stack_last_element->next_element->
        list_element_list_last_element = NULL;
    mtli_recursion_stack_last_element =
        mtli_recursion_stack_last_element->next_element;
    mtli_Recursion_stack_element_list_element
        *tmp_recursion_stack_element_list_element =
        mtli_recursion_stack_last_element->previous_element->list_element_list;
    unsigned int tmp_return = 0;
    while (tmp_recursion_stack_element_list_element != NULL) {
      switch ($1) {
        case mtl_south: {
          unsigned int first_inserted_chip_operation_list_element = 1;
          for (int row = 0; row < mtli_memory_chip.number_of_rows (); row++) {
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element =
                new mtli_Chip_operation_list_element;
            assert (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element !=
                NULL); //memory exhausted
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                next_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element;
            for (unsigned int i = 0; i < 27; i++) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier [i] =
                  tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  previous_element->addressing_identifier [i];
              }
            if (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_column ||
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_row_column) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_row_column;
              }
            else {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_row;
              }
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].row = row;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list = NULL;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list_last_element = NULL;
            if (mtli_recursion_stack_last_element->list_element_list == NULL)
                {
              mtli_recursion_stack_last_element->list_element_list =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->list_element_list !=
                  NULL); //memory exhausted
              mtli_recursion_stack_last_element->list_element_list->
                  previous_element = NULL;
              mtli_recursion_stack_last_element->list_element_list->
                  next_element = NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->list_element_list;
              }
            else {
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element != NULL);
                  //memory exhausted
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->
                  previous_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element;
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->next_element =
                  NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element;
              }
            first_inserted_chip_operation_list_element = 0;
            }
          break;
          }
        case mtl_north: {
          unsigned int first_inserted_chip_operation_list_element = 1;
          for (int row = mtli_memory_chip.number_of_rows () - 1; row >= 0;
              row--) {
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element =
                new mtli_Chip_operation_list_element;
            assert (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element !=
                NULL); //memory exhausted
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                next_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element;
            for (unsigned int i = 0; i < 27; i++) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier [i] =
                  tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  previous_element->addressing_identifier [i];
              }
            if (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_column ||
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_row_column) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_row_column;
              }
            else {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_row;
              }
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].row = row;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list = NULL;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list_last_element = NULL;
            if (mtli_recursion_stack_last_element->list_element_list == NULL)
                {
              mtli_recursion_stack_last_element->list_element_list =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->list_element_list !=
                  NULL); //memory exhausted
              mtli_recursion_stack_last_element->list_element_list->
                  previous_element = NULL;
              mtli_recursion_stack_last_element->list_element_list->
                  next_element = NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->list_element_list;
              }
            else {
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element != NULL);
                  //memory exhausted
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->
                  previous_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element;
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->
                  next_element = NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element;
              }
            first_inserted_chip_operation_list_element = 0;
            }
          break;
          }
        default: {
          yyerror ("MTL internal error: row_addressing_direction not "
              "recognized");
          mtli_garbage_collection ();
          tmp_return = 1; //return from yyparse
          break;
          }
        }
      if (tmp_return == 1) {
        return 1;
        }
      tmp_recursion_stack_element_list_element =
          tmp_recursion_stack_element_list_element->next_element;
      }
    }
  else {
    yyerror ("MTL internal error: empty recursion stack pop");
    mtli_garbage_collection ();
    return 1;
    }
  } sub_march_element_list ')' {
  if (mtli_recursion_stack_last_element != NULL) {
    mtli_Recursion_stack_element_list_element
       *tmp_recursion_stack_element_list_element =
       mtli_recursion_stack_last_element->list_element_list;
    while (tmp_recursion_stack_element_list_element != NULL) {
      if (tmp_recursion_stack_element_list_element->next_element == NULL) {
        delete tmp_recursion_stack_element_list_element;
        tmp_recursion_stack_element_list_element = NULL;
        }
      else {
        tmp_recursion_stack_element_list_element =
            tmp_recursion_stack_element_list_element->next_element;
        delete tmp_recursion_stack_element_list_element->previous_element;
        }
      }
    if (mtli_recursion_stack_last_element->previous_element != NULL) {
      mtli_recursion_stack_last_element =
          mtli_recursion_stack_last_element->previous_element;
      delete mtli_recursion_stack_last_element->next_element;
      mtli_recursion_stack_last_element->next_element = NULL;
      }
    else {
      yyerror ("MTL internal error: empty recursion stack pop");
      mtli_garbage_collection ();
      return 1;
      }
    }
  else {
    yyerror ("MTL internal error: empty recursion stack pop");
    mtli_garbage_collection ();
    return 1;
    }
  }                  | row_addressing_direction addressing_id '(' {
  if (mtli_recursion_stack_last_element != NULL) {
    mtli_recursion_stack_last_element->next_element =
        new mtli_Recursion_stack_element;
    assert (mtli_recursion_stack_last_element->next_element != NULL);
        //memory exhausted
    mtli_recursion_stack_last_element->next_element->previous_element =
        mtli_recursion_stack_last_element;
    mtli_recursion_stack_last_element->next_element->next_element = NULL;
    mtli_recursion_stack_last_element->next_element->list_element_list = NULL;
    mtli_recursion_stack_last_element->next_element->
        list_element_list_last_element = NULL;
    mtli_recursion_stack_last_element =
        mtli_recursion_stack_last_element->next_element;
    mtli_Recursion_stack_element_list_element
        *tmp_recursion_stack_element_list_element =
        mtli_recursion_stack_last_element->previous_element->list_element_list;
    unsigned int tmp_return = 0;
    while (tmp_recursion_stack_element_list_element != NULL) {
      switch ($1) {
        case mtl_south: {
          unsigned int first_inserted_chip_operation_list_element = 1;
          for (int row = 0; row < mtli_memory_chip.number_of_rows (); row++) {
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element =
                new mtli_Chip_operation_list_element;
            assert (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element !=
                NULL); //memory exhausted
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                next_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element;
            for (unsigned int i = 0; i < 27; i++) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier [i] =
                  tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  previous_element->addressing_identifier [i];
              }
            if (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_column ||
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_row_column) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_row_column;
              }
            else {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_row;
              }
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].row = row;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[$2].status = mtl_row;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[$2].row = row;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list = NULL;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list_last_element = NULL;
            if (mtli_recursion_stack_last_element->list_element_list == NULL)
                {
              mtli_recursion_stack_last_element->list_element_list =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->list_element_list !=
                  NULL); //memory exhausted
              mtli_recursion_stack_last_element->list_element_list->
                  previous_element = NULL;
              mtli_recursion_stack_last_element->list_element_list->
                  next_element = NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->list_element_list;
              }
            else {
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element != NULL);
                  //memory exhausted
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->
                  previous_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element;
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->next_element =
                  NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element;
              }
            first_inserted_chip_operation_list_element = 0;
            }
          break;
          }
        case mtl_north: {
          unsigned int first_inserted_chip_operation_list_element = 1;
          for (int row = mtli_memory_chip.number_of_rows () - 1; row >= 0;
              row--) {
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element =
                new mtli_Chip_operation_list_element;
            assert (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element !=
                NULL); //memory exhausted
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                next_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element;
            for (unsigned int i = 0; i < 27; i++) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier [i] =
                  tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  previous_element->addressing_identifier [i];
              }
            if (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_column ||
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_row_column) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_row_column;
              }
            else {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_row;
              }
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].row = row;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[$2].status = mtl_row;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[$2].row = row;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list = NULL;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list_last_element = NULL;
            if (mtli_recursion_stack_last_element->list_element_list == NULL)
                {
              mtli_recursion_stack_last_element->list_element_list =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->list_element_list !=
                  NULL); //memory exhausted
              mtli_recursion_stack_last_element->list_element_list->
                  previous_element = NULL;
              mtli_recursion_stack_last_element->list_element_list->
                  next_element = NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->list_element_list;
              }
            else {
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element != NULL);
                  //memory exhausted
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->
                  previous_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element;
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->
                  next_element = NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element;
              }
            first_inserted_chip_operation_list_element = 0;
            }
          break;
          }
        default: {
          yyerror ("MTL internal error: row_addressing_direction not "
              "recognized");
          mtli_garbage_collection ();
          tmp_return = 1; //return from yyparse
          break;
          }
        }
      if (tmp_return == 1) {
        return 1;
        }
      tmp_recursion_stack_element_list_element =
          tmp_recursion_stack_element_list_element->next_element;
      }
    }
  else {
    yyerror ("MTL internal error: empty recursion stack pop");
    mtli_garbage_collection ();
    return 1;
    }
  } sub_march_element_list ')' {
  if (mtli_recursion_stack_last_element != NULL) {
    mtli_Recursion_stack_element_list_element
       *tmp_recursion_stack_element_list_element =
       mtli_recursion_stack_last_element->list_element_list;
    while (tmp_recursion_stack_element_list_element != NULL) {
      if (tmp_recursion_stack_element_list_element->next_element == NULL) {
        delete tmp_recursion_stack_element_list_element;
        tmp_recursion_stack_element_list_element = NULL;
        }
      else {
        tmp_recursion_stack_element_list_element =
            tmp_recursion_stack_element_list_element->next_element;
        delete tmp_recursion_stack_element_list_element->previous_element;
        }
      }
    if (mtli_recursion_stack_last_element->previous_element != NULL) {
      mtli_recursion_stack_last_element =
          mtli_recursion_stack_last_element->previous_element;
      delete mtli_recursion_stack_last_element->next_element;
      mtli_recursion_stack_last_element->next_element = NULL;
      }
    else {
      yyerror ("MTL internal error: empty recursion stack pop");
      mtli_garbage_collection ();
      return 1;
      }
    }
  else {
    yyerror ("MTL internal error: empty recursion stack pop");
    mtli_garbage_collection ();
    return 1;
    }
  }                  | time_operation {
  };

sub_march_element_list: sub_march_element {
  }                   | sub_march_element ',' sub_march_element_list {
  };

sub_march_element: addressing_specifier '(' {
  if (mtli_recursion_stack_last_element != NULL) {
    mtli_recursion_stack_last_element->next_element =
        new mtli_Recursion_stack_element;
    assert (mtli_recursion_stack_last_element->next_element != NULL);
        //memory exhausted
    mtli_recursion_stack_last_element->next_element->previous_element =
        mtli_recursion_stack_last_element;
    mtli_recursion_stack_last_element->next_element->next_element = NULL;
    mtli_recursion_stack_last_element->next_element->list_element_list = NULL;
    mtli_recursion_stack_last_element->next_element->
        list_element_list_last_element = NULL;
    mtli_recursion_stack_last_element =
        mtli_recursion_stack_last_element->next_element;
    mtli_Recursion_stack_element_list_element
        *tmp_recursion_stack_element_list_element =
        mtli_recursion_stack_last_element->previous_element->list_element_list;
    unsigned int tmp_return = 0;
    while (tmp_recursion_stack_element_list_element != NULL) {
      switch ($1.addressing_direction) {
        case mtl_down: {
          if (current_memory_type.address_order == column_first) {
            if (current_memory_type.row_order == top_first) {
              if (current_memory_type.column_order == left_first) {
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int row = mtli_memory_chip.number_of_rows () - 1;
                    row >= 0; row--) {
                  for (int column = mtli_memory_chip.number_of_columns () - 1;
                      column >= 0; column--) {
                    if ($1.addressing_exclusion != 0) {
                      if (tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier[$1.addressing_exclusion].
                          status == mtl_row_column) {
                        if (row == tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element->
                            addressing_identifier[$1.addressing_exclusion].
                            row && column ==
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element->
                            addressing_identifier[$1.addressing_exclusion].
                            column) {
                          continue;
                          }
                        }
                      else {
                        yyerror ("MTL interpreter error: excluded addressing "
                            "identifier not assigned to a 1-dimensional "
                            "addressing direction");
                        mtli_garbage_collection ();
                        tmp_return = 1; //return from yyparse
                        break;
                        }
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              else { //right_first
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int row = mtli_memory_chip.number_of_rows () - 1;
                    row >= 0; row--) {
                  for (int column = 0;
                      column < mtli_memory_chip.number_of_columns ();
                      column++) {
                    if ($1.addressing_exclusion != 0) {
                      if (tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier[$1.addressing_exclusion].
                          status == mtl_row_column) {
                        if (row == tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element->
                            addressing_identifier[$1.addressing_exclusion].
                            row && column ==
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element->
                            addressing_identifier[$1.addressing_exclusion].
                            column) {
                          continue;
                          }
                        }
                      else {
                        yyerror ("MTL interpreter error: excluded addressing "
                            "identifier not assigned to a 1-dimensional "
                            "addressing direction");
                        mtli_garbage_collection ();
                        tmp_return = 1; //return from yyparse
                        break;
                        }
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              }
            else { //bottom_first
              if (current_memory_type.column_order == left_first) {
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int row = 0; row < mtli_memory_chip.number_of_rows ();
                    row++) {
                  for (int column = mtli_memory_chip.number_of_columns () - 1;
                      column >= 0; column--) {
                    if ($1.addressing_exclusion != 0) {
                      if (tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier[$1.addressing_exclusion].
                          status == mtl_row_column) {
                        if (row == tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element->
                            addressing_identifier[$1.addressing_exclusion].
                            row && column ==
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element->
                            addressing_identifier[$1.addressing_exclusion].
                            column) {
                          continue;
                          }
                        }
                      else {
                        yyerror ("MTL interpreter error: excluded addressing "
                            "identifier not assigned to a 1-dimensional "
                            "addressing direction");
                        mtli_garbage_collection ();
                        tmp_return = 1; //return from yyparse
                        break;
                        }
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              else { //right_first
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int row = 0; row < mtli_memory_chip.number_of_rows ();
                    row++) {
                  for (int column = 0;
                      column < mtli_memory_chip.number_of_columns ();
                      column++) {
                    if ($1.addressing_exclusion != 0) {
                      if (tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier[$1.addressing_exclusion].
                          status == mtl_row_column) {
                        if (row == tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element->
                            addressing_identifier[$1.addressing_exclusion].
                            row && column ==
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element->
                            addressing_identifier[$1.addressing_exclusion].
                            column) {
                          continue;
                          }
                        }
                      else {
                        yyerror ("MTL interpreter error: excluded addressing "
                            "identifier not assigned to a 1-dimensional "
                            "addressing direction");
                        mtli_garbage_collection ();
                        tmp_return = 1; //return from yyparse
                        break;
                        }
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              }
            }
          else { //row_first
            if (current_memory_type.row_order == top_first) {
              if (current_memory_type.column_order == left_first) {
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int column = mtli_memory_chip.number_of_columns () - 1;
                    column >= 0; column--)
                    {
                  for (int row = mtli_memory_chip.number_of_rows () - 1;
                      row >= 0; row--) {
                    if ($1.addressing_exclusion != 0) {
                      if (tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier[$1.addressing_exclusion].
                          status == mtl_row_column) {
                        if (row == tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element->
                            addressing_identifier[$1.addressing_exclusion].
                            row && column ==
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element->
                            addressing_identifier[$1.addressing_exclusion].
                            column) {
                          continue;
                          }
                        }
                      else {
                        yyerror ("MTL interpreter error: excluded addressing "
                            "identifier not assigned to a 1-dimensional "
                            "addressing direction");
                        mtli_garbage_collection ();
                        tmp_return = 1; //return from yyparse
                        break;
                        }
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              else { //right_first
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int column = 0;
                    column < mtli_memory_chip.number_of_columns (); column++)
                    { 
                  for (int row = mtli_memory_chip.number_of_rows () - 1;
                      row >= 0; row--) {
                    if ($1.addressing_exclusion != 0) {
                      if (tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier[$1.addressing_exclusion].
                          status == mtl_row_column) {
                        if (row == tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element->
                            addressing_identifier[$1.addressing_exclusion].
                            row && column ==
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element->
                            addressing_identifier[$1.addressing_exclusion].
                            column) {
                          continue;
                          }
                        }
                      else {
                        yyerror ("MTL interpreter error: excluded addressing "
                            "identifier not assigned to a 1-dimensional "
                            "addressing direction");
                        mtli_garbage_collection ();
                        tmp_return = 1; //return from yyparse
                        break;
                        }
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              }
            else { //bottom_first
              if (current_memory_type.column_order == left_first) {
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int column = mtli_memory_chip.number_of_columns () - 1;
                    column >= 0; column--)
                    {
                  for (int row = 0; row < mtli_memory_chip.number_of_rows ();
                      row++) {
                    if ($1.addressing_exclusion != 0) {
                      if (tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier[$1.addressing_exclusion].
                          status == mtl_row_column) {
                        if (row == tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element->
                            addressing_identifier[$1.addressing_exclusion].
                            row && column ==
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element->
                            addressing_identifier[$1.addressing_exclusion].
                            column) {
                          continue;
                          }
                        }
                      else {
                        yyerror ("MTL interpreter error: excluded addressing "
                            "identifier not assigned to a 1-dimensional "
                            "addressing direction");
                        mtli_garbage_collection ();
                        tmp_return = 1; //return from yyparse
                        break;
                        }
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              else { //right_first
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int column = 0;
                    column < mtli_memory_chip.number_of_columns (); column++)
                    {
                  for (int row = 0;
                      row < mtli_memory_chip.number_of_rows (); row++) {
                    if ($1.addressing_exclusion != 0) {
                      if (tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier[$1.addressing_exclusion].
                          status == mtl_row_column) {
                        if (row == tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element->
                            addressing_identifier[$1.addressing_exclusion].
                            row && column ==
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element->
                            addressing_identifier[$1.addressing_exclusion].
                            column) {
                          continue;
                          }
                        }
                      else {
                        yyerror ("MTL interpreter error: excluded addressing "
                            "identifier not assigned to a 1-dimensional "
                            "addressing direction");
                        mtli_garbage_collection ();
                        tmp_return = 1; //return from yyparse
                        break;
                        }
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              }
            }
          break;
          }
        case mtl_up: {
          if (current_memory_type.address_order == column_first) {
            if (current_memory_type.row_order == top_first) {
              if (current_memory_type.column_order == left_first) {
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int row = 0; row < mtli_memory_chip.number_of_rows ();
                    row++) {
                  for (int column = 0;
                      column < mtli_memory_chip.number_of_columns ();
                      column++) {
                    if ($1.addressing_exclusion != 0) {
                      if (tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier[$1.addressing_exclusion].
                          status == mtl_row_column) {
                        if (row == tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element->
                            addressing_identifier[$1.addressing_exclusion].
                            row && column ==
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element->
                            addressing_identifier[$1.addressing_exclusion].
                            column) {
                          continue;
                          }
                        }
                      else {
                        yyerror ("MTL interpreter error: excluded addressing "
                            "identifier not assigned to a 1-dimensional "
                            "addressing direction");
                        mtli_garbage_collection ();
                        tmp_return = 1; //return from yyparse
                        break;
                        }
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              else { //right_first
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int row = 0; row < mtli_memory_chip.number_of_rows ();
                    row++) {
                  for (int column = mtli_memory_chip.number_of_columns () - 1;
                      column >= 0; column--) {
                    if ($1.addressing_exclusion != 0) {
                      if (tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier[$1.addressing_exclusion].
                          status == mtl_row_column) {
                        if (row == tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element->
                            addressing_identifier[$1.addressing_exclusion].
                            row && column ==
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element->
                            addressing_identifier[$1.addressing_exclusion].
                            column) {
                          continue;
                          }
                        }
                      else {
                        yyerror ("MTL interpreter error: excluded addressing "
                            "identifier not assigned to a 1-dimensional "
                            "addressing direction");
                        mtli_garbage_collection ();
                        tmp_return = 1; //return from yyparse
                        break;
                        }
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              }
            else { //bottom_first
              if (current_memory_type.column_order == left_first) {
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int row = mtli_memory_chip.number_of_rows () - 1;
                    row >= 0; row--) {
                  for (int column = 0;
                      column < mtli_memory_chip.number_of_columns ();
                      column++) {
                    if ($1.addressing_exclusion != 0) {
                      if (tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier[$1.addressing_exclusion].
                          status == mtl_row_column) {
                        if (row == tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element->
                            addressing_identifier[$1.addressing_exclusion].
                            row && column ==
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element->
                            addressing_identifier[$1.addressing_exclusion].
                            column) {
                          continue;
                          }
                        }
                      else {
                        yyerror ("MTL interpreter error: excluded addressing "
                            "identifier not assigned to a 1-dimensional "
                            "addressing direction");
                        mtli_garbage_collection ();
                        tmp_return = 1; //return from yyparse
                        break;
                        }
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              else { //right_first
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int row = mtli_memory_chip.number_of_rows () - 1;
                    row >= 0; row--) {
                  for (int column = mtli_memory_chip.number_of_columns () - 1;
                      column >= 0; column--) {
                    if ($1.addressing_exclusion != 0) {
                      if (tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier[$1.addressing_exclusion].
                          status == mtl_row_column) {
                        if (row == tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element->
                            addressing_identifier[$1.addressing_exclusion].
                            row && column ==
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element->
                            addressing_identifier[$1.addressing_exclusion].
                            column) {
                          continue;
                          }
                        }
                      else {
                        yyerror ("MTL interpreter error: excluded addressing "
                            "identifier not assigned to a 1-dimensional "
                            "addressing direction");
                        mtli_garbage_collection ();
                        tmp_return = 1; //return from yyparse
                        break;
                        }
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              }
            }
          else { //row_first
            if (current_memory_type.row_order == top_first) {
              if (current_memory_type.column_order == left_first) {
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int column = 0;
                    column < mtli_memory_chip.number_of_columns (); column++)
                    {
                  for (int row = 0; row < mtli_memory_chip.number_of_rows ();
                      row++) {
                    if ($1.addressing_exclusion != 0) {
                      if (tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier[$1.addressing_exclusion].
                          status == mtl_row_column) {
                        if (row == tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element->
                            addressing_identifier[$1.addressing_exclusion].
                            row && column ==
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element->
                            addressing_identifier[$1.addressing_exclusion].
                            column) {
                          continue;
                          }
                        }
                      else {
                        yyerror ("MTL interpreter error: excluded addressing "
                            "identifier not assigned to a 1-dimensional "
                            "addressing direction");
                        mtli_garbage_collection ();
                        tmp_return = 1; //return from yyparse
                        break;
                        }
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              else { //right_first
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int column = mtli_memory_chip.number_of_columns () - 1;
                    column >= 0; column--) {
                  for (int row = 0; row < mtli_memory_chip.number_of_rows ();
                      row++) {
                    if ($1.addressing_exclusion != 0) {
                      if (tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier[$1.addressing_exclusion].
                          status == mtl_row_column) {
                        if (row == tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element->
                            addressing_identifier[$1.addressing_exclusion].
                            row && column ==
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element->
                            addressing_identifier[$1.addressing_exclusion].
                            column) {
                          continue;
                          }
                        }
                      else {
                        yyerror ("MTL interpreter error: excluded addressing "
                            "identifier not assigned to a 1-dimensional "
                            "addressing direction");
                        mtli_garbage_collection ();
                        tmp_return = 1; //return from yyparse
                        break;
                        }
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              }
            else { //bottom_first
              if (current_memory_type.column_order == left_first) {
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int column = 0;
                    column < mtli_memory_chip.number_of_columns (); column++)
                    {
                  for (int row = mtli_memory_chip.number_of_rows () - 1;
                      row >= 0; row--) {
                    if ($1.addressing_exclusion != 0) {
                      if (tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier[$1.addressing_exclusion].
                          status == mtl_row_column) {
                        if (row == tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element->
                            addressing_identifier[$1.addressing_exclusion].
                            row && column ==
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element->
                            addressing_identifier[$1.addressing_exclusion].
                            column) {
                          continue;
                          }
                        }
                      else {
                        yyerror ("MTL interpreter error: excluded addressing "
                            "identifier not assigned to a 1-dimensional "
                            "addressing direction");
                        mtli_garbage_collection ();
                        tmp_return = 1; //return from yyparse
                        break;
                        }
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              else { //right_first
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int column = mtli_memory_chip.number_of_columns () - 1;
                    column >= 0; column--) {
                  for (int row = mtli_memory_chip.number_of_rows () - 1;
                      row >= 0; row--) {
                    if ($1.addressing_exclusion != 0) {
                      if (tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier[$1.addressing_exclusion].
                          status == mtl_row_column) {
                        if (row == tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element->
                            addressing_identifier[$1.addressing_exclusion].
                            row && column ==
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element->
                            addressing_identifier[$1.addressing_exclusion].
                            column) {
                          continue;
                          }
                        }
                      else {
                        yyerror ("MTL interpreter error: excluded addressing "
                            "identifier not assigned to a 1-dimensional "
                            "addressing direction");
                        mtli_garbage_collection ();
                        tmp_return = 1; //return from yyparse
                        break;
                        }
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[$1.addressing_assignment].
                        column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              }
            }
          break;
          }
        case mtl_south: {
          unsigned int first_inserted_chip_operation_list_element = 1;
          for (int row = 0; row < mtli_memory_chip.number_of_rows (); row++) {
            if ($1.addressing_exclusion != 0) {
              if (tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[$1.addressing_exclusion].status ==
                  mtl_row_column ||
                  tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[$1.addressing_exclusion].status ==
                  mtl_row) {
                if (row == tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element->
                    addressing_identifier[$1.addressing_exclusion].row) {
                  continue;
                  }
                }
              else {
                yyerror ("MTL interpreter error: excluded addressing "
                    "identifier not assigned to a 1-dimensional or row "
                    "addressing direction");
                mtli_garbage_collection ();
                tmp_return = 1; //return from yyparse
                break;
                }
              }
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element =
                new mtli_Chip_operation_list_element;
            assert (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element !=
                NULL); //memory exhausted
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                next_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element;
            for (unsigned int i = 0; i < 27; i++) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier [i] =
                  tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  previous_element->addressing_identifier [i];
              }
            if (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_column ||
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_row_column) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_row_column;
              }
            else {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_row;
              }
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].row = row;
            if (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[$1.addressing_assignment].status ==
                mtl_column ||
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[$1.addressing_assignment].status ==
                mtl_row_column) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[$1.addressing_assignment].status =
                  mtl_row_column;
              }
            else {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[$1.addressing_assignment].status =
                  mtl_row;
              }
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[$1.addressing_assignment].row = row;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list = NULL;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list_last_element = NULL;
            if (mtli_recursion_stack_last_element->list_element_list == NULL)
                {
              mtli_recursion_stack_last_element->list_element_list =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->list_element_list !=
                  NULL); //memory exhausted
              mtli_recursion_stack_last_element->list_element_list->
                  previous_element = NULL;
              mtli_recursion_stack_last_element->list_element_list->
                  next_element = NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->list_element_list;
              }
            else {
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element != NULL);
                  //memory exhausted
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->
                  previous_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element;
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->next_element =
                  NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element;
              }
            first_inserted_chip_operation_list_element = 0;
            }
          break;
          }
        case mtl_north: {
          unsigned int first_inserted_chip_operation_list_element = 1;
          for (int row = mtli_memory_chip.number_of_rows () - 1; row >= 0;
              row--) {
            if ($1.addressing_exclusion != 0) {
              if (tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[$1.addressing_exclusion].status ==
                  mtl_row_column ||
                  tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[$1.addressing_exclusion].status ==
                  mtl_row) {
                if (row == tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element->
                    addressing_identifier[$1.addressing_exclusion].row ) {
                  continue;
                  }
                }
              else {
                yyerror ("MTL interpreter error: excluded addressing "
                    "identifier not assigned to a 1-dimensional or row "
                    "addressing direction");
                mtli_garbage_collection ();
                tmp_return = 1; //return from yyparse
                break;
                }
              }
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element =
                new mtli_Chip_operation_list_element;
            assert (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element !=
                NULL); //memory exhausted
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                next_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element;
            for (unsigned int i = 0; i < 27; i++) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier [i] =
                  tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  previous_element->addressing_identifier [i];
              }
            if (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_column ||
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_row_column) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_row_column;
              }
            else {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_row;
              }
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].row = row;
            if (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[$1.addressing_assignment].status ==
                mtl_column ||
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[$1.addressing_assignment].status ==
                mtl_row_column) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[$1.addressing_assignment].status =
                  mtl_row_column;
              }
            else {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[$1.addressing_assignment].status =
                  mtl_row;
              }
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[$1.addressing_assignment].row = row;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list = NULL;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list_last_element = NULL;
            if (mtli_recursion_stack_last_element->list_element_list == NULL)
                {
              mtli_recursion_stack_last_element->list_element_list =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->list_element_list !=
                  NULL); //memory exhausted
              mtli_recursion_stack_last_element->list_element_list->
                  previous_element = NULL;
              mtli_recursion_stack_last_element->list_element_list->
                  next_element = NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->list_element_list;
              }
            else {
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element != NULL);
                  //memory exhausted
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->
                  previous_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element;
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->
                  next_element = NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element;
              }
            first_inserted_chip_operation_list_element = 0;
            }
          break;
          }
        case mtl_east: {
          unsigned int first_inserted_chip_operation_list_element = 1;
          for (int column = 0; column < mtli_memory_chip.number_of_columns ();
              column++) {
            if ($1.addressing_exclusion != 0) {
              if (tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[$1.addressing_exclusion].status ==
                  mtl_row_column ||
                  tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[$1.addressing_exclusion].status ==
                  mtl_column) {
                if (column == tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element->
                    addressing_identifier[$1.addressing_exclusion].column) {
                  continue;
                  }
                }
              else {
                yyerror ("MTL interpreter error: excluded addressing "
                    "identifier not assigned to a 1-dimensional or column "
                    "addressing direction");
                mtli_garbage_collection ();
                tmp_return = 1; //return from yyparse
                break;
                }
              }
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element =
                new mtli_Chip_operation_list_element;
            assert (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element !=
                NULL); //memory exhausted
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                next_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element;
            for (unsigned int i = 0; i < 27; i++) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier [i] =
                  tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  previous_element->addressing_identifier [i];
              }
            if (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_row ||
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_row_column) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_row_column;
              }
            else {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_column;
              }
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].column = column;
            if (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[$1.addressing_assignment].status ==
                mtl_row ||
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[$1.addressing_assignment].status ==
                mtl_row_column) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[$1.addressing_assignment].status =
                  mtl_row_column;
              }
            else {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[$1.addressing_assignment].status =
                  mtl_column;
              }
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[$1.addressing_assignment].column =
                column;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list = NULL;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list_last_element = NULL;
            if (mtli_recursion_stack_last_element->list_element_list == NULL)
                {
              mtli_recursion_stack_last_element->list_element_list =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->list_element_list !=
                  NULL); //memory exhausted
              mtli_recursion_stack_last_element->list_element_list->
                  previous_element = NULL;
              mtli_recursion_stack_last_element->list_element_list->
                  next_element = NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->list_element_list;
              }
            else {
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element != NULL);
                  //memory exhausted
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->
                  previous_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element;
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->next_element =
                  NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element;
              }
            first_inserted_chip_operation_list_element = 0;
            }
          break;
          }
        case mtl_west: {
          unsigned int first_inserted_chip_operation_list_element = 1;
          for (int column = mtli_memory_chip.number_of_columns () - 1;
              column >= 0; column--) {
            if ($1.addressing_exclusion != 0) {
              if (tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[$1.addressing_exclusion].status ==
                  mtl_row_column ||
                  tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[$1.addressing_exclusion].status ==
                  mtl_column) {
                if (column == tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element->
                    addressing_identifier[$1.addressing_exclusion].column) {
                  continue;
                  }
                }
              else {
                yyerror ("MTL interpreter error: excluded addressing "
                    "identifier not assigned to a 1-dimensional or column "
                    "addressing direction");
                mtli_garbage_collection ();
                tmp_return = 1; //return from yyparse
                break;
                }
              }
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element =
                new mtli_Chip_operation_list_element;
            assert (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element !=
                NULL); //memory exhausted
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element->
                next_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element =
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->next_element;
            for (unsigned int i = 0; i < 27; i++) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier [i] =
                  tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  previous_element->addressing_identifier [i];
              }
            if (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_row ||
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].status == mtl_row_column) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_row_column;
              }
            else {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[0].status = mtl_column;
              }
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[0].column = column;
            if (tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[$1.addressing_assignment].status ==
                mtl_row ||
                tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[$1.addressing_assignment].status ==
                mtl_row_column) {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[$1.addressing_assignment].status =
                  mtl_row_column;
              }
            else {
              tmp_recursion_stack_element_list_element->
                  chip_operation_list_element->previous_element->
                  addressing_identifier[$1.addressing_assignment].status =
                  mtl_column;
              }
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                addressing_identifier[$1.addressing_assignment].column =
                column;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list = NULL;
            tmp_recursion_stack_element_list_element->
                chip_operation_list_element->previous_element->
                operation_list_last_element = NULL;
            if (mtli_recursion_stack_last_element->list_element_list == NULL)
                {
              mtli_recursion_stack_last_element->list_element_list =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->list_element_list !=
                  NULL); //memory exhausted
              mtli_recursion_stack_last_element->list_element_list->
                  previous_element = NULL;
              mtli_recursion_stack_last_element->list_element_list->
                  next_element = NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->list_element_list->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->list_element_list;
              }
            else {
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element =
                  new mtli_Recursion_stack_element_list_element;
              assert (mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element != NULL);
                  //memory exhausted
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->
                  previous_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element;
              mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element->
                  next_element = NULL;
              if (first_inserted_chip_operation_list_element) {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element;
                }
              else {
                mtli_recursion_stack_last_element->
                    list_element_list_last_element->next_element->
                    chip_operation_list_element =
                    tmp_recursion_stack_element_list_element->
                    chip_operation_list_element->previous_element;
                }
              mtli_recursion_stack_last_element->
                  list_element_list_last_element =
                  mtli_recursion_stack_last_element->
                  list_element_list_last_element->next_element;
              }
            first_inserted_chip_operation_list_element = 0;
            }
          break;
          }
        default: {
          yyerror ("MTL internal error: addressing_direction not recognized");
          mtli_garbage_collection ();
          tmp_return = 1; //return from yyparse
          break;
          }
        }
      if (tmp_return == 1) {
        return 1;
        }
      tmp_recursion_stack_element_list_element =
          tmp_recursion_stack_element_list_element->next_element;
      }
    }
  else {
    yyerror ("MTL internal error: empty recursion stack pop");
    mtli_garbage_collection ();
    return 1;
    }
  } sub_march_element_list ')' {
  if (mtli_recursion_stack_last_element != NULL) {
    mtli_Recursion_stack_element_list_element
       *tmp_recursion_stack_element_list_element =
       mtli_recursion_stack_last_element->list_element_list;
    while (tmp_recursion_stack_element_list_element != NULL) {
      if (tmp_recursion_stack_element_list_element->next_element == NULL) {
        delete tmp_recursion_stack_element_list_element;
        tmp_recursion_stack_element_list_element = NULL;
        }
      else {
        tmp_recursion_stack_element_list_element =
            tmp_recursion_stack_element_list_element->next_element;
        delete tmp_recursion_stack_element_list_element->previous_element;
        }
      }
    if (mtli_recursion_stack_last_element->previous_element != NULL) {
      mtli_recursion_stack_last_element =
          mtli_recursion_stack_last_element->previous_element;
      delete mtli_recursion_stack_last_element->next_element;
      mtli_recursion_stack_last_element->next_element = NULL;
      }
    else {
      yyerror ("MTL internal error: empty recursion stack pop");
      mtli_garbage_collection ();
      return 1;
      }
    }
  else {
    yyerror ("MTL internal error: empty recursion stack pop");
    mtli_garbage_collection ();
    return 1;
    }
  }              | operation {


  }              | time_operation {
  };

addressing_specifier: addressing_direction {
  $$.addressing_direction = $1;
  $$.addressing_assignment = 0;
  $$.addressing_exclusion = 0;
  }                 | addressing_direction addressing_id {
  $$.addressing_direction = $1;
  $$.addressing_assignment = $2;
  $$.addressing_exclusion = 0;
  }                 | addressing_direction addressing_id '=' OPERATOR addressing_id {
  if ($4 != mtl_minus) {
    yyerror ("MTL interpreter error: '-' expected");
    return 1;
    }
  $$.addressing_direction = $1;
  $$.addressing_assignment = $2;
  $$.addressing_exclusion = $5;
  }                 | addressing_direction OPERATOR addressing_id {
  if ($2 != mtl_minus) {
    yyerror ("MTL interpreter error: '-' expected");
    return 1;
    }
  $$.addressing_direction = $1;
  $$.addressing_assignment = 0;
  $$.addressing_exclusion = $3;
  };

addressing_direction: _1_dimensional_addressing_direction {
  $$ = $1;
  }                 | row_addressing_direction {
  $$ = $1;
  }                 | column_addressing_direction {
  $$ = $1;
  };

_1_dimensional_addressing_direction: UP_DOWN {
  yyerror ("MTL internal error: UP_DOWN not expanded");
  mtli_garbage_collection ();
  return 1;
  }                                | DOWN {
  $$ = mtl_down;
  }                                | UP {
  $$ = mtl_up;
  };

row_addressing_direction: EAST_WEST {
  yyerror ("MTL internal error: EAST_WEST not expanded");
  mtli_garbage_collection ();
  return 1;
  }                     | EAST {
  $$ = mtl_east;
  }                     | WEST {
  $$ = mtl_west;
  };

column_addressing_direction: NORTH_SOUTH {
  yyerror ("MTL internal error: NORTH_SOUTH not expanded");
  mtli_garbage_collection ();
  return 1;
  }                        | SOUTH {
  $$ = mtl_south;
  }                        | NORTH {
  $$ = mtl_north;
  };

addressing_id: 'a' {
  $$ = 1;
  }          | 'b' {
  $$ = 2;
  }          | 'c' {
  $$ = 3;
  }          | 'd' {
  $$ = 4;
  }          | 'e' {
  $$ = 5;
  }          | 'f' {
  $$ = 6;
  }          | 'g' {
  $$ = 7;
  }          | 'h' {
  $$ = 8;
  }          | 'i' {
  $$ = 9;
  }          | 'j' {
  $$ = 10;
  }          | 'k' {
  $$ = 11;
  }          | 'l' {
  $$ = 12;
  }          | 'm' {
  $$ = 13;
  }          | 'n' {
  $$ = 14;
  }          | 'o' {
  $$ = 15;
  }          | 'p' {
  $$ = 16;
  }          | 'q' {
  $$ = 17;
  }          | 'r' {
  $$ = 18;
  }          | 's' {
  $$ = 19;
  }          | 't' {
  $$ = 20;
  }          | 'u' {
  $$ = 21;
  }          | 'v' {
  $$ = 22;
  }          | 'w' {
  $$ = 23;
  }          | 'x' {
  $$ = 24;
  }          | 'y' {
  $$ = 25;
  }          | 'z' {
  $$ = 26;
  }          | 'A' {
  $$ = 1;
  }          | 'B' {
  $$ = 2;
  }          | 'C' {
  $$ = 3;
  }          | 'D' {
  $$ = 4;
  }          | 'E' {
  $$ = 5;
  }          | 'F' {
  $$ = 6;
  }          | 'G' {
  $$ = 7;
  }          | 'H' {
  $$ = 8;
  }          | 'I' {
  $$ = 9;
  }          | 'J' {
  $$ = 10;
  }          | 'K' {
  $$ = 11;
  }          | 'L' {
  $$ = 12;
  }          | 'M' {
  $$ = 13;
  }          | 'N' {
  $$ = 14;
  }          | 'O' {
  $$ = 15;
  }          | 'P' {
  $$ = 16;
  }          | 'Q' {
  $$ = 17;
  }          | 'R' {
  $$ = 18;
  }          | 'S' {
  $$ = 19;
  }          | 'T' {
  $$ = 20;
  }          | 'U' {
  $$ = 21;
  }          | 'V' {
  $$ = 22;
  }          | 'W' {
  $$ = 23;
  }          | 'X' {
  $$ = 24;
  }          | 'Y' {
  $$ = 25;
  }          | 'Z' {
  $$ = 26;
  };

operation: port_operation_list {
  };

port_operation_list: port_operation {
  }                | port_operation ':' port_operation_list {
  };

port_operation: 'r' data {


  }           | 'w' data {


  }           | 'r' offset data {


  }           | 'w' offset data {


  }           | NOP {


  };

offset: '[' addressing_id_offset ']' {
  yyerror ("MTL interpreter warning: 1-dimensional addressing_id_offset not "
      "implemented");
  mtli_garbage_collection ();
  return 1;
  }   | '[' addressing_id_offset ',' addressing_id_offset ']' {


  };


addressing_id_offset: addressing_id {


  }      | addressing_id OPERATOR integer {


  };

tile_march_element: _1_dimensional_addressing_direction tile_size '(' {
  if (mtli_recursion_stack_last_element != NULL) {
    mtli_recursion_stack_last_element->next_element =
        new mtli_Recursion_stack_element;
    assert (mtli_recursion_stack_last_element->next_element != NULL);
        //memory exhausted
    mtli_recursion_stack_last_element->next_element->previous_element =
        mtli_recursion_stack_last_element;
    mtli_recursion_stack_last_element->next_element->next_element = NULL;
    mtli_recursion_stack_last_element->next_element->list_element_list = NULL;
    mtli_recursion_stack_last_element->next_element->
        list_element_list_last_element = NULL;
    mtli_recursion_stack_last_element =
        mtli_recursion_stack_last_element->next_element;
    mtli_Recursion_stack_element_list_element
        *tmp_recursion_stack_element_list_element =
        mtli_recursion_stack_last_element->previous_element->list_element_list;
    unsigned int tmp_return = 0;
    while (tmp_recursion_stack_element_list_element != NULL) {
      switch ($1) {
        case mtl_down: {
          if (current_memory_type.address_order == column_first) {
            if (current_memory_type.row_order == top_first) {
              if (current_memory_type.column_order == left_first) {
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int row = mtli_memory_chip.number_of_rows () -
                    $2.number_of_rows; row >= 0; row -= $2.number_of_rows) {
                  for (int column = mtli_memory_chip.number_of_columns () -
                      $2.number_of_columns; column >= 0; column -=
                      $2.number_of_columns) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              else { //right_first
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int row = mtli_memory_chip.number_of_rows () - 
                    $2.number_of_rows; row >= 0; row -= $2.number_of_rows) {
                  for (int column = 0; column <=
                      mtli_memory_chip.number_of_columns () -
                      $2.number_of_columns; column += $2.number_of_columns) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              }
            else { //bottom_first
              if (current_memory_type.column_order == left_first) {
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int row = 0; row <= mtli_memory_chip.number_of_rows () -
                    $2.number_of_rows; row += $2.number_of_rows) {
                  for (int column = mtli_memory_chip.number_of_columns () -
                      $2.number_of_columns; column >= 0; column -=
                      $2.number_of_columns) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              else { //right_first
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int row = 0; row <= mtli_memory_chip.number_of_rows () -
                    $2.number_of_rows; row += $2.number_of_rows) {
                  for (int column = 0; column <=
                      mtli_memory_chip.number_of_columns () -
                      $2.number_of_columns; column += $2.number_of_columns) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              }
            }
          else { //row_first
            if (current_memory_type.row_order == top_first) {
              if (current_memory_type.column_order == left_first) {
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int column = mtli_memory_chip.number_of_columns () -
                    $2.number_of_columns; column >= 0; column -=
                    $2.number_of_columns) {
                  for (int row = mtli_memory_chip.number_of_rows () -
                      $2.number_of_rows; row >= 0; row -= $2.number_of_rows) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              else { //right_first
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int column = 0; column <=
                    mtli_memory_chip.number_of_columns () -
                    $2.number_of_columns; column += $2.number_of_columns) { 
                  for (int row = mtli_memory_chip.number_of_rows () -
                      $2.number_of_rows; row >= 0; row -= $2.number_of_rows) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              }
            else { //bottom_first
              if (current_memory_type.column_order == left_first) {
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int column = mtli_memory_chip.number_of_columns () - 
                    $2.number_of_columns; column >= 0; column -=
                    $2.number_of_columns) {
                  for (int row = 0; row <= mtli_memory_chip.number_of_rows () -
                      $2.number_of_rows; row += $2.number_of_rows) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              else { //right_first
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int column = 0; column <=
                    mtli_memory_chip.number_of_columns () -
                    $2.number_of_columns; column += $2.number_of_columns) {
                  for (int row = 0; row <=
                      mtli_memory_chip.number_of_rows () -
                      $2.number_of_rows; row += $2.number_of_rows) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              }
            }
          break;
          }
        case mtl_up: {
          if (current_memory_type.address_order == column_first) {
            if (current_memory_type.row_order == top_first) {
              if (current_memory_type.column_order == left_first) {
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int row = 0; row <= mtli_memory_chip.number_of_rows () -
                    $2.number_of_rows; row += $2.number_of_rows) {
                  for (int column = 0; column <=
                      mtli_memory_chip.number_of_columns () -
                      $2.number_of_columns; column += $2.number_of_columns) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              else { //right_first
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int row = 0; row <= mtli_memory_chip.number_of_rows () -
                    $2.number_of_rows; row += $2.number_of_rows) {
                  for (int column = mtli_memory_chip.number_of_columns () -
                      $2.number_of_columns; column >= 0; column -=
                      $2.number_of_columns) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              }
            else { //bottom_first
              if (current_memory_type.column_order == left_first) {
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int row = mtli_memory_chip.number_of_rows () -
                    $2.number_of_rows; row >= 0; row -= $2.number_of_rows) {
                  for (int column = 0; column <=
                      mtli_memory_chip.number_of_columns () -
                      $2.number_of_columns; column += $2.number_of_columns) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              else { //right_first
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int row = mtli_memory_chip.number_of_rows () -
                    $2.number_of_rows; row >= 0; row -= $2.number_of_rows) {
                  for (int column = mtli_memory_chip.number_of_columns () -
                      $2.number_of_columns; column >= 0; column -=
                      $2.number_of_columns) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              }
            }
          else { //row_first
            if (current_memory_type.row_order == top_first) {
              if (current_memory_type.column_order == left_first) {
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int column = 0; column <=
                    mtli_memory_chip.number_of_columns () -
                    $2.number_of_columns; column += $2.number_of_columns) {
                  for (int row = 0; row <=
                      mtli_memory_chip.number_of_rows () - $2.number_of_rows;
                      row += $2.number_of_rows) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              else { //right_first
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int column = mtli_memory_chip.number_of_columns () -
                    $2.number_of_columns; column >= 0; column -=
                    $2.number_of_columns) {
                  for (int row = 0; row <= mtli_memory_chip.number_of_rows () -
                      $2.number_of_rows; row += $2.number_of_rows) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              }
            else { //bottom_first
              if (current_memory_type.column_order == left_first) {
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int column = 0; column <=
                    mtli_memory_chip.number_of_columns () -
                    $2.number_of_columns; column += $2.number_of_columns) {
                  for (int row = mtli_memory_chip.number_of_rows () -
                      $2.number_of_rows; row >= 0; row -= $2.number_of_rows) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              else { //right_first
                unsigned int first_inserted_chip_operation_list_element = 1;
                for (int column = mtli_memory_chip.number_of_columns () -
                    $2.number_of_columns; column >= 0; column -=
                    $2.number_of_columns) {
                  for (int row = mtli_memory_chip.number_of_rows () -
                      $2.number_of_rows; row >= 0; row -= $2.number_of_rows) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element = new mtli_Chip_operation_list_element;
                    assert (tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element != NULL); //memory exhausted
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element->next_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        next_element;
                    for (unsigned int i = 0; i < 27; i++) {
                      tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          addressing_identifier [i] =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element->
                          previous_element->addressing_identifier [i];
                      }
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].status = mtl_row_column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].row = row;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier[0].column = column;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list = NULL;
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        operation_list_last_element = NULL;
                    if (mtli_recursion_stack_last_element->
                        list_element_list == NULL) {
                      mtli_recursion_stack_last_element->
                          list_element_list =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list != NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list->previous_element = NULL;
                      mtli_recursion_stack_last_element->
                          list_element_list->next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list->chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element =
                          new mtli_Recursion_stack_element_list_element;
                      assert (mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element !=
                          NULL); //memory exhausted
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          previous_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element;
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          next_element = NULL;
                      if (first_inserted_chip_operation_list_element) {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element;
                        }
                      else {
                        mtli_recursion_stack_last_element->
                            list_element_list_last_element->next_element->
                            chip_operation_list_element =
                            tmp_recursion_stack_element_list_element->
                            chip_operation_list_element->previous_element;
                        }
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element =
                          mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element;
                      }
                    first_inserted_chip_operation_list_element = 0;
                    }
                  }
                }
              }
            }
          break;
          }
        default: {
          yyerror ("MTL internal error: 1_dimensional_addressing_direction "
              "not recognized");
          mtli_garbage_collection ();
          tmp_return = 1; //return from yyparse
          break;
          }
        }
      if (tmp_return == 1) {
        return 1;
        }
      tmp_recursion_stack_element_list_element =
          tmp_recursion_stack_element_list_element->next_element;
      }
    }
  else {
    yyerror ("MTL internal error: empty recursion stack pop");
    mtli_garbage_collection ();
    return 1;
    }
  } local_operation_list ')' {
  if (mtli_recursion_stack_last_element != NULL) {
    mtli_Recursion_stack_element_list_element
       *tmp_recursion_stack_element_list_element =
       mtli_recursion_stack_last_element->list_element_list;
    while (tmp_recursion_stack_element_list_element != NULL) {
      if (tmp_recursion_stack_element_list_element->next_element == NULL) {
        delete tmp_recursion_stack_element_list_element;
        tmp_recursion_stack_element_list_element = NULL;
        }
      else {
        tmp_recursion_stack_element_list_element =
            tmp_recursion_stack_element_list_element->next_element;
        delete tmp_recursion_stack_element_list_element->previous_element;
        }
      }
    if (mtli_recursion_stack_last_element->previous_element != NULL) {
      mtli_recursion_stack_last_element =
          mtli_recursion_stack_last_element->previous_element;
      delete mtli_recursion_stack_last_element->next_element;
      mtli_recursion_stack_last_element->next_element = NULL;
      }
    else {
      yyerror ("MTL internal error: empty recursion stack pop");
      mtli_garbage_collection ();
      return 1;
      }
    }
  else {
    yyerror ("MTL internal error: empty recursion stack pop");
    mtli_garbage_collection ();
    return 1;
    }
  }               | row_addressing_direction column_addressing_direction tile_size '(' {
  if (mtli_recursion_stack_last_element != NULL) {
    mtli_recursion_stack_last_element->next_element =
        new mtli_Recursion_stack_element;
    assert (mtli_recursion_stack_last_element->next_element != NULL);
        //memory exhausted
    mtli_recursion_stack_last_element->next_element->previous_element =
        mtli_recursion_stack_last_element;
    mtli_recursion_stack_last_element->next_element->next_element = NULL;
    mtli_recursion_stack_last_element->next_element->list_element_list = NULL;
    mtli_recursion_stack_last_element->next_element->
        list_element_list_last_element = NULL;
    mtli_recursion_stack_last_element =
        mtli_recursion_stack_last_element->next_element;
    mtli_Recursion_stack_element_list_element
        *tmp_recursion_stack_element_list_element =
        mtli_recursion_stack_last_element->previous_element->list_element_list;
    unsigned int tmp_return = 0;
    while (tmp_recursion_stack_element_list_element != NULL) {
      switch ($1) {
        case mtl_north: {
          switch ($2) {
            case mtl_east: {
              unsigned int first_inserted_chip_operation_list_element = 1;
              for (int row = mtli_memory_chip.number_of_rows () - 
                  $3.number_of_rows; row >= 0; row -= $3.number_of_rows) {
                for (int column = 0; column <=
                    mtli_memory_chip.number_of_columns () -
                    $3.number_of_columns; column += $3.number_of_columns) {
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element = new mtli_Chip_operation_list_element;
                  assert (tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element != NULL); //memory exhausted
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element->previous_element =
                      tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element->next_element =
                      tmp_recursion_stack_element_list_element->
                      chip_operation_list_element;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element =
                      tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element;
                  for (unsigned int i = 0; i < 27; i++) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier [i] =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        previous_element->addressing_identifier [i];
                    }
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      addressing_identifier[0].status = mtl_row_column;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      addressing_identifier[0].row = row;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      addressing_identifier[0].column = column;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      operation_list = NULL;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      operation_list_last_element = NULL;
                  if (mtli_recursion_stack_last_element->list_element_list ==
                      NULL) {
                    mtli_recursion_stack_last_element->list_element_list =
                        new mtli_Recursion_stack_element_list_element;
                    assert (mtli_recursion_stack_last_element->
                        list_element_list != NULL); //memory exhausted
                    mtli_recursion_stack_last_element->
                        list_element_list->previous_element = NULL;
                    mtli_recursion_stack_last_element->
                        list_element_list->next_element = NULL;
                    if (first_inserted_chip_operation_list_element) {
                      mtli_recursion_stack_last_element->list_element_list->
                          chip_operation_list_element =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element;
                      }
                    else {
                      mtli_recursion_stack_last_element->list_element_list->
                          chip_operation_list_element =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element;
                      }
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element =
                        mtli_recursion_stack_last_element->list_element_list;
                    }
                  else {
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element =
                        new mtli_Recursion_stack_element_list_element;
                    assert (mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element != NULL);
                        //memory exhausted
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element->
                        previous_element =
                        mtli_recursion_stack_last_element->
                        list_element_list_last_element;
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element->
                        next_element = NULL;
                    if (first_inserted_chip_operation_list_element) {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          chip_operation_list_element =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          chip_operation_list_element =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element;
                      }
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element =
                        mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element;
                    }
                  first_inserted_chip_operation_list_element = 0;
                  }
                }
              break;
              }
            case mtl_west: {
              unsigned int first_inserted_chip_operation_list_element = 1;
              for (int row = mtli_memory_chip.number_of_rows () -
                  $3.number_of_rows; row >= 0; row -= $3.number_of_rows) {
                for (int column = mtli_memory_chip.number_of_columns () -
                    $3.number_of_columns; column >= 0; column -=
                    $3.number_of_columns) {
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element = new mtli_Chip_operation_list_element;
                  assert (tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element != NULL); //memory exhausted
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element->previous_element =
                      tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element->next_element =
                      tmp_recursion_stack_element_list_element->
                      chip_operation_list_element;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element =
                      tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element;
                  for (unsigned int i = 0; i < 27; i++) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier [i] =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        previous_element->addressing_identifier [i];
                    }
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      addressing_identifier[0].status = mtl_row_column;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      addressing_identifier[0].row = row;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      addressing_identifier[0].column = column;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      operation_list = NULL;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      operation_list_last_element = NULL;
                  if (mtli_recursion_stack_last_element->list_element_list ==
                      NULL) {
                    mtli_recursion_stack_last_element->list_element_list =
                        new mtli_Recursion_stack_element_list_element;
                    assert (mtli_recursion_stack_last_element->
                        list_element_list != NULL); //memory exhausted
                    mtli_recursion_stack_last_element->
                        list_element_list->previous_element = NULL;
                    mtli_recursion_stack_last_element->list_element_list->
                        next_element = NULL;
                    if (first_inserted_chip_operation_list_element) {
                      mtli_recursion_stack_last_element->list_element_list->
                          chip_operation_list_element =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element;
                      }
                    else {
                      mtli_recursion_stack_last_element->list_element_list->
                          chip_operation_list_element =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element;
                      }
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element =
                        mtli_recursion_stack_last_element->list_element_list;
                    }
                  else {
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element =
                        new mtli_Recursion_stack_element_list_element;
                    assert (mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element != NULL);
                        //memory exhausted
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element->
                        previous_element =
                        mtli_recursion_stack_last_element->
                        list_element_list_last_element;
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element->
                        next_element = NULL;
                    if (first_inserted_chip_operation_list_element) {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          chip_operation_list_element =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          chip_operation_list_element =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element;
                      }
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element =
                        mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element;
                    }
                  first_inserted_chip_operation_list_element = 0;
                  }
                }
              break;
              }
            default: {
              yyerror ("MTL internal error: column_addressing_direction not "
                  "recognized");
              mtli_garbage_collection ();
              tmp_return = 1; //return from yyparse
              break;
              }
            }
          if (tmp_return == 1) {
            return 1;
            }
          break;
          }
        case mtl_south: {
          switch ($2) {
            case mtl_east: {
              unsigned int first_inserted_chip_operation_list_element = 1;
              for (int row = 0; row <= mtli_memory_chip.number_of_rows () -
                  $3.number_of_rows; row += $3.number_of_rows) {
                for (int column = 0; column <=
                    mtli_memory_chip.number_of_columns () -
                    $3.number_of_columns; column += $3.number_of_columns) {
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element = new mtli_Chip_operation_list_element;
                  assert (tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element != NULL); //memory exhausted
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element->previous_element =
                      tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element->next_element =
                      tmp_recursion_stack_element_list_element->
                      chip_operation_list_element;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element =
                      tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element;
                  for (unsigned int i = 0; i < 27; i++) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier [i] =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        previous_element->addressing_identifier [i];
                    }
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      addressing_identifier[0].status = mtl_row_column;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      addressing_identifier[0].row = row;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      addressing_identifier[0].column = column;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      operation_list = NULL;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      operation_list_last_element = NULL;
                  if (mtli_recursion_stack_last_element->list_element_list ==
                      NULL) {
                    mtli_recursion_stack_last_element->list_element_list =
                        new mtli_Recursion_stack_element_list_element;
                    assert (mtli_recursion_stack_last_element->
                        list_element_list != NULL); //memory exhausted
                    mtli_recursion_stack_last_element->list_element_list->
                        previous_element = NULL;
                    mtli_recursion_stack_last_element->list_element_list->
                        next_element = NULL;
                    if (first_inserted_chip_operation_list_element) {
                      mtli_recursion_stack_last_element->list_element_list->
                          chip_operation_list_element =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element;
                      }
                    else {
                      mtli_recursion_stack_last_element->list_element_list->
                          chip_operation_list_element =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element;
                      }
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element =
                        mtli_recursion_stack_last_element->list_element_list;
                    }
                  else {
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element =
                        new mtli_Recursion_stack_element_list_element;
                    assert (mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element != NULL);
                        //memory exhausted
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element->
                        previous_element =
                        mtli_recursion_stack_last_element->
                        list_element_list_last_element;
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element->
                        next_element = NULL;
                    if (first_inserted_chip_operation_list_element) {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          chip_operation_list_element =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          chip_operation_list_element =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element;
                      }
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element =
                        mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element;
                    }
                  first_inserted_chip_operation_list_element = 0;
                  }
                }
              break;
              }
            case mtl_west: {
              unsigned int first_inserted_chip_operation_list_element = 1;
              for (int row = 0; row <= mtli_memory_chip.number_of_rows () -
                  $3.number_of_rows; row += $3.number_of_rows) {
                for (int column = mtli_memory_chip.number_of_columns () -
                    $3.number_of_columns; column >= 0; column -=
                    $3.number_of_columns) {
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element = new mtli_Chip_operation_list_element;
                  assert (tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element != NULL); //memory exhausted
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element->previous_element =
                      tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element->next_element =
                      tmp_recursion_stack_element_list_element->
                      chip_operation_list_element;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element =
                      tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element;
                  for (unsigned int i = 0; i < 27; i++) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier [i] =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        previous_element->addressing_identifier [i];
                    }
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      addressing_identifier[0].status = mtl_row_column;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      addressing_identifier[0].row = row;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      addressing_identifier[0].column = column;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      operation_list = NULL;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      operation_list_last_element = NULL;
                  if (mtli_recursion_stack_last_element->list_element_list ==
                      NULL) {
                    mtli_recursion_stack_last_element->list_element_list =
                        new mtli_Recursion_stack_element_list_element;
                    assert (mtli_recursion_stack_last_element->
                        list_element_list != NULL); //memory exhausted
                    mtli_recursion_stack_last_element->list_element_list->
                        previous_element = NULL;
                    mtli_recursion_stack_last_element->list_element_list->
                        next_element = NULL;
                    if (first_inserted_chip_operation_list_element) {
                      mtli_recursion_stack_last_element->list_element_list->
                          chip_operation_list_element =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element;
                      }
                    else {
                      mtli_recursion_stack_last_element->list_element_list->
                          chip_operation_list_element =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element;
                      }
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element =
                        mtli_recursion_stack_last_element->list_element_list;
                    }
                  else {
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element =
                        new mtli_Recursion_stack_element_list_element;
                    assert (mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element != NULL);
                        //memory exhausted
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element->
                        previous_element =
                        mtli_recursion_stack_last_element->
                        list_element_list_last_element;
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element->
                        next_element = NULL;
                    if (first_inserted_chip_operation_list_element) {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          chip_operation_list_element =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          chip_operation_list_element =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element;
                      }
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element =
                        mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element;
                    }
                  first_inserted_chip_operation_list_element = 0;
                  }
                }
              break;
              }
            default: {
              yyerror ("MTL internal error: column_addressing_direction not "
                  "recognized");
              mtli_garbage_collection ();
              tmp_return = 1; //return from yyparse
              break;
              }
            }
          if (tmp_return == 1) {
            return 1;
            }
          break;
          }
        default: {
          yyerror ("MTL internal error: row_addressing_direction not "
              "recognized");
          mtli_garbage_collection ();
          tmp_return = 1; //return from yyparse
          break;
          }
        }
      if (tmp_return == 1) {
        return 1;
        }
      tmp_recursion_stack_element_list_element =
          tmp_recursion_stack_element_list_element->next_element;
      }
    }
  else {
    yyerror ("MTL internal error: empty recursion stack pop");
    mtli_garbage_collection ();
    return 1;
    }
  } local_operation_list ')' {
  if (mtli_recursion_stack_last_element != NULL) {
    mtli_Recursion_stack_element_list_element
       *tmp_recursion_stack_element_list_element =
       mtli_recursion_stack_last_element->list_element_list;
    while (tmp_recursion_stack_element_list_element != NULL) {
      if (tmp_recursion_stack_element_list_element->next_element == NULL) {
        delete tmp_recursion_stack_element_list_element;
        tmp_recursion_stack_element_list_element = NULL;
        }
      else {
        tmp_recursion_stack_element_list_element =
            tmp_recursion_stack_element_list_element->next_element;
        delete tmp_recursion_stack_element_list_element->previous_element;
        }
      }
    if (mtli_recursion_stack_last_element->previous_element != NULL) {
      mtli_recursion_stack_last_element =
          mtli_recursion_stack_last_element->previous_element;
      delete mtli_recursion_stack_last_element->next_element;
      mtli_recursion_stack_last_element->next_element = NULL;
      }
    else {
      yyerror ("MTL internal error: empty recursion stack pop");
      mtli_garbage_collection ();
      return 1;
      }
    }
  else {
    yyerror ("MTL internal error: empty recursion stack pop");
    mtli_garbage_collection ();
    return 1;
    }
  }               | column_addressing_direction row_addressing_direction tile_size '(' {
  if (mtli_recursion_stack_last_element != NULL) {
    mtli_recursion_stack_last_element->next_element =
        new mtli_Recursion_stack_element;
    assert (mtli_recursion_stack_last_element->next_element != NULL);
        //memory exhausted
    mtli_recursion_stack_last_element->next_element->previous_element =
        mtli_recursion_stack_last_element;
    mtli_recursion_stack_last_element->next_element->next_element = NULL;
    mtli_recursion_stack_last_element->next_element->list_element_list = NULL;
    mtli_recursion_stack_last_element->next_element->
        list_element_list_last_element = NULL;
    mtli_recursion_stack_last_element =
        mtli_recursion_stack_last_element->next_element;
    mtli_Recursion_stack_element_list_element
        *tmp_recursion_stack_element_list_element =
        mtli_recursion_stack_last_element->previous_element->list_element_list;
    unsigned int tmp_return = 0;
    while (tmp_recursion_stack_element_list_element != NULL) {
      switch ($1) {
        case mtl_east: {
          switch ($2) {
            case mtl_north: {
              unsigned int first_inserted_chip_operation_list_element = 1;
              for (int column = 0; column <=
                  mtli_memory_chip.number_of_columns () -
                  $3.number_of_columns; column += $3.number_of_columns) { 
                for (int row = mtli_memory_chip.number_of_rows () -
                    $3.number_of_rows; row >= 0; row -= $3.number_of_rows) {
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element = new mtli_Chip_operation_list_element;
                  assert (tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element != NULL); //memory exhausted
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element->previous_element =
                      tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element->next_element =
                      tmp_recursion_stack_element_list_element->
                      chip_operation_list_element;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element =
                      tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element;
                  for (unsigned int i = 0; i < 27; i++) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier [i] =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        previous_element->addressing_identifier [i];
                    }
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      addressing_identifier[0].status = mtl_row_column;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      addressing_identifier[0].row = row;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      addressing_identifier[0].column = column;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      operation_list = NULL;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      operation_list_last_element = NULL;
                  if (mtli_recursion_stack_last_element->list_element_list ==
                      NULL) {
                    mtli_recursion_stack_last_element->list_element_list =
                        new mtli_Recursion_stack_element_list_element;
                    assert (mtli_recursion_stack_last_element->
                        list_element_list != NULL); //memory exhausted
                    mtli_recursion_stack_last_element->list_element_list->
                        previous_element = NULL;
                    mtli_recursion_stack_last_element->list_element_list->
                        next_element = NULL;
                    if (first_inserted_chip_operation_list_element) {
                      mtli_recursion_stack_last_element->list_element_list->
                          chip_operation_list_element =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element;
                      }
                    else {
                      mtli_recursion_stack_last_element->list_element_list->
                          chip_operation_list_element =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element;
                      }
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element =
                        mtli_recursion_stack_last_element->list_element_list;
                    }
                  else {
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element =
                        new mtli_Recursion_stack_element_list_element;
                    assert (mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element != NULL);
                        //memory exhausted
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element->
                        previous_element =
                        mtli_recursion_stack_last_element->
                        list_element_list_last_element;
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element->
                        next_element = NULL;
                    if (first_inserted_chip_operation_list_element) {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          chip_operation_list_element =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          chip_operation_list_element =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element;
                      }
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element =
                        mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element;
                    }
                  first_inserted_chip_operation_list_element = 0;
                  }
                }
              break;
              }
            case mtl_south: {
              unsigned int first_inserted_chip_operation_list_element = 1;
              for (int column = 0; column <=
                  mtli_memory_chip.number_of_columns () -
                  $3.number_of_columns; column += $3.number_of_columns) {
                for (int row = 0; row <= mtli_memory_chip.number_of_rows () -
                    $3.number_of_rows; row += $3.number_of_rows) {
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element = new mtli_Chip_operation_list_element;
                  assert (tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element != NULL); //memory exhausted
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element->previous_element =
                      tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element->next_element =
                      tmp_recursion_stack_element_list_element->
                      chip_operation_list_element;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element =
                      tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element;
                  for (unsigned int i = 0; i < 27; i++) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier [i] =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        previous_element->addressing_identifier [i];
                    }
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      addressing_identifier[0].status = mtl_row_column;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      addressing_identifier[0].row = row;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      addressing_identifier[0].column = column;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      operation_list = NULL;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      operation_list_last_element = NULL;
                  if (mtli_recursion_stack_last_element->list_element_list ==
                      NULL) {
                    mtli_recursion_stack_last_element->list_element_list =
                        new mtli_Recursion_stack_element_list_element;
                    assert (mtli_recursion_stack_last_element->
                        list_element_list != NULL); //memory exhausted
                    mtli_recursion_stack_last_element->
                        list_element_list->previous_element = NULL;
                    mtli_recursion_stack_last_element->list_element_list->
                        next_element = NULL;
                    if (first_inserted_chip_operation_list_element) {
                      mtli_recursion_stack_last_element->list_element_list->
                          chip_operation_list_element =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element;
                      }
                    else {
                      mtli_recursion_stack_last_element->list_element_list->
                          chip_operation_list_element =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element;
                      }
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element =
                        mtli_recursion_stack_last_element->list_element_list;
                    }
                  else {
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element =
                        new mtli_Recursion_stack_element_list_element;
                    assert (mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element != NULL);
                        //memory exhausted
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element->
                        previous_element =
                        mtli_recursion_stack_last_element->
                        list_element_list_last_element;
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element->
                        next_element = NULL;
                    if (first_inserted_chip_operation_list_element) {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          chip_operation_list_element =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          chip_operation_list_element =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element;
                      }
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element =
                        mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element;
                    }
                  first_inserted_chip_operation_list_element = 0;
                  }
                }
              break;
              }
            default: {
              yyerror ("MTL internal error: row_addressing_direction not "
                  "recognized");
              mtli_garbage_collection ();
              tmp_return = 1; //return from yyparse
              break;
              }
            }
          if (tmp_return == 1) {
            return 1;
            }
          break;
          }
        case mtl_west: {
          switch ($2) {
            case mtl_north: {
              unsigned int first_inserted_chip_operation_list_element = 1;
              for (int column = mtli_memory_chip.number_of_columns () -
                  $3.number_of_columns; column >= 0; column -=
                  $3.number_of_columns) {
                for (int row = mtli_memory_chip.number_of_rows () -
                    $3.number_of_rows; row >= 0; row -= $3.number_of_rows) {
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element = new mtli_Chip_operation_list_element;
                  assert (tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element != NULL); //memory exhausted
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element->previous_element =
                      tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element->next_element =
                      tmp_recursion_stack_element_list_element->
                      chip_operation_list_element;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element =
                      tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element;
                  for (unsigned int i = 0; i < 27; i++) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier [i] =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        previous_element->addressing_identifier [i];
                    }
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      addressing_identifier[0].status = mtl_row_column;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      addressing_identifier[0].row = row;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      addressing_identifier[0].column = column;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      operation_list = NULL;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      operation_list_last_element = NULL;
                  if (mtli_recursion_stack_last_element->list_element_list ==
                      NULL) {
                    mtli_recursion_stack_last_element->list_element_list =
                        new mtli_Recursion_stack_element_list_element;
                    assert (mtli_recursion_stack_last_element->
                        list_element_list != NULL); //memory exhausted
                    mtli_recursion_stack_last_element->list_element_list->
                        previous_element = NULL;
                    mtli_recursion_stack_last_element->list_element_list->
                        next_element = NULL;
                    if (first_inserted_chip_operation_list_element) {
                      mtli_recursion_stack_last_element->
                          list_element_list->chip_operation_list_element =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list->chip_operation_list_element =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element;
                      }
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element =
                        mtli_recursion_stack_last_element->list_element_list;
                    }
                  else {
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element =
                        new mtli_Recursion_stack_element_list_element;
                    assert (mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element != NULL);
                        //memory exhausted
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element->
                        previous_element =
                        mtli_recursion_stack_last_element->
                        list_element_list_last_element;
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element->
                        next_element = NULL;
                    if (first_inserted_chip_operation_list_element) {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          chip_operation_list_element =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          chip_operation_list_element =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element;
                      }
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element =
                        mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element;
                    }
                  first_inserted_chip_operation_list_element = 0;
                  }
                }
              break;
              }
            case mtl_south: {
              unsigned int first_inserted_chip_operation_list_element = 1;
              for (int column = mtli_memory_chip.number_of_columns () - 
                  $3.number_of_columns; column >= 0; column -=
                  $3.number_of_columns) {
                for (int row = 0; row <= mtli_memory_chip.number_of_rows () -
                    $3.number_of_rows; row += $3.number_of_rows) {
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element = new mtli_Chip_operation_list_element;
                  assert (tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element != NULL); //memory exhausted
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element->previous_element =
                      tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element->next_element =
                      tmp_recursion_stack_element_list_element->
                      chip_operation_list_element;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element =
                      tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      next_element;
                  for (unsigned int i = 0; i < 27; i++) {
                    tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        addressing_identifier [i] =
                        tmp_recursion_stack_element_list_element->
                        chip_operation_list_element->previous_element->
                        previous_element->addressing_identifier [i];
                    }
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      addressing_identifier[0].status = mtl_row_column;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      addressing_identifier[0].row = row;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      addressing_identifier[0].column = column;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      operation_list = NULL;
                  tmp_recursion_stack_element_list_element->
                      chip_operation_list_element->previous_element->
                      operation_list_last_element = NULL;
                  if (mtli_recursion_stack_last_element->list_element_list ==
                      NULL) {
                    mtli_recursion_stack_last_element->list_element_list =
                        new mtli_Recursion_stack_element_list_element;
                    assert (mtli_recursion_stack_last_element->
                        list_element_list != NULL); //memory exhausted
                    mtli_recursion_stack_last_element->list_element_list->
                        previous_element = NULL;
                    mtli_recursion_stack_last_element->list_element_list->
                        next_element = NULL;
                    if (first_inserted_chip_operation_list_element) {
                      mtli_recursion_stack_last_element->list_element_list->
                          chip_operation_list_element =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element;
                      }
                    else {
                      mtli_recursion_stack_last_element->list_element_list->
                          chip_operation_list_element =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element;
                      }
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element =
                        mtli_recursion_stack_last_element->list_element_list;
                    }
                  else {
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element =
                        new mtli_Recursion_stack_element_list_element;
                    assert (mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element != NULL);
                        //memory exhausted
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element->
                        previous_element =
                        mtli_recursion_stack_last_element->
                        list_element_list_last_element;
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element->
                        next_element = NULL;
                    if (first_inserted_chip_operation_list_element) {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          chip_operation_list_element =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element;
                      }
                    else {
                      mtli_recursion_stack_last_element->
                          list_element_list_last_element->next_element->
                          chip_operation_list_element =
                          tmp_recursion_stack_element_list_element->
                          chip_operation_list_element->previous_element;
                      }
                    mtli_recursion_stack_last_element->
                        list_element_list_last_element =
                        mtli_recursion_stack_last_element->
                        list_element_list_last_element->next_element;
                    }
                  first_inserted_chip_operation_list_element = 0;
                  }
                }
              break;
              }
            default: {
              yyerror ("MTL internal error: row_addressing_direction not "
                  "recognized");
              mtli_garbage_collection ();
              tmp_return = 1; //return from yyparse
              break;
              }
            }
          if (tmp_return == 1) {
            return 1;
            }
          break;
          }
        default: {
          yyerror ("MTL internal error: column_addressing_direction not "
              "recognized");
          mtli_garbage_collection ();
          tmp_return = 1; //return from yyparse
          break;
          }
        }
      if (tmp_return == 1) {
        return 1;
        }
      tmp_recursion_stack_element_list_element =
          tmp_recursion_stack_element_list_element->next_element;
      }
    }
  else {
    yyerror ("MTL internal error: empty recursion stack pop");
    mtli_garbage_collection ();
    return 1;
    }
  } local_operation_list ')' {
  if (mtli_recursion_stack_last_element != NULL) {
    mtli_Recursion_stack_element_list_element
       *tmp_recursion_stack_element_list_element =
       mtli_recursion_stack_last_element->list_element_list;
    while (tmp_recursion_stack_element_list_element != NULL) {
      if (tmp_recursion_stack_element_list_element->next_element == NULL) {
        delete tmp_recursion_stack_element_list_element;
        tmp_recursion_stack_element_list_element = NULL;
        }
      else {
        tmp_recursion_stack_element_list_element =
            tmp_recursion_stack_element_list_element->next_element;
        delete tmp_recursion_stack_element_list_element->previous_element;
        }
      }
    if (mtli_recursion_stack_last_element->previous_element != NULL) {
      mtli_recursion_stack_last_element =
          mtli_recursion_stack_last_element->previous_element;
      delete mtli_recursion_stack_last_element->next_element;
      mtli_recursion_stack_last_element->next_element = NULL;
      }
    else {
      yyerror ("MTL internal error: empty recursion stack pop");
      mtli_garbage_collection ();
      return 1;
      }
    }
  else {
    yyerror ("MTL internal error: empty recursion stack pop");
    mtli_garbage_collection ();
    return 1;
    }
  };

/*
tile_operation: tile_size '(' local_operation_list ')' {
  };
*/

local_operation_list: local_operation {
  }                 | local_operation ',' local_operation_list {
  };

tile_size: '[' number_of_rows ',' number_of_columns ']' {
  $$.number_of_rows = $2;
  $$.number_of_columns = $4;
  };

number_of_rows: integer {
  $$ = $1;
  };

number_of_columns: integer {
  $$ = $1;
  };

local_operation: 'r' location data {


  }            | 'w' location data {


  };

location: '[' row_offset ',' column_offset ']' {
  $$.row_offset = $2;
  $$.column_offset = $4;
  };

row_offset: integer {
  $$ = $1;
  };

column_offset: integer {
  $$ = $1;
  };

integer: DECIMAL_WORD {
  $$ = atoi ($1);
  };

data: DECIMAL_WORD {
  $$ = $1;
  };

global_march_element: time_operation {
  };

time_operation: 't' {


  }           | 't' integer {


  }           | 'T' {


  };

%%


//yyerror
int yyerror (char *error_message) {
  char error_report [200];
  sprintf (error_report, "MTL interpreter: %d: %s at '%s'\n",
      mtli_line_number, error_message, mtlitext);
  xmtvg_error_report (error_report);
  mtl_error = 1;
  return 0;
  }


//mtli_garbage_collection
static void mtli_garbage_collection (void) {
  //mtli_chip_operation_list
  mtli_Chip_operation_list_element *tmp_chip_operation_list_element =
      mtli_chip_operation_list;
  mtli_chip_operation_list = NULL;
  mtli_chip_operation_list_last_element = NULL;
  while (tmp_chip_operation_list_element != NULL) {
    mtli_Operation_list_element *tmp_operation_list_element =
        tmp_chip_operation_list_element->operation_list;
    while (tmp_operation_list_element != NULL) {
      mtli_Port_operation_list_element *tmp_port_operation_list_element =
          tmp_operation_list_element->port_operation_list;
      while (tmp_port_operation_list_element != NULL) {
        delete [] tmp_port_operation_list_element->data;
        if (tmp_port_operation_list_element->next_element == NULL) {
          delete tmp_port_operation_list_element;
          tmp_port_operation_list_element = NULL;
          }
        else {
          tmp_port_operation_list_element =
              tmp_port_operation_list_element->next_element;
          delete tmp_port_operation_list_element->previous_element;
          }
        }
      if (tmp_operation_list_element->next_element == NULL) {
        delete tmp_operation_list_element;
        tmp_operation_list_element = NULL;
        }
      else {
        tmp_operation_list_element = tmp_operation_list_element->next_element;
        delete tmp_operation_list_element->previous_element;
        }
      }
    if (tmp_chip_operation_list_element->next_element == NULL) {
      delete tmp_chip_operation_list_element;
      tmp_chip_operation_list_element = NULL;
      }
    else {
      tmp_chip_operation_list_element =
          tmp_chip_operation_list_element->next_element;
      delete tmp_chip_operation_list_element->previous_element;
      }
    }
  //mtli_recursion_stack
  mtli_Recursion_stack_element *tmp_recursion_stack_element =
      mtli_recursion_stack;
  mtli_recursion_stack = NULL;
  mtli_recursion_stack_last_element = NULL;
  while (tmp_recursion_stack_element != NULL) {
    mtli_Recursion_stack_element_list_element
        *tmp_recursion_stack_element_list_element =
        tmp_recursion_stack_element->list_element_list;
    while (tmp_recursion_stack_element_list_element != NULL) {
      if (tmp_recursion_stack_element_list_element->next_element == NULL) {
        delete tmp_recursion_stack_element_list_element;
        tmp_recursion_stack_element_list_element = NULL;
        }
      else {
        tmp_recursion_stack_element_list_element =
            tmp_recursion_stack_element_list_element->next_element;
        delete tmp_recursion_stack_element_list_element->previous_element;
        }
      }
    if (tmp_recursion_stack_element->next_element == NULL) {
      delete tmp_recursion_stack_element;
      tmp_recursion_stack_element = NULL;
      }
    else {
      tmp_recursion_stack_element =
          tmp_recursion_stack_element->next_element;
      delete tmp_recursion_stack_element->previous_element;
      }
    }
  };

//mtli_fresh_environment
static void mtli_fresh_environment (void) {
  //mtli_chip_operation_list
  mtli_chip_operation_list = new mtli_Chip_operation_list_element;
  assert (mtli_chip_operation_list != NULL); //memory exhausted
  mtli_chip_operation_list_last_element = mtli_chip_operation_list;
  mtli_chip_operation_list->previous_element = NULL;
  mtli_chip_operation_list->next_element = NULL;
  for (int i = 0; i < 27; i++) {
    mtli_chip_operation_list->addressing_identifier[i].status = mtl_undefined;
    mtli_chip_operation_list->addressing_identifier[i].row = 0;
    mtli_chip_operation_list->addressing_identifier[i].column = 0;
    }
  mtli_chip_operation_list->operation_list = NULL;
  mtli_chip_operation_list->operation_list_last_element = NULL;
  mtli_chip_operation_list->next_element =
      new mtli_Chip_operation_list_element;
  assert (mtli_chip_operation_list->next_element != NULL); //memory exhausted
  mtli_chip_operation_list_last_element =
      mtli_chip_operation_list->next_element;
  mtli_chip_operation_list_last_element->previous_element =
      mtli_chip_operation_list;
  mtli_chip_operation_list_last_element->next_element = NULL;
  for (i = 0; i <27; i++) {
    mtli_chip_operation_list_last_element->addressing_identifier[i].status =
        mtl_undefined;
    mtli_chip_operation_list_last_element->addressing_identifier[i].row = 0;
    mtli_chip_operation_list_last_element->addressing_identifier[i].column =
        0;
    }
  mtli_chip_operation_list_last_element->operation_list = NULL;
  mtli_chip_operation_list_last_element->operation_list_last_element = NULL;
  //mtli_recursion_stack
  mtli_recursion_stack = new mtli_Recursion_stack_element;
  assert (mtli_recursion_stack != NULL); //memory exhausted
  mtli_recursion_stack_last_element = mtli_recursion_stack;
  mtli_recursion_stack->previous_element = NULL;
  mtli_recursion_stack->next_element = NULL;
  mtli_recursion_stack->list_element_list =
     new mtli_Recursion_stack_element_list_element;
  assert (mtli_recursion_stack->list_element_list != NULL); //memory exhausted
  mtli_recursion_stack->list_element_list_last_element =
      mtli_recursion_stack->list_element_list;
  mtli_recursion_stack->list_element_list->previous_element = NULL;
  mtli_recursion_stack->list_element_list->next_element = NULL;
  mtli_recursion_stack->list_element_list->chip_operation_list_element =
      mtli_chip_operation_list_last_element;
  };

//mtli_execute_chip_operation_list
static unsigned int mtli_execute_chip_operation_list (void) {


  };
