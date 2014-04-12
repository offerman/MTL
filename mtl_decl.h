/*X Memory Test Verification and Generation
  Copyright 1994, 1995, A. Offerman (offerman@einstein.et.tudelft.nl),
                        H.I. Schanstra (ivo@duteca.et.tudelft.nl),
                        Section Computer Architecture & Digital Systems,
                        Department of Electrical Engeneering,
                        Delft University of Technology, The Netherlands
  All rights reserved*/




#ifndef MTL_DECL_H
#define MTL_DECL_H




//YYSTYPE type declarations
enum mtl_Addressing_direction {mtl_up_down, mtl_down, mtl_up, mtl_north_south,
    mtl_south, mtl_north, mtl_east_west, mtl_east, mtl_west};
enum mtl_Addressing_identifier_status {mtl_undefined, mtl_row_column, mtl_row,
    mtl_column};
enum mtl_Port_type {mtl_read_port, mtl_write_port, mtl_read_write_port,
    mtl_dont_care_port};
enum mtl_Operator {mtl_plus, mtl_minus};

struct Attributes {unsigned int horizontal_period;
                  unsigned int vertical_period;
                  unsigned int bits_per_word;
                  unsigned int *port_type_vector;
                  unsigned int number_of_ports;
                  };

struct Addressing_specifier {unsigned int addressing_direction;
                            unsigned int addressing_assignment;
                            unsigned int addressing_exclusion;
                            };

struct Tile_size {unsigned int number_of_rows;
                 unsigned int number_of_columns;
                 };

struct Location {unsigned int row_offset;
                unsigned int column_offset;
                };




#endif //MTL_DECL_H
