//X Memory Test Verification and Generation
//xmtvg MTL interpreter
//
//Copyright 1994, 1995, A. Offerman (offerman@einstein.et.tudelft.nl),
//                      Ivo Schanstra (ivo@duteca.et.tudelft.nl),
//                      Section Computer Architecture & Digital Systems,
//                      Department of Electrical Engeneering,
//                      Delft University of Technology, The Netherlands
//All rights reserved




//C/C++
#include <assert.h>
extern "C" {
  #include <string.h>
  }




//Tcl/Tk
extern "C" {
  #include "tcl.h"
  #include "tk.h"
  }




//xmtvg
#include "mess_il.h"
#include "test.h"
#include "mtl_decl.h"
#include "mtl_dstr.h"
#include "datastr.h"




//MTL interpreters
extern "C" {
  #include <stdio.h>
  }
void mtlarestart (FILE *);
int mtlaparse (void);
void mtlprestart (FILE *);
int mtlpparse (void);
void mtlirestart (FILE *);
int mtliparse (void);




void Test::mtl_compute_attributes (void) {
  mtla_test = algorithm;
  mtla_test_current = mtla_test;
  mtla_test_sentinel = mtla_test;
  while (*mtla_test_sentinel != '\0') {
    mtla_test_sentinel++;
    }
  mtla_line_number = 1;
  mtla_horizontal_period = 1;
  mtla_vertical_period = 1;
  mtla_bits_per_word = 1;
  while (mtla_port_type_vector.size () != 0) {
    mtla_port_type_vector.extract (0);
    }
  mtlarestart (NULL); //reset lexer
  mtlaparse ();
  horizontal_margin = mtla_horizontal_period - 1;
  vertical_margin = mtla_vertical_period - 1;
  word_width = mtla_bits_per_word;
  }


void mtl_preprocessor (void) {
  mtlp_test = current_test.algorithm;
  mtlp_test_current = mtlp_test;
  mtlp_test_sentinel = mtlp_test;
  while (*mtlp_test_sentinel != '\0') {
    mtlp_test_sentinel++;
    }
  mtlp_line_number = 1;
  while (mtlp_port_type_vector.size () != 0) {
    mtlp_port_type_vector.extract (0);
    }
  mtlp_all_ports = 0;
  mtlp_current_port = 0;
  mtlprestart (NULL); //reset lexer
  mtlpparse ();
  if (mtlp_port_type_vector.size () == 0) {
    current_test.port_type_vector = mtla_port_type_vector;
    }
  else {
    if (mtla_port_type_vector.size () == mtlp_port_type_vector.size ()) {
      for (int i = 0; i < mtlp_port_type_vector.size (); i++) {
        if (mtlp_port_type_vector.read (i) == read_port &&
            (mtla_port_type_vector.read (i) == write_port ||
            mtla_port_type_vector.read (i) == read_write_port) ||
            mtlp_port_type_vector.read (i) == write_port &&
            (mtla_port_type_vector.read (i) == read_port ||
            mtla_port_type_vector.read (i) == read_write_port)) {
          xmtvg_error_report ("MTL preprocessor error: port specification "
              "does not match test algorithm");
          mtl_error = 1;
          return;
          }
        if (mtlp_port_type_vector.read (i) == dont_care_port) {
          mtlp_port_type_vector.write (i, mtla_port_type_vector.read (i));
          }
        }
      current_test.port_type_vector = mtlp_port_type_vector;
      }
    else {
      xmtvg_error_report ("MTL preprocessor error: port specification does "
          "not match test algorithm");
      mtl_error = 1;
      return;
      }
    }
  if (mtlp_all_ports && current_test.port_type_vector.size () != 1) {
    xmtvg_error_report ("MTL preprocessor error: port specification does not "
        "match test algorithm");
    mtl_error = 1;
    return;
    }
  mtlp_reduced_test = mtlp_test;
  while (*mtlp_reduced_test != '{' && *mtlp_reduced_test != '\0') {
    mtlp_reduced_test++;
    }
  }


