/*Copyright 1994, 1995, A. Offerman (offerman@einstein.et.tudelft.nl),
                        H.I. Schanstra (ivo@duteca.et.tudelft.nl),
                        Section Computer Architecture & Digital Systems,
                        Department of Electrical Engeneering,
                        Delft University of Technology, The Netherlands
  All rights reserved*/




%{
//MTL interpreter declarations
#include "mtl_decl.h"
#include "defs.h"
#include "porttvec.h"
#include "mtl_dstr.h"
%}


%{
//C/C++
#include <assert.h>
extern "C" {
  #include <stdlib.h>
  #include <string.h>
  }
#define max(a, b) ((a) > (b) ? (a) : (b))
static unsigned int least_common_multiple (unsigned int a, unsigned int b) {
  return (a >= b ? a : b);
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
extern char *mtlatext;
#define YYERROR_VERBOSE 1
int yyerror (char *error_message);
int yylex (void);
%}


//YYSTYPE declaration
%union {unsigned int unsigned_integer;
       char *string; //dynamically allocated
       Tile_size tile_size;
       Attributes attributes;
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
%type <attributes> test_algorithm
%type <attributes> march_element_list
%type <attributes> march_element
%type <attributes> normal_march_element
%type <attributes> column_sub_march_element_list
%type <attributes> column_sub_march_element
%type <attributes> row_sub_march_element_list
%type <attributes> row_sub_march_element
%type <attributes> sub_march_element_list
%type <attributes> sub_march_element
%type <attributes> operation
%type <attributes> port_operation_list
%type <attributes> port_operation
%type <attributes> offset
%type <unsigned_integer> addressing_id_offset
%type <attributes> tile_march_element
%type <attributes> tile_operation
%type <tile_size> tile_size
%type <unsigned_integer> number_of_rows
%type <unsigned_integer> number_of_columns
%type <attributes> local_operation_list
%type <attributes> local_operation
%type <unsigned_integer> integer
%type <string> data
%type <attributes> global_march_element


%%

%start MTL_test
MTL_test: test_type test_algorithm {
  mtla_horizontal_period = $2.horizontal_period;
  mtla_vertical_period = $2.vertical_period;
  mtla_bits_per_word = $2.bits_per_word;
  while (mtla_port_type_vector.size () != 0) {
    mtla_port_type_vector.extract (0);
    }
  unsigned int tmp_return = 0;
  for (int i = 0; i < $2.number_of_ports; i++) {
    switch ($2.port_type_vector [i]) {
      case mtl_read_port: {
        mtla_port_type_vector.insert (i, read_port);
        break;
        }
      case mtl_write_port: {
        mtla_port_type_vector.insert (i, write_port);
        break;
        }
      case mtl_read_write_port: {
        mtla_port_type_vector.insert (i, read_write_port);
        break;
        }
      case mtl_dont_care_port: {
        mtla_port_type_vector.insert (i, dont_care_port);
        break;
        }
      default: {
        yyerror ("MTL internal error: port_type not recognized");
        delete [] $2.port_type_vector;
        tmp_return = 1; //return from yyparse
        break;
        }
      }
    if (tmp_return == 1) {
      return 1;
      }
    }
  delete [] $2.port_type_vector;
  };

test_type: port_list {
  }      | ALLPORTS {
  }      | {
  };

port_list: PORT {
  }      | PORT port_list {
  };

test_algorithm: '{' march_element_list '}' {
  $$.horizontal_period = $2.horizontal_period;
  $$.vertical_period = $2.vertical_period;
  $$.bits_per_word = $2.bits_per_word;
  $$.port_type_vector = $2.port_type_vector;
  $$.number_of_ports = $2.number_of_ports;
  };

march_element_list: march_element {
  $$.horizontal_period = $1.horizontal_period;
  $$.vertical_period = $1.vertical_period;
  $$.bits_per_word = $1.bits_per_word;
  $$.port_type_vector = $1.port_type_vector;
  $$.number_of_ports = $1.number_of_ports;
  }               | march_element ';' march_element_list {
  $$.horizontal_period = least_common_multiple ($1.horizontal_period,
      $3.horizontal_period);
  $$.vertical_period = least_common_multiple ($1.vertical_period,
      $3.vertical_period);
  if ($1.bits_per_word == $3.bits_per_word) {
    $$.bits_per_word == $1.bits_per_word;
    }
  else {
    if ($1.bits_per_word == 1) {
      $$.bits_per_word = $3.bits_per_word;
      }
    else {
      if ($3.bits_per_word == 1) {
        $$.bits_per_word = $1.bits_per_word;
        }
      else {
        yyerror ("MTL attributes error: bits per word conflict");
        delete [] $1.port_type_vector;
        delete [] $3.port_type_vector;
        return 1;
        }
      }
    }
  if ($1.number_of_ports == $3.number_of_ports) {
    $$.port_type_vector = new unsigned int [$1.number_of_ports];
    assert ($$.port_type_vector != NULL); //memory exhausted
    $$.number_of_ports = $1.number_of_ports;
    for (int i = 0; i < $1.number_of_ports; i++) {
      if ($1.port_type_vector [i] == mtl_read_write_port ||
          $3.port_type_vector [i] == mtl_read_write_port) {
        $$.port_type_vector [i] = mtl_read_write_port;
        }
      else {
        if ($1.port_type_vector [i] == $3.port_type_vector [i]) {
          $$.port_type_vector [i] = $1.port_type_vector [i];
          }
        else {
          if ($1.port_type_vector [i] == mtl_dont_care_port) {
            $$.port_type_vector [i] = $3.port_type_vector [i];
            }
          else {
            if ($3.port_type_vector [i] == mtl_dont_care_port) {
              $$.port_type_vector [i] = $1.port_type_vector [i];
              }
            else {
              $$.port_type_vector [i] = mtl_read_write_port;
              }
            }
          }
        }
      }
    delete [] $1.port_type_vector;
    delete [] $3.port_type_vector;
    }
  else {
    if ($1.number_of_ports == 0) {
      $$.port_type_vector = $3.port_type_vector;
      $$.number_of_ports = $3.number_of_ports;
      delete [] $1.port_type_vector;
      }
    else {
      if ($3.number_of_ports == 0) {
        $$.port_type_vector = $1.port_type_vector;
        $$.number_of_ports = $1.number_of_ports;
        delete [] $3.port_type_vector;
        }
      else {
        yyerror ("MTL attributes error: number of ports conflict");
        delete [] $1.port_type_vector;
        delete [] $3.port_type_vector;
        return 1;
        }
      }
    }
  };

march_element: normal_march_element {
  $$.horizontal_period = $1.horizontal_period;
  $$.vertical_period = $1.vertical_period;
  $$.bits_per_word = $1.bits_per_word;
  $$.port_type_vector = $1.port_type_vector;
  $$.number_of_ports = $1.number_of_ports;
  }          | tile_march_element {
  $$.horizontal_period = $1.horizontal_period;
  $$.vertical_period = $1.vertical_period;
  $$.bits_per_word = $1.bits_per_word;
  $$.port_type_vector = $1.port_type_vector;
  $$.number_of_ports = $1.number_of_ports;
  }          | global_march_element {
  $$.horizontal_period = 1;
  $$.vertical_period = 1;
  $$.bits_per_word = 1;
  $$.port_type_vector = NULL;
  $$.number_of_ports = 0;
  };

normal_march_element: _1_dimensional_addressing_direction '(' sub_march_element_list ')' {
  $$.horizontal_period = $3.horizontal_period;
  $$.vertical_period = $3.vertical_period;
  $$.bits_per_word = $3.bits_per_word;
  $$.port_type_vector = $3.port_type_vector;
  $$.number_of_ports = $3.number_of_ports;
  }                 | _1_dimensional_addressing_direction addressing_id '(' sub_march_element_list ')' {
  $$.horizontal_period = $4.horizontal_period;
  $$.vertical_period = $4.vertical_period;
  $$.bits_per_word = $4.bits_per_word;
  $$.port_type_vector = $4.port_type_vector;
  $$.number_of_ports = $4.number_of_ports;
  }                 | row_addressing_direction '(' column_sub_march_element_list ')' {
  $$.horizontal_period = $3.horizontal_period;
  $$.vertical_period = $3.vertical_period;
  $$.bits_per_word = $3.bits_per_word;
  $$.port_type_vector = $3.port_type_vector;
  $$.number_of_ports = $3.number_of_ports;
  }                 | row_addressing_direction addressing_id '(' column_sub_march_element_list ')' {
  $$.horizontal_period = $4.horizontal_period;
  $$.vertical_period = $4.vertical_period;
  $$.bits_per_word = $4.bits_per_word;
  $$.port_type_vector = $4.port_type_vector;
  $$.number_of_ports = $4.number_of_ports;
  }                 | column_addressing_direction '(' row_sub_march_element_list ')' {
  $$.horizontal_period = $3.horizontal_period;
  $$.vertical_period = $3.vertical_period;
  $$.bits_per_word = $3.bits_per_word;
  $$.port_type_vector = $3.port_type_vector;
  $$.number_of_ports = $3.number_of_ports;
  }                 | column_addressing_direction addressing_id '(' row_sub_march_element_list ')' {
  $$.horizontal_period = $4.horizontal_period;
  $$.vertical_period = $4.vertical_period;
  $$.bits_per_word = $4.bits_per_word;
  $$.port_type_vector = $4.port_type_vector;
  $$.number_of_ports = $4.number_of_ports;
  };

column_sub_march_element_list: column_sub_march_element {
  $$.horizontal_period = $1.horizontal_period;
  $$.vertical_period = $1.vertical_period;
  $$.bits_per_word = $1.bits_per_word;
  $$.port_type_vector = $1.port_type_vector;
  $$.number_of_ports = $1.number_of_ports;
  }                          | column_sub_march_element ',' column_sub_march_element_list {
  $$.horizontal_period = max ($1.horizontal_period, $3.horizontal_period);
  $$.vertical_period = max ($1.vertical_period, $3.vertical_period);
  if ($1.bits_per_word == $3.bits_per_word) {
    $$.bits_per_word == $1.bits_per_word;
    }
  else {
    if ($1.bits_per_word == 1) {
      $$.bits_per_word = $3.bits_per_word;
      }
    else {
      if ($3.bits_per_word == 1) {
        $$.bits_per_word = $1.bits_per_word;
        }
      else {
        yyerror ("MTL attributes error: bits per word conflict");
        delete [] $1.port_type_vector;
        delete [] $3.port_type_vector;
        return 1;
        }
      }
    }
  if ($1.number_of_ports == $3.number_of_ports) {
    $$.port_type_vector = new unsigned int [$1.number_of_ports];
    assert ($$.port_type_vector != NULL); //memory exhausted
    $$.number_of_ports = $1.number_of_ports;
    for (int i = 0; i < $1.number_of_ports; i++) {
      if ($1.port_type_vector [i] == mtl_read_write_port ||
          $3.port_type_vector [i] == mtl_read_write_port) {
        $$.port_type_vector [i] = mtl_read_write_port;
        }
      else {
        if ($1.port_type_vector [i] == $3.port_type_vector [i]) {
          $$.port_type_vector [i] = $1.port_type_vector [i];
          }
        else {
          if ($1.port_type_vector [i] == mtl_dont_care_port) {
            $$.port_type_vector [i] = $3.port_type_vector [i];
            }
          else {
            if ($3.port_type_vector [i] == mtl_dont_care_port) {
              $$.port_type_vector [i] = $1.port_type_vector [i];
              }
            else {
              $$.port_type_vector [i] = mtl_read_write_port;
              }
            }
          }
        }
      }
    delete [] $1.port_type_vector;
    delete [] $3.port_type_vector;
    }
  else {
    if ($1.number_of_ports == 0) {
      $$.port_type_vector = $3.port_type_vector;
      $$.number_of_ports = $3.number_of_ports;
      delete [] $1.port_type_vector;
      }
    else {
      if ($3.number_of_ports == 0) {
        $$.port_type_vector = $1.port_type_vector;
        $$.number_of_ports = $1.number_of_ports;
        delete [] $3.port_type_vector;
        }
      else {
        yyerror ("MTL attributes error: number of ports conflict");
        delete [] $1.port_type_vector;
        delete [] $3.port_type_vector;
        return 1;
        }
      }
    }
  };

column_sub_march_element: column_addressing_direction '(' sub_march_element_list ')' {
  $$.horizontal_period = $3.horizontal_period;
  $$.vertical_period = $3.vertical_period;
  $$.bits_per_word = $3.bits_per_word;
  $$.port_type_vector = $3.port_type_vector;
  $$.number_of_ports = $3.number_of_ports;
  }                     | column_addressing_direction addressing_id '(' sub_march_element_list ')' {
  $$.horizontal_period = $4.horizontal_period;
  $$.vertical_period = $4.vertical_period;
  $$.bits_per_word = $4.bits_per_word;
  $$.port_type_vector = $4.port_type_vector;
  $$.number_of_ports = $4.number_of_ports;
  }                     | time_operation {
  $$.horizontal_period = 1;
  $$.vertical_period = 1;
  $$.bits_per_word = 1;
  $$.port_type_vector = NULL;
  $$.number_of_ports = 0;
  };

row_sub_march_element_list: row_sub_march_element {
  $$.horizontal_period = $1.horizontal_period;
  $$.vertical_period = $1.vertical_period;
  $$.bits_per_word = $1.bits_per_word;
  $$.port_type_vector = $1.port_type_vector;
  $$.number_of_ports = $1.number_of_ports;
  }                       | row_sub_march_element ',' row_sub_march_element_list {
  $$.horizontal_period = max ($1.horizontal_period, $3.horizontal_period);
  $$.vertical_period = max ($1.vertical_period, $3.vertical_period);
  if ($1.bits_per_word == $3.bits_per_word) {
    $$.bits_per_word == $1.bits_per_word;
    }
  else {
    if ($1.bits_per_word == 1) {
      $$.bits_per_word = $3.bits_per_word;
      }
    else {
      if ($3.bits_per_word == 1) {
        $$.bits_per_word = $1.bits_per_word;
        }
      else {
        yyerror ("MTL attributes error: bits per word conflict");
        delete [] $1.port_type_vector;
        delete [] $3.port_type_vector;
        return 1;
        }
      }
    }
  if ($1.number_of_ports == $3.number_of_ports) {
    $$.port_type_vector = new unsigned int [$1.number_of_ports];
    assert ($$.port_type_vector != NULL); //memory exhausted
    $$.number_of_ports = $1.number_of_ports;
    for (int i = 0; i < $1.number_of_ports; i++) {
      if ($1.port_type_vector [i] == mtl_read_write_port ||
          $3.port_type_vector [i] == mtl_read_write_port) {
        $$.port_type_vector [i] = mtl_read_write_port;
        }
      else {
        if ($1.port_type_vector [i] == $3.port_type_vector [i]) {
          $$.port_type_vector [i] = $1.port_type_vector [i];
          }
        else {
          if ($1.port_type_vector [i] == mtl_dont_care_port) {
            $$.port_type_vector [i] = $3.port_type_vector [i];
            }
          else {
            if ($3.port_type_vector [i] == mtl_dont_care_port) {
              $$.port_type_vector [i] = $1.port_type_vector [i];
              }
            else {
              $$.port_type_vector [i] = mtl_read_write_port;
              }
            }
          }
        }
      }
    delete [] $1.port_type_vector;
    delete [] $3.port_type_vector;
    }
  else {
    if ($1.number_of_ports == 0) {
      $$.port_type_vector = $3.port_type_vector;
      $$.number_of_ports = $3.number_of_ports;
      delete [] $1.port_type_vector;
      }
    else {
      if ($3.number_of_ports == 0) {
        $$.port_type_vector = $1.port_type_vector;
        $$.number_of_ports = $1.number_of_ports;
        delete [] $3.port_type_vector;
        }
      else {
        yyerror ("MTL attributes error: number of ports conflict");
        delete [] $1.port_type_vector;
        delete [] $3.port_type_vector;
        return 1;
        }
      }
    }
  };

row_sub_march_element: row_addressing_direction '(' sub_march_element_list ')' {
  $$.horizontal_period = $3.horizontal_period;
  $$.vertical_period = $3.vertical_period;
  $$.bits_per_word = $3.bits_per_word;
  $$.port_type_vector = $3.port_type_vector;
  $$.number_of_ports = $3.number_of_ports;
  }                  | row_addressing_direction addressing_id '(' sub_march_element_list ')' {
  $$.horizontal_period = $4.horizontal_period;
  $$.vertical_period = $4.vertical_period;
  $$.bits_per_word = $4.bits_per_word;
  $$.port_type_vector = $4.port_type_vector;
  $$.number_of_ports = $4.number_of_ports;
  }                  | time_operation {
  $$.horizontal_period = 1;
  $$.vertical_period = 1;
  $$.bits_per_word = 1;
  $$.port_type_vector = NULL;
  $$.number_of_ports = 0;
  };

sub_march_element_list: sub_march_element {
  $$.horizontal_period = $1.horizontal_period;
  $$.vertical_period = $1.vertical_period;
  $$.bits_per_word = $1.bits_per_word;
  $$.port_type_vector = $1.port_type_vector;
  $$.number_of_ports = $1.number_of_ports;
  }                   | sub_march_element ',' sub_march_element_list {
  $$.horizontal_period = max ($1.horizontal_period, $3.horizontal_period);
  $$.vertical_period = max ($1.vertical_period, $3.vertical_period);
  if ($1.bits_per_word == $3.bits_per_word) {
    $$.bits_per_word == $1.bits_per_word;
    }
  else {
    if ($1.bits_per_word == 1) {
      $$.bits_per_word = $3.bits_per_word;
      }
    else {
      if ($3.bits_per_word == 1) {
        $$.bits_per_word = $1.bits_per_word;
        }
      else {
        yyerror ("MTL attributes error: bits per word conflict");
        delete [] $1.port_type_vector;
        delete [] $3.port_type_vector;
        return 1;
        }
      }
    }
  if ($1.number_of_ports == $3.number_of_ports) {
    $$.port_type_vector = new unsigned int [$1.number_of_ports];
    assert ($$.port_type_vector != NULL); //memory exhausted
    $$.number_of_ports = $1.number_of_ports;
    for (int i = 0; i < $1.number_of_ports; i++) {
      if ($1.port_type_vector [i] == mtl_read_write_port ||
          $3.port_type_vector [i] == mtl_read_write_port) {
        $$.port_type_vector [i] = mtl_read_write_port;
        }
      else {
        if ($1.port_type_vector [i] == $3.port_type_vector [i]) {
          $$.port_type_vector [i] = $1.port_type_vector [i];
          }
        else {
          if ($1.port_type_vector [i] == mtl_dont_care_port) {
            $$.port_type_vector [i] = $3.port_type_vector [i];
            }
          else {
            if ($3.port_type_vector [i] == mtl_dont_care_port) {
              $$.port_type_vector [i] = $1.port_type_vector [i];
              }
            else {
              $$.port_type_vector [i] = mtl_read_write_port;
              }
            }
          }
        }
      }
    delete [] $1.port_type_vector;
    delete [] $3.port_type_vector;
    }
  else {
    if ($1.number_of_ports == 0) {
      $$.port_type_vector = $3.port_type_vector;
      $$.number_of_ports = $3.number_of_ports;
      delete [] $1.port_type_vector;
      }
    else {
      if ($3.number_of_ports == 0) {
        $$.port_type_vector = $1.port_type_vector;
        $$.number_of_ports = $1.number_of_ports;
        delete [] $3.port_type_vector;
        }
      else {
        yyerror ("MTL attributes error: number of ports conflict");
        delete [] $1.port_type_vector;
        delete [] $3.port_type_vector;
        return 1;
        }
      }
    }
  };

sub_march_element: addressing_specifier '(' sub_march_element_list ')' {
  $$.horizontal_period = $3.horizontal_period;
  $$.vertical_period = $3.vertical_period;
  $$.bits_per_word = $3.bits_per_word;
  $$.port_type_vector = $3.port_type_vector;
  $$.number_of_ports = $3.number_of_ports;
  }              | operation {
  $$.horizontal_period = $1.horizontal_period;
  $$.vertical_period = $1.vertical_period;
  $$.bits_per_word = $1.bits_per_word;
  $$.port_type_vector = $1.port_type_vector;
  $$.number_of_ports = $1.number_of_ports;
  }              | time_operation {
  $$.horizontal_period = 1;
  $$.vertical_period = 1;
  $$.bits_per_word = 1;
  $$.port_type_vector = NULL;
  $$.number_of_ports = 0;
  };

addressing_specifier: addressing_direction {
  }                 | addressing_direction addressing_id {
  }                 | addressing_direction addressing_id '=' OPERATOR addressing_id {
  if ($4 != mtl_minus) {
    yyerror ("MTL attributes error: '-' expected");
    return 1;
    }
  }                 | addressing_direction OPERATOR addressing_id {
  if ($2 != mtl_minus) {
    yyerror ("MTL attributes error: '-' expected");
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
  $$.horizontal_period = $1.horizontal_period;
  $$.vertical_period = $1.vertical_period;
  $$.bits_per_word = $1.bits_per_word;
  $$.port_type_vector = $1.port_type_vector;
  $$.number_of_ports = $1.number_of_ports;
  };

port_operation_list: port_operation {
  $$.horizontal_period = $1.horizontal_period;
  $$.vertical_period = $1.vertical_period;
  $$.bits_per_word = $1.bits_per_word;
  $$.port_type_vector = $1.port_type_vector;
  $$.number_of_ports = $1.number_of_ports;
  }                | port_operation ':' port_operation_list {
  $$.horizontal_period = max ($1.horizontal_period, $3.horizontal_period);
  $$.vertical_period = max ($1.vertical_period, $3.vertical_period);
  if ($1.bits_per_word == $3.bits_per_word) {
    $$.bits_per_word = $1.bits_per_word;
    }
  else {
    if ($1.bits_per_word == 1) {
      $$.bits_per_word = $3.bits_per_word;
      }
    else {
      if ($3.bits_per_word == 1) {
        $$.bits_per_word = $1.bits_per_word;
        }
      else {
        yyerror ("MTL attributes error: bits per word conflict");
        delete [] $1.port_type_vector;
        delete [] $3.port_type_vector;
        return 1;
        }
      }
    }
  $$.port_type_vector = new unsigned int [$3.number_of_ports + 1];
  assert ($$.port_type_vector != NULL); //memory exhausted
  $$.number_of_ports = $3.number_of_ports + 1;
  $$.port_type_vector [0] = $1.port_type_vector [0];
  for (int i = 0; i < $3.number_of_ports; i++) {
    $$.port_type_vector [i + 1] = $3.port_type_vector [i];
    }
  delete [] $1.port_type_vector;
  delete [] $3.port_type_vector;
  };

port_operation: 'r' data {
  $$.horizontal_period = 1;
  $$.vertical_period = 1;
  $$.bits_per_word = strlen ($2);
  $$.port_type_vector = new unsigned int [1];
  assert ($$.port_type_vector != NULL); //memory exhausted
  $$.number_of_ports = 1;
  $$.port_type_vector [0] = mtl_read_port;
  delete [] $2;
  }           | 'w' data {
  $$.horizontal_period = 1;
  $$.vertical_period = 1;
  $$.bits_per_word = strlen ($2);
  $$.port_type_vector = new unsigned int [1];
  assert ($$.port_type_vector != NULL); //memory exhausted
  $$.number_of_ports = 1;
  $$.port_type_vector [0] = mtl_write_port;
  delete [] $2;
  }           | 'r' offset data {
  $$.horizontal_period = $2.horizontal_period;
  $$.vertical_period = $2.vertical_period;
  $$.bits_per_word = strlen ($3);
  $$.port_type_vector = new unsigned int [1];
  assert ($$.port_type_vector != NULL); //memory exhausted
  $$.number_of_ports = 1;
  $$.port_type_vector [0] = mtl_read_port;
  delete [] $3;
  }           | 'w' offset data {
  $$.horizontal_period = $2.horizontal_period;
  $$.vertical_period = $2.vertical_period;
  $$.bits_per_word = strlen ($3);
  $$.port_type_vector = new unsigned int [1];
  assert ($$.port_type_vector != NULL); //memory exhausted
  $$.number_of_ports = 1;
  $$.port_type_vector [0] = mtl_write_port;
  delete [] $3;
  }           | NOP {
  $$.horizontal_period = 1;
  $$.vertical_period = 1;
  $$.bits_per_word = 1;
  $$.port_type_vector = new unsigned int [1];
  assert ($$.port_type_vector != NULL); //memory exhausted
  $$.number_of_ports = 1;
  $$.port_type_vector [0] = mtl_dont_care_port;
  };

offset: '[' addressing_id_offset ']' {
  $$.horizontal_period = $2;
  $$.vertical_period = $2;
  }   | '[' addressing_id_offset ',' addressing_id_offset ']' {
  $$.horizontal_period = $4;
  $$.vertical_period = $2;
  };

addressing_id_offset: addressing_id {
  $$ = 1;
  }                 | addressing_id OPERATOR integer {
  $$ = 2 * $3 + 1;
  };

tile_march_element: _1_dimensional_addressing_direction tile_operation {
  $$.horizontal_period = $2.horizontal_period;
  $$.vertical_period = $2.vertical_period;
  $$.bits_per_word = $2.bits_per_word;
  $$.port_type_vector = $2.port_type_vector;
  $$.number_of_ports = $2.number_of_ports;
  }               | row_addressing_direction column_addressing_direction tile_operation {
  $$.horizontal_period = $3.horizontal_period;
  $$.vertical_period = $3.vertical_period;
  $$.bits_per_word = $3.bits_per_word;
  $$.port_type_vector = $3.port_type_vector;
  $$.number_of_ports = $3.number_of_ports;
  }               | column_addressing_direction row_addressing_direction tile_operation {
  $$.horizontal_period = $3.horizontal_period;
  $$.vertical_period = $3.vertical_period;
  $$.bits_per_word = $3.bits_per_word;
  $$.port_type_vector = $3.port_type_vector;
  $$.number_of_ports = $3.number_of_ports;
  };

tile_operation: tile_size '(' local_operation_list ')' {
  $$.horizontal_period = $1.number_of_columns;
  $$.vertical_period = $1.number_of_rows;
  $$.bits_per_word = $3.bits_per_word;
  $$.port_type_vector = $3.port_type_vector;
  $$.number_of_ports = $3.number_of_ports;
  };

local_operation_list: local_operation {
  $$.bits_per_word = $1.bits_per_word;
  $$.port_type_vector = $1.port_type_vector;
  $$.number_of_ports = $1.number_of_ports;
  }                 | local_operation ',' local_operation_list {
  if ($1.bits_per_word == $3.bits_per_word) {
    $$.bits_per_word = $1.bits_per_word;
    }
  else {
    if ($1.bits_per_word == 1) {
      $$.bits_per_word = $3.bits_per_word;
      }
    else {
      if ($3.bits_per_word == 1) {
        $$.bits_per_word = $1.bits_per_word;
        }
      else {
        yyerror ("MTL attributes error: bits per word conflict");
        delete [] $1.port_type_vector;
        delete [] $3.port_type_vector;
        return 1;
        }
      }
    }
  $$.port_type_vector = new unsigned int [1];
  assert ($$.port_type_vector != NULL); //memory exhausted
  $$.number_of_ports = 1;
  if ($1.port_type_vector [0] == mtl_read_write_port ||
      $3.port_type_vector [0] == mtl_read_write_port) {
    $$.port_type_vector [0] = mtl_read_write_port;
    }
  else {
    if ($1.port_type_vector [0] == $3.port_type_vector [0]) {
      $$.port_type_vector [0] = $1.port_type_vector [0];
      }
    else {
      if ($1.port_type_vector [0] == mtl_dont_care_port) {
        $$.port_type_vector [0] = $3.port_type_vector [0];
        }
      else {
        if ($3.port_type_vector [0] == mtl_dont_care_port) {
          $$.port_type_vector [0] = $1.port_type_vector [0];
          }
        else {
          $$.port_type_vector [0] = mtl_read_write_port;
          }
        }
      }
    }
  delete [] $1.port_type_vector;
  delete [] $3.port_type_vector;
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
  $$.bits_per_word = strlen ($3);
  $$.port_type_vector = new unsigned int [1];
  assert ($$.port_type_vector != NULL); //memory exhausted
  $$.number_of_ports = 1;
  $$.port_type_vector [0] = mtl_read_port;
  delete [] $3;
  }            | 'w' location data {
  $$.bits_per_word = strlen ($3);
  $$.port_type_vector = new unsigned int [1];
  assert ($$.port_type_vector != NULL); //memory exhausted
  $$.number_of_ports = 1;
  $$.port_type_vector [0] = mtl_write_port;
  delete [] $3;
  };

location: '[' row_offset ',' column_offset ']' {
  };

row_offset: integer {
  };

column_offset: integer {
  };

integer: DECIMAL_WORD {
  $$ = atoi ($1);
  delete [] $1;
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
  sprintf (error_report, "MTL attributes: %d: %s at '%s'\n", mtla_line_number,
      error_message, mtlatext);
  xmtvg_error_report (error_report);
  mtl_error = 1;
  return 0;
  }
