/*X Memory Test Verification and Generation
  Copyright 1994, 1995, A. Offerman (offerman@einstein.et.tudelft.nl),
                        H.I. Schanstra (ivo@duteca.et.tudelft.nl),
                        Section Computer Architecture & Digital Systems,
                        Department of Electrical Engeneering,
                        Delft University of Technology, The Netherlands
  All rights reserved*/




%{
//MTL interpreter declarations
#include "mtl_decl.h"
#include "mtl_dstr.h"
%}


%{
//C/C++
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
#include "defs.h"
#include "porttvec.h"
%}


%{
//bison declarations
extern char *mtlptext;
#define YYERROR_VERBOSE 1
int yyerror (char *error_message);
int yylex (void);
%}


//YYSTYPE declaration
%union {unsigned int unsigned_integer;
       char *string; //dynamically allocated
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


%%

%start MTL_test
MTL_test: test_type test_algorithm {
  };

test_type: port_list {
  }      | ALLPORTS {
  mtlp_all_ports = 1;
  mtlp_current_port = 0;
  }      | {
  };

port_list: PORT {
  unsigned int tmp_return = 0;
  switch ($1) {
    case mtl_read_port: {
      mtlp_port_type_vector.insert (mtlp_port_type_vector.size (), read_port);
      break;
      }
    case mtl_write_port: {
      mtlp_port_type_vector.insert (mtlp_port_type_vector.size (),
          write_port);
      break;
      }
    case mtl_read_write_port: {
      mtlp_port_type_vector.insert (mtlp_port_type_vector.size (),
          read_write_port);
      break;
      }
    case mtl_dont_care_port: {
      mtlp_port_type_vector.insert (mtlp_port_type_vector.size (),
          dont_care_port);
      break;
      }
    default: {
      yyerror ("MTL internal error: port_type not recognized");
      tmp_return = 1; //return from yyparse
      break;
      }
    }
  if (tmp_return == 1) {
    return 1;
    }
  }      | PORT port_list {
  unsigned int tmp_return = 0;
  switch ($1) {
    case mtl_read_port: {
      mtlp_port_type_vector.insert (mtlp_port_type_vector.size (), read_port);
      break;
      }
    case mtl_write_port: {
      mtlp_port_type_vector.insert (mtlp_port_type_vector.size (),
          write_port);
      break;
      }
    case mtl_read_write_port: {
      mtlp_port_type_vector.insert (mtlp_port_type_vector.size (),
          read_write_port);
      break;
      }
    case mtl_dont_care_port: {
      mtlp_port_type_vector.insert (mtlp_port_type_vector.size (),
          dont_care_port);
      break;
      }
    default: {
      yyerror ("MTL internal error: port_type not recognized");
      tmp_return = 1; //return from yyparse
      break;
      }
    }
  if (tmp_return == 1) {
    return 1;
    }
  };

test_algorithm: '{' march_element_list '}' {
  };

march_element_list: march_element {
  }               | march_element ';' march_element_list {
  };

march_element: normal_march_element {
  }          | tile_march_element {
  }          | global_march_element {
  };

normal_march_element: _1_dimensional_addressing_direction '(' sub_march_element_list ')' {
  }                 | _1_dimensional_addressing_direction addressing_id '(' sub_march_element_list ')' {
  }                 | row_addressing_direction '(' column_sub_march_element_list ')' {
  }                 | row_addressing_direction addressing_id '(' column_sub_march_element_list ')' {
  }                 | column_addressing_direction '(' row_sub_march_element_list ')' {
  }                 | column_addressing_direction addressing_id '(' row_sub_march_element_list ')' {
  };

column_sub_march_element_list: column_sub_march_element {
  }                          | column_sub_march_element ',' column_sub_march_element_list {
  };

column_sub_march_element: column_addressing_direction '(' sub_march_element_list ')' {
  }                     | column_addressing_direction addressing_id '(' sub_march_element_list ')' {
  }                     | time_operation {
  };

row_sub_march_element_list: row_sub_march_element {
  }                       | row_sub_march_element ',' row_sub_march_element_list {
  };

row_sub_march_element: row_addressing_direction '(' sub_march_element_list ')' {
  }                  | row_addressing_direction addressing_id '(' sub_march_element_list ')' {
  }                  | time_operation {
  };

sub_march_element_list: sub_march_element {
  }                   | sub_march_element ',' sub_march_element_list {
  };

sub_march_element: addressing_specifier '(' sub_march_element_list ')' {
  }              | operation {
  }              | time_operation {
  };

addressing_specifier: addressing_direction {
  }                 | addressing_direction addressing_id {
  }                 | addressing_direction addressing_id '=' OPERATOR addressing_id {
  if ($4 != mtl_minus) {
    yyerror ("MTL preprocessor error: '-' expected");
    return 1;
    }
  }                 | addressing_direction OPERATOR addressing_id {
  if ($2 != mtl_minus) {
    yyerror ("MTL preprocessor error: '-' expected");
    return 1;
    }
  };

addressing_direction: _1_dimensional_addressing_direction {
  }                 | row_addressing_direction {
  }                 | column_addressing_direction {
  };

_1_dimensional_addressing_direction: UP_DOWN {
  }                                | DOWN {
  }                                | UP {
  };

row_addressing_direction: EAST_WEST {
  }                     | EAST {
  }                     | WEST {
  };

column_addressing_direction: NORTH_SOUTH {
  }                        | SOUTH {
  }                        | NORTH {
  };

addressing_id: 'a' {
  }          | 'b' {
  }          | 'c' {
  }          | 'd' {
  }          | 'e' {
  }          | 'f' {
  }          | 'g' {
  }          | 'h' {
  }          | 'i' {
  }          | 'j' {
  }          | 'k' {
  }          | 'l' {
  }          | 'm' {
  }          | 'n' {
  }          | 'o' {
  }          | 'p' {
  }          | 'q' {
  }          | 'r' {
  }          | 's' {
  }          | 't' {
  }          | 'u' {
  }          | 'v' {
  }          | 'w' {
  }          | 'x' {
  }          | 'y' {
  }          | 'z' {
  }          | 'A' {
  }          | 'B' {
  }          | 'C' {
  }          | 'D' {
  }          | 'E' {
  }          | 'F' {
  }          | 'G' {
  }          | 'H' {
  }          | 'I' {
  }          | 'J' {
  }          | 'K' {
  }          | 'L' {
  }          | 'M' {
  }          | 'N' {
  }          | 'O' {
  }          | 'P' {
  }          | 'Q' {
  }          | 'R' {
  }          | 'S' {
  }          | 'T' {
  }          | 'U' {
  }          | 'V' {
  }          | 'W' {
  }          | 'X' {
  }          | 'Y' {
  }          | 'Z' {
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
  }   | '[' addressing_id_offset ',' addressing_id_offset ']' {
  };

addressing_id_offset: addressing_id {
  }                 | addressing_id OPERATOR integer {
  };

tile_march_element: _1_dimensional_addressing_direction tile_operation {
  }               | row_addressing_direction column_addressing_direction tile_operation {
  }               | column_addressing_direction row_addressing_direction tile_operation {
  };

tile_operation: tile_size '(' local_operation_list ')' {
  };

local_operation_list: local_operation {
  }                 | local_operation ',' local_operation_list {
  };

tile_size: '[' number_of_rows ',' number_of_columns ']' {
  };

number_of_rows: integer {
  };

number_of_columns: integer {
  };

local_operation: 'r' location data {
  }            | 'w' location data {
  };

location: '[' row_offset ',' column_offset ']' {
  };

row_offset: integer {
  };

column_offset: integer {
  };

integer: DECIMAL_WORD {
  };

data: DECIMAL_WORD {
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
  sprintf (error_report, "MTL preprocessor: %d: %s at '%s'\n",
      mtlp_line_number, error_message, mtlptext);
  xmtvg_error_report (error_report);
  mtl_error = 1;
  return 0;
  }