void mtl_expand_test (void) {
  mtle_test = mtlp_reduced_test;
  mtle_updown_dirty_tag = 0;
  mtle_northsouth_dirty_tag = 0;
  mtle_eastwest_dirty_tag = 0;
  delete [] mtle_down_south_east_test;
  mtle_down_south_east_test = new char [strlen (mtle_test) + 1];
  assert (mtle_down_south_east_test != NULL); //memory exhausted
  strcpy (mtle_down_south_east_test, mtle_test);
  char *tmp_mtle_test_pointer = mtle_down_south_east_test;
  while (*tmp_mtle_test_pointer != '\0') {
    if (strncmp (tmp_mtle_test_pointer, "updown", 6) == 0) {
      strncpy (tmp_mtle_test_pointer, "down  ", 6);
      tmp_mtle_test_pointer += 6 - 1;
      mtle_updown_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "UPDOWN", 6) == 0) {
      strncpy (tmp_mtle_test_pointer, "DOWN  ", 6);
      tmp_mtle_test_pointer += 6 - 1;
      mtle_updown_dirty_tag = 1;
      }
    else if (*tmp_mtle_test_pointer == '\xCA') {
      *tmp_mtle_test_pointer == '\xC8';
      mtle_updown_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "northsouth", 10) == 0) {
      strncpy (tmp_mtle_test_pointer, "south     ", 10);
      tmp_mtle_test_pointer += 10 - 1;
      mtle_northsouth_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "NORTSOUTH", 10) == 0) {
      strncpy (tmp_mtle_test_pointer, "SOUTH     ", 10);
      tmp_mtle_test_pointer += 10 - 1;
      mtle_northsouth_dirty_tag = 1;
      }
    else if (*tmp_mtle_test_pointer == '\xCD') {   
      *tmp_mtle_test_pointer == '\xCB';
      mtle_northsouth_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "eastwest", 8) == 0) {
      strncpy (tmp_mtle_test_pointer, "east    ", 8);
      tmp_mtle_test_pointer += 8 - 1;
      mtle_eastwest_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "EASTWEST", 10) == 0) {
      strncpy (tmp_mtle_test_pointer, "EAST    ", 8);
      tmp_mtle_test_pointer += 8 - 1;
      mtle_eastwest_dirty_tag = 1;
      }
    else if (*tmp_mtle_test_pointer == '\xD0') {
      *tmp_mtle_test_pointer == '\xCE';
      mtle_eastwest_dirty_tag = 1;
      }
    tmp_mtle_test_pointer++;
    }
  delete [] mtle_up_south_east_test;
  mtle_up_south_east_test = new char [strlen (mtle_test) + 1];
  assert (mtle_up_south_east_test != NULL); //memory exhausted
  strcpy (mtle_up_south_east_test, mtle_test);
  tmp_mtle_test_pointer = mtle_up_south_east_test;
  while (*tmp_mtle_test_pointer != '\0') {
    if (strncmp (tmp_mtle_test_pointer, "updown", 6) == 0) {
      strncpy (tmp_mtle_test_pointer, "up    ", 6);
      tmp_mtle_test_pointer += 6 - 1;
      mtle_updown_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "UPDOWN", 6) == 0) {
      strncpy (tmp_mtle_test_pointer, "UP    ", 6);
      tmp_mtle_test_pointer += 6 - 1;
      mtle_updown_dirty_tag = 1;
      }
    else if (*tmp_mtle_test_pointer == '\xCA') {   
      *tmp_mtle_test_pointer == '\xC9';
      mtle_updown_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "northsouth", 10) == 0) {
      strncpy (tmp_mtle_test_pointer, "south     ", 10);
      tmp_mtle_test_pointer += 10 - 1;
      mtle_northsouth_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "NORTSOUTH", 10) == 0) {
      strncpy (tmp_mtle_test_pointer, "SOUTH     ", 10);
      tmp_mtle_test_pointer += 10 - 1;
      mtle_northsouth_dirty_tag = 1;
      }
    else if (*tmp_mtle_test_pointer == '\xCD') {
      *tmp_mtle_test_pointer == '\xCB';
      mtle_northsouth_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "eastwest", 8) == 0) {   
      strncpy (tmp_mtle_test_pointer, "east    ", 8);   
      tmp_mtle_test_pointer += 8 - 1; 
      mtle_eastwest_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "EASTWEST", 10) == 0) { 
      strncpy (tmp_mtle_test_pointer, "EAST    ", 8);   
      tmp_mtle_test_pointer += 8 - 1; 
      mtle_eastwest_dirty_tag = 1;
      }
    else if (*tmp_mtle_test_pointer == '\xD0') {
      *tmp_mtle_test_pointer == '\xCE';
      mtle_eastwest_dirty_tag = 1;
      }
    tmp_mtle_test_pointer++;
    }
  delete [] mtle_down_north_east_test;
  mtle_down_north_east_test = new char [strlen (mtle_test) + 1];
  assert (mtle_down_north_east_test != NULL); //memory exhausted
  strcpy (mtle_down_north_east_test, mtle_test);
  tmp_mtle_test_pointer = mtle_down_north_east_test;
  while (*tmp_mtle_test_pointer != '\0') {
    if (strncmp (tmp_mtle_test_pointer, "updown", 6) == 0) {
      strncpy (tmp_mtle_test_pointer, "down  ", 6);
      tmp_mtle_test_pointer += 6 - 1;
      mtle_updown_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "UPDOWN", 6) == 0) {
      strncpy (tmp_mtle_test_pointer, "DOWN  ", 6);
      tmp_mtle_test_pointer += 6 - 1;
      mtle_updown_dirty_tag = 1;
      }
    else if (*tmp_mtle_test_pointer == '\xCA') {
      *tmp_mtle_test_pointer == '\xC8';
      mtle_updown_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "northsouth", 10) == 0) {
      strncpy (tmp_mtle_test_pointer, "north     ", 10);
      tmp_mtle_test_pointer += 10 - 1;
      mtle_northsouth_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "NORTSOUTH", 10) == 0) {
      strncpy (tmp_mtle_test_pointer, "NORTH     ", 10);
      tmp_mtle_test_pointer += 10 - 1;
      mtle_northsouth_dirty_tag = 1;
      }
    else if (*tmp_mtle_test_pointer == '\xCD') {   
      *tmp_mtle_test_pointer == '\xCC';
      mtle_northsouth_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "eastwest", 8) == 0) {
      strncpy (tmp_mtle_test_pointer, "east    ", 8);
      tmp_mtle_test_pointer += 8 - 1;
      mtle_eastwest_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "EASTWEST", 10) == 0) {
      strncpy (tmp_mtle_test_pointer, "EAST    ", 8);
      tmp_mtle_test_pointer += 8 - 1;
      mtle_eastwest_dirty_tag = 1;
      }
    else if (*tmp_mtle_test_pointer == '\xD0') {
      *tmp_mtle_test_pointer == '\xCE';
      mtle_eastwest_dirty_tag = 1;
      }
    tmp_mtle_test_pointer++;
    }
  delete [] mtle_up_north_east_test;
  mtle_up_north_east_test = new char [strlen (mtle_test) + 1];
  assert (mtle_up_north_east_test != NULL); // memory exhausted
  strcpy (mtle_up_north_east_test, mtle_test);
  tmp_mtle_test_pointer = mtle_up_north_east_test;
  while (*tmp_mtle_test_pointer != '\0') {
    if (strncmp (tmp_mtle_test_pointer, "updown", 6) == 0) {
      strncpy (tmp_mtle_test_pointer, "up    ", 6);
      tmp_mtle_test_pointer += 6 - 1;
      mtle_updown_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "UPDOWN", 6) == 0) {
      strncpy (tmp_mtle_test_pointer, "UP    ", 6);
      tmp_mtle_test_pointer += 6 - 1;
      mtle_updown_dirty_tag = 1;
      }
    else if (*tmp_mtle_test_pointer == '\xCA') {
      *tmp_mtle_test_pointer == '\xC9';
      mtle_updown_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "northsouth", 10) == 0) {
      strncpy (tmp_mtle_test_pointer, "north     ", 10);
      tmp_mtle_test_pointer += 10 - 1;
      mtle_northsouth_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "NORTSOUTH", 10) == 0) {
      strncpy (tmp_mtle_test_pointer, "NORTH     ", 10);
      tmp_mtle_test_pointer += 10 - 1;
      mtle_northsouth_dirty_tag = 1;
      }
    else if (*tmp_mtle_test_pointer == '\xCD') {
      *tmp_mtle_test_pointer == '\xCC';
      mtle_northsouth_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "eastwest", 8) == 0) {
      strncpy (tmp_mtle_test_pointer, "east    ", 8);
      tmp_mtle_test_pointer += 8 - 1;
      mtle_eastwest_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "EASTWEST", 10) == 0) {
      strncpy (tmp_mtle_test_pointer, "EAST    ", 8);
      tmp_mtle_test_pointer += 8 - 1;
      mtle_eastwest_dirty_tag = 1;
      }
    else if (*tmp_mtle_test_pointer == '\xD0') {
      *tmp_mtle_test_pointer == '\xCE';
      mtle_eastwest_dirty_tag = 1;
      }
    tmp_mtle_test_pointer++;
    }
  delete [] mtle_down_south_west_test;
  mtle_down_south_west_test = new char [strlen (mtle_test) + 1];
  assert (mtle_down_south_west_test != NULL); //memory exhausted
  strcpy (mtle_down_south_west_test, mtle_test);
  tmp_mtle_test_pointer = mtle_down_south_west_test;
  while (*tmp_mtle_test_pointer != '\0') {
    if (strncmp (tmp_mtle_test_pointer, "updown", 6) == 0) {
      strncpy (tmp_mtle_test_pointer, "down  ", 6);
      tmp_mtle_test_pointer += 6 - 1;
      mtle_updown_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "UPDOWN", 6) == 0) {
      strncpy (tmp_mtle_test_pointer, "DOWN  ", 6);
      tmp_mtle_test_pointer += 6 - 1;
      mtle_updown_dirty_tag = 1;
      }
    else if (*tmp_mtle_test_pointer == '\xCA') {
      *tmp_mtle_test_pointer == '\xC8';
      mtle_updown_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "northsouth", 10) == 0) {
      strncpy (tmp_mtle_test_pointer, "south     ", 10);
      tmp_mtle_test_pointer += 10 - 1;
      mtle_northsouth_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "NORTSOUTH", 10) == 0) {
      strncpy (tmp_mtle_test_pointer, "SOUTH     ", 10);
      tmp_mtle_test_pointer += 10 - 1;
      mtle_northsouth_dirty_tag = 1;
      }
    else if (*tmp_mtle_test_pointer == '\xCD') {   
      *tmp_mtle_test_pointer == '\xCB';
      mtle_northsouth_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "eastwest", 8) == 0) {
      strncpy (tmp_mtle_test_pointer, "west    ", 8);
      tmp_mtle_test_pointer += 8 - 1;
      mtle_eastwest_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "EASTWEST", 10) == 0) {
      strncpy (tmp_mtle_test_pointer, "WEST    ", 8);
      tmp_mtle_test_pointer += 8 - 1;
      mtle_eastwest_dirty_tag = 1;
      }
    else if (*tmp_mtle_test_pointer == '\xD0') {
      *tmp_mtle_test_pointer == '\xCF';
      mtle_eastwest_dirty_tag = 1;
      }
    tmp_mtle_test_pointer++;
    }
  delete [] mtle_up_south_west_test;
  mtle_up_south_west_test = new char [strlen (mtle_test) + 1];
  assert (mtle_up_south_west_test != NULL); //memory exhausted
  strcpy (mtle_up_south_west_test, mtle_test);
  tmp_mtle_test_pointer = mtle_up_south_west_test;
  while (*tmp_mtle_test_pointer != '\0') {
    if (strncmp (tmp_mtle_test_pointer, "updown", 6) == 0) {
      strncpy (tmp_mtle_test_pointer, "up    ", 6);
      tmp_mtle_test_pointer += 6 - 1;
      mtle_updown_dirty_tag = 1;
      }                             
    else if (strncmp (tmp_mtle_test_pointer, "UPDOWN", 6) == 0) {
      strncpy (tmp_mtle_test_pointer, "UP    ", 6);
      tmp_mtle_test_pointer += 6 - 1;
      mtle_updown_dirty_tag = 1;
      }
    else if (*tmp_mtle_test_pointer == '\xCA') {
      *tmp_mtle_test_pointer == '\xC9';
      mtle_updown_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "northsouth", 10) == 0) {
      strncpy (tmp_mtle_test_pointer, "south     ", 10);
      tmp_mtle_test_pointer += 10 - 1;
      mtle_northsouth_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "NORTSOUTH", 10) == 0) {
      strncpy (tmp_mtle_test_pointer, "SOUTH     ", 10);
      tmp_mtle_test_pointer += 10 - 1;
      mtle_northsouth_dirty_tag = 1;
      }
    else if (*tmp_mtle_test_pointer == '\xCD') {
      *tmp_mtle_test_pointer == '\xCB';
      mtle_northsouth_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "eastwest", 8) == 0) {
      strncpy (tmp_mtle_test_pointer, "west    ", 8);
      tmp_mtle_test_pointer += 8 - 1;
      mtle_eastwest_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "EASTWEST", 10) == 0) {
      strncpy (tmp_mtle_test_pointer, "WEST    ", 8);
      tmp_mtle_test_pointer += 8 - 1;
      mtle_eastwest_dirty_tag = 1;
      }
    else if (*tmp_mtle_test_pointer == '\xD0') {
      *tmp_mtle_test_pointer == '\xCF';
      mtle_eastwest_dirty_tag = 1;
      }
    tmp_mtle_test_pointer++;
    }
  delete [] mtle_down_north_west_test;
  mtle_down_north_west_test = new char [strlen (mtle_test) + 1];
  assert (mtle_down_north_west_test != NULL); //memory exhausted
  strcpy (mtle_down_north_west_test, mtle_test);
  tmp_mtle_test_pointer = mtle_down_north_west_test;
  while (*tmp_mtle_test_pointer != '\0') {
    if (strncmp (tmp_mtle_test_pointer, "updown", 6) == 0) {
      strncpy (tmp_mtle_test_pointer, "down  ", 6);
      tmp_mtle_test_pointer += 6 - 1;
      mtle_updown_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "UPDOWN", 6) == 0) {
      strncpy (tmp_mtle_test_pointer, "DOWN  ", 6);
      tmp_mtle_test_pointer += 6 - 1;
      mtle_updown_dirty_tag = 1;
      }
    else if (*tmp_mtle_test_pointer == '\xCA') {
      *tmp_mtle_test_pointer == '\xC8';
      mtle_updown_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "northsouth", 10) == 0) {
      strncpy (tmp_mtle_test_pointer, "north     ", 10);
      tmp_mtle_test_pointer += 10 - 1;
      mtle_northsouth_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "NORTSOUTH", 10) == 0) {
      strncpy (tmp_mtle_test_pointer, "NORTH     ", 10);
      tmp_mtle_test_pointer += 10 - 1;
      mtle_northsouth_dirty_tag = 1;
      }
    else if (*tmp_mtle_test_pointer == '\xCC') {
      *tmp_mtle_test_pointer == '\xCB';
      mtle_northsouth_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "eastwest", 8) == 0) {
      strncpy (tmp_mtle_test_pointer, "west    ", 8);
      tmp_mtle_test_pointer += 8 - 1;
      mtle_eastwest_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "EASTWEST", 10) == 0) {
      strncpy (tmp_mtle_test_pointer, "WEST    ", 8);
      tmp_mtle_test_pointer += 8 - 1;
      mtle_eastwest_dirty_tag = 1;
      }
    else if (*tmp_mtle_test_pointer == '\xD0') {
      *tmp_mtle_test_pointer == '\xCF';
      mtle_eastwest_dirty_tag = 1;
      }
    tmp_mtle_test_pointer++;
    }
  delete [] mtle_up_north_west_test;
  mtle_up_north_west_test = new char [strlen (mtle_test) + 1];
  assert (mtle_up_north_west_test != NULL); //memory exhausted
  strcpy (mtle_up_north_west_test, mtle_test);
  tmp_mtle_test_pointer = mtle_up_north_west_test;
  while (*tmp_mtle_test_pointer != '\0') {
    if (strncmp (tmp_mtle_test_pointer, "updown", 6) == 0) {
      strncpy (tmp_mtle_test_pointer, "up    ", 6);
      tmp_mtle_test_pointer += 6 - 1;
      mtle_updown_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "UPDOWN", 6) == 0) {
      strncpy (tmp_mtle_test_pointer, "UP    ", 6);
      tmp_mtle_test_pointer += 6 - 1;
      mtle_updown_dirty_tag = 1;
      }
    else if (*tmp_mtle_test_pointer == '\xCA') {
      *tmp_mtle_test_pointer == '\xC9';
      mtle_updown_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "northsouth", 10) == 0) {
      strncpy (tmp_mtle_test_pointer, "north     ", 10);
      tmp_mtle_test_pointer += 10 - 1;
      mtle_northsouth_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "NORTSOUTH", 10) == 0) {
      strncpy (tmp_mtle_test_pointer, "NORTH     ", 10);
      tmp_mtle_test_pointer += 10 - 1;
      mtle_northsouth_dirty_tag = 1;
      }
    else if (*tmp_mtle_test_pointer == '\xCC') {
      *tmp_mtle_test_pointer == '\xCB';
      mtle_northsouth_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "eastwest", 8) == 0) {
      strncpy (tmp_mtle_test_pointer, "west    ", 8);
      tmp_mtle_test_pointer += 8 - 1;
      mtle_eastwest_dirty_tag = 1;
      }
    else if (strncmp (tmp_mtle_test_pointer, "EASTWEST", 10) == 0) {
      strncpy (tmp_mtle_test_pointer, "WEST    ", 8);
      tmp_mtle_test_pointer += 8 - 1;
      mtle_eastwest_dirty_tag = 1;
      }
    else if (*tmp_mtle_test_pointer == '\xD0') {
      *tmp_mtle_test_pointer == '\xCF';
      mtle_eastwest_dirty_tag = 1;
      }
    tmp_mtle_test_pointer++;
    }
  }


