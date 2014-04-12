//X Memory Test Verification and Generation
//xmtvg MTL interpreter
//
//Copyright 1994, 1995, A. Offerman (offerman@einstein.et.tudelft.nl),
//                      Ivo Schanstra (ivo@duteca.et.tudelft.nl),
//                      Section Computer Architecture & Digital Systems,
//                      Department of Electrical Engeneering,
//                      Delft University of Technology, The Netherlands
//All rights reserved




#ifndef MTL_VERF_H
#define MTL_VERF_H




void Test::mtl_compute_attributes (void);


void mtl_preprocessor (void);


void mtl_expand_test (void);


Flag Test::mtl_verify_chip (Memory_chip &memory_chip) const;




#endif //MTL_VERF_H
