%{
//X Memory Test Verification and Generation
//Copyright 1994, 1995, A. Offerman (offerman@einstein.et.tudelft.nl),
//                      H.I. Schanstra (ivo@duteca.et.tudelft.nl),
//                      Section Computer Architecture & Digital Systems,
//                      Department of Electrical Engeneering,
//                      Delft University of Technology, The Netherlands
//All rights reserved
%}




%{
//MTL interpreter declarations
#include "mtl_decl.h"
#include "mtl_dstr.h"
%}


%{
//flex declarations
#include "mtlp.h"
%}


%{
//C/C++
#include <assert.h>
%}


%{
//MTL interpreter input
int mtlp_input (char *buffer, int buffer_size);
#define min(a, b) ((a) < (b) ? (a) : (b))
extern "C" {
  #include <string.h>
  }
#undef YY_INPUT
#define YY_INPUT(b, r, ms) (r = mtlp_input (b, ms))
%}


%s TEST_ALGORITHM


%%

[\t ]+ {//ignore whitespace
       }

#.* {//ignore comments
    }

\n {//newline
   mtlp_line_number++;
   }

<INITIAL>allports |
<INITIAL>ALLPORTS {//allports
                  BEGIN TEST_ALGORITHM;
                  return ALLPORTS;
                  }

<INITIAL>r {//read port
           mtlplval.unsigned_integer = mtl_read_port;
           return PORT;
           }
<INITIAL>w {//write port
           mtlplval.unsigned_integer = mtl_write_port;
           return PORT;
           }
<INITIAL>x {//read/write port
           mtlplval.unsigned_integer = mtl_read_write_port;
           return PORT;
           }
<INITIAL>- {//don't care port
           mtlplval.unsigned_integer = mtl_dont_care_port;
           return PORT;
           }
<INITIAL>\{ {//start test algorithm
            BEGIN TEST_ALGORITHM;
            return '{';
            }

<INITIAL>. {//rest
           return yytext [0];
           }

<TEST_ALGORITHM>down |
<TEST_ALGORITHM>DOWN |
<TEST_ALGORITHM>\xC8 {//down addressing order
                     return DOWN;
                     }
<TEST_ALGORITHM>up |
<TEST_ALGORITHM>UP |
<TEST_ALGORITHM>\xC9 {//up addressing order
                     return UP;
                     }
<TEST_ALGORITHM>updown |
<TEST_ALGORITHM>UPDOWN |
<TEST_ALGORITHM>\xCA {//up/down addressing order
                     return UP_DOWN;
                     }
<TEST_ALGORITHM>south |
<TEST_ALGORITHM>SOUTH |
<TEST_ALGORITHM>\xCB {//south addressing order
                     return SOUTH;
                     }
<TEST_ALGORITHM>north |
<TEST_ALGORITHM>NORTH |
<TEST_ALGORITHM>\xCC {//north addressing order
                     return NORTH;
                     }
<TEST_ALGORITHM>northsouth |
<TEST_ALGORITHM>NORTHSOUTH |
<TEST_ALGORITHM>\xCD {//north/south addressing order
                     return NORTH_SOUTH;
                     }
<TEST_ALGORITHM>east |
<TEST_ALGORITHM>EAST |
<TEST_ALGORITHM>\xCE {//east addressing order
                     return EAST;
                     }
<TEST_ALGORITHM>west |
<TEST_ALGORITHM>WEST |
<TEST_ALGORITHM>\xCF {//west addressing order
                     return WEST;
                     }
<TEST_ALGORITHM>eastwest |
<TEST_ALGORITHM>EASTWEST |
<TEST_ALGORITHM>\xD0 {//east/west addressing order
                     return EAST_WEST;
                     }

<TEST_ALGORITHM>[a..zA..Z] {//character
                           return yytext [0];
                           }

<TEST_ALGORITHM>\+ {//+ operator
                   mtlplval.unsigned_integer = mtl_plus;
                   return OPERATOR;
                   }
<TEST_ALGORITHM>\- {//- operator
                   mtlplval.unsigned_integer = mtl_minus;
                   return OPERATOR;
                   }

<TEST_ALGORITHM>[0-9]+ {//decimal word
                       mtlplval.string = new char [strlen (yytext) + 1];
                       assert (mtlplval.string != NULL); //memory exhausted
                       strcpy (mtlplval.string, yytext);
                       return DECIMAL_WORD;
                       }

<TEST_ALGORITHM>nop |
<TEST_ALGORITHM>NOP {//no operation
                    return NOP;
                    }

<TEST_ALGORITHM>\} {//end test algorithm
                   BEGIN INITIAL;
                   return '}';
                   }

<TEST_ALGORITHM>. {//rest
                  return yytext [0];
                  }

%%


//MTL interpreter input
int mtlp_input (char *buffer, int buffer_size) {
  int n = min (buffer_size, mtlp_test_sentinel - mtlp_test_current);
  if (n > 0) {
    memcpy (buffer, mtlp_test_current, n);
    mtlp_test_current += n;
    }
  return n;
  }

//yywrap
int yywrap () {
  return 1;
  }