Flag Test::mtl_verify_chip (Memory_chip &memory_chip) const {
  mtli_fault_found = 1;
  mtli_test = mtle_down_south_east_test;
  mtli_test_current = mtli_test;
  mtli_test_sentinel = mtli_test;
  while (*mtli_test_sentinel != '\0') {
    mtli_test_sentinel++;
    }
  mtlirestart (NULL); //reset lexer
  mtli_line_number = 1;
  mtli_memory_chip = memory_chip;
  mtli_memory_chip.reset ();
  mtliparse ();
  if (mtli_fault_found == 0 || mtl_error) {
    return 0;
    }
  if (mtle_updown_dirty_tag) {
    mtli_test = mtle_up_south_east_test;
    mtli_test_current = mtli_test;
    mtli_test_sentinel = mtli_test;
    while (*mtli_test_sentinel != '\0') {
      mtli_test_sentinel++;
      }
    mtlirestart (NULL); //reset lexer
    mtli_line_number = 1;
    mtli_memory_chip.reset ();
    mtliparse ();
    if (mtli_fault_found == 0 || mtl_error) {
      return 0;
      }
    }
  if (mtle_northsouth_dirty_tag) {
    mtli_test = mtle_down_north_east_test;
    mtli_test_current = mtli_test;
    mtli_test_sentinel = mtli_test;
    while (*mtli_test_sentinel != '\0') {
      mtli_test_sentinel++;
      }
    mtlirestart (NULL); //lexer reset
    mtli_line_number = 1;
    mtli_memory_chip.reset ();
    mtliparse ();
    if (mtli_fault_found == 0 || mtl_error) {
      return 0;
      }
    if (mtle_updown_dirty_tag) {
      mtli_test = mtle_up_north_east_test;
      mtli_test_current = mtli_test;
      mtli_test_sentinel = mtli_test;
      while (*mtli_test_sentinel != '\0') {
        mtli_test_sentinel++;
        }
      mtlirestart (NULL); //reset lexer
      mtli_line_number = 1;
      mtli_memory_chip.reset ();
      mtliparse ();
      if (mtli_fault_found == 0 || mtl_error) {
        return 0;
        }
      }
    }
  if (mtle_eastwest_dirty_tag) {
    mtli_test = mtle_down_south_west_test;
    mtli_test_current = mtli_test;
    mtli_test_sentinel = mtli_test;
    while (*mtli_test_sentinel != '\0') {
      mtli_test_sentinel++;
      }
    mtlirestart (NULL); //reset lexer
    mtli_line_number = 1;
    mtli_memory_chip.reset ();
    mtliparse ();
    if (mtli_fault_found == 0 || mtl_error) {
      return 0;
      }
    if (mtle_updown_dirty_tag) {
      mtli_test = mtle_up_south_west_test;
      mtli_test_current = mtli_test;
      mtli_test_sentinel = mtli_test;
      while (*mtli_test_sentinel != '\0') {
        mtli_test_sentinel++;
        }
      mtlirestart (NULL); //reset lexer
      mtli_line_number = 1;
      mtli_memory_chip.reset ();
      mtliparse ();
      if (mtli_fault_found == 0 || mtl_error) {
        return 0;
        }
      }
    if (mtle_northsouth_dirty_tag) {
      mtli_test = mtle_down_north_west_test;
      mtli_test_current = mtli_test;
      mtli_test_sentinel = mtli_test;
      while (*mtli_test_sentinel != '\0') {
        mtli_test_sentinel++;
        }
      mtlirestart (NULL); //reset lexer
      mtli_line_number = 1;
      mtli_memory_chip.reset ();
      mtliparse ();
      if (mtli_fault_found == 0 || mtl_error) {
        return 0;
        }
      if (mtle_updown_dirty_tag) {
        mtli_test = mtle_up_north_west_test;
        mtli_test_current = mtli_test;
        mtli_test_sentinel = mtli_test;
        while (*mtli_test_sentinel != '\0') {
          mtli_test_sentinel++;
          }
        mtlirestart (NULL); //reset lexer
        mtli_line_number = 1;
        mtli_memory_chip.reset ();
        mtliparse ();
        if (mtli_fault_found == 0 || mtl_error) {
          return 0;
          }
        }
      }
    }
  extern Tcl_Interp *tcl_interpreter;
  if (Tcl_Eval (tcl_interpreter,
      "incr v_verify_for_completeness_memory_chip_counter") != TCL_OK) {
    Tcl_AddErrorInfo (tcl_interpreter, "error while incrementing "
        "v_verify_for_completeness_memory_chip_counter in mtl_verify_chip");
    }
  return 1;
  }
