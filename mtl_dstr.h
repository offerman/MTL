/*X Memory Test Verification and Generation
  Copyright 1995, A. Offerman (offerman@einstein.et.tudelft.nl),
                  H.I. Schanstra (ivo@duteca.et.tudelft.nl),
                  Section Computer Architecture & Digital Systems,
                  Department of Electrical Engeneering,
                  Delft University of Technology, The Netherlands
  All rights reserved*/




#ifndef MTL_DSTR_H
#define MTL_DSTR_H




//MTL interpreter error
extern unsigned int mtl_error;




//MTL interpreter compute attributes data structures
extern char *mtla_test;
extern char *mtla_test_current;
extern char *mtla_test_sentinel;
extern unsigned int mtla_line_number;

extern unsigned int mtla_horizontal_period;
extern unsigned int mtla_vertical_period;
extern unsigned int mtla_bits_per_word;
extern class Port_type_vector mtla_port_type_vector;




//MTL interpreter preprocessor data structures
extern char *mtlp_test;
extern char *mtlp_test_current;
extern char *mtlp_test_sentinel;
extern unsigned int mtlp_line_number;

extern class Port_type_vector mtlp_port_type_vector;
extern unsigned int mtlp_all_ports;
extern unsigned int mtlp_current_port;

extern char *mtlp_reduced_test;




//MTL interpreter expansion data structures
extern char *mtle_test;

extern unsigned int mtle_updown_dirty_tag;
extern unsigned int mtle_northsouth_dirty_tag;
extern unsigned int mtle_eastwest_dirty_tag;
extern char *mtle_down_south_east_test;
extern char *mtle_up_south_east_test;
extern char *mtle_down_north_east_test;
extern char *mtle_up_north_east_test;
extern char *mtle_down_south_west_test;
extern char *mtle_up_south_west_test;
extern char *mtle_down_north_west_test;
extern char *mtle_up_north_west_test;




//MTL interpreter data structures
extern char *mtli_test;
extern char *mtli_test_current;
extern char *mtli_test_sentinel;
extern unsigned int mtli_line_number;
extern class Memory_chip mtli_memory_chip;

extern unsigned int mtli_fault_found;




#endif //MTL_DSTR_H
