/*X Memory Test Verification and Generation
  Copyright 1995, A. Offerman (offerman@einstein.et.tudelft.nl),
                  H.I. Schanstra (ivo@duteca.et.tudelft.nl),
                  Section Computer Architecture & Digital Systems,
                  Department of Electrical Engeneering,
                  Delft University of Technology, The Netherlands
  All rights reserved*/




//C/C++
#include <stdio.h>




//xmtvg
#include "defs.h"
#include "porttvec.h"
#include "memchip.h"




//MTL interpreter declarations
#include "mtl_decl.h"




//MTL interpreter error
unsigned int mtl_error;




//MTL interpreter compute attributes data structures
char *mtla_test;
char *mtla_test_current;
char *mtla_test_sentinel;
unsigned int mtla_line_number;

unsigned int mtla_horizontal_period;
unsigned int mtla_vertical_period;
unsigned int mtla_bits_per_word;
Port_type_vector mtla_port_type_vector;




//MTL interpreter preprocessor data structures
char *mtlp_test;
char *mtlp_test_current;
char *mtlp_test_sentinel;
unsigned int mtlp_line_number;

Port_type_vector mtlp_port_type_vector;
unsigned int mtlp_all_ports;
unsigned int mtlp_current_port;

char *mtlp_reduced_test;




//MTL interpreter expansion data structures
char *mtle_test;

unsigned int mtle_updown_dirty_tag;
unsigned int mtle_northsouth_dirty_tag;
unsigned int mtle_eastwest_dirty_tag;
char *mtle_down_south_east_test = NULL;
char *mtle_up_south_east_test = NULL;
char *mtle_down_north_east_test = NULL;
char *mtle_up_north_east_test = NULL;
char *mtle_down_south_west_test = NULL;
char *mtle_up_south_west_test = NULL;
char *mtle_down_north_west_test = NULL;
char *mtle_up_north_west_test = NULL;




//MTL interpreter data structures
char *mtli_test;
char *mtli_test_current;
char *mtli_test_sentinel;
unsigned int mtli_line_number;
Memory_chip *mtli_memory_chip; //reference

unsigned int mtli_fault_found;
