LIB_OPTIONS = -I../Bottom -I../Tcl -I../Tk -I../Top

C = gcc
C_OPTIONS = -g    #debug

CC = g++
CC_OPTIONS = -g    #debug

LEX = flex
LEX_OPTIONS = -bdppv8
# -b  backing-up info
# -d  debug
# -f  optimize for speed
# -F  optimize for speed and size
# -i  case insensitive
# -pp  performance report
# -v  verbose
# -t  output to stdout
# -8  8 bit
# -Pprefix  overrule standard yy prefix
# -+  C++ scanner class 

YACC = bison
YACC_OPTIONS = -dtv
# -d  generate token definition header file
# -o filename  output file
# -p prefix  prefix
# -t  debug
# -v  verbose

.SUFFIXES: .o .cc .c
.c.o:
	${C} -c ${C_OPTIONS} $< ${LIB_OPTIONS}
.cc.o:
	${CC} -c ${CC_OPTIONS} $< ${LIB_OPTIONS}

interpreter: mtla_lex.o mtla_prs.o mtlp_lex.o mtlp_prs.o mtli_lex.o \
             mtli_prs.o mtl_dstr.o mtl_verf.o
mtla_lex.o: mtla_lex.cc mtla.h mtl_decl.h mtl_dstr.h
mtla_lex.cc: mtla_lex.l
	${LEX} ${LEX_OPTIONS} -Pmtla -t mtla_lex.l >mtla_lex.cc
mtla.h: mtla_prs.y
	${YACC} ${YACC_OPTIONS} -p mtla mtla_prs.y -o mtla_prs.cc
	mv mtla_prs.cc.h mtla.h
mtla_prs.o: mtla_prs.cc mtl_decl.h ../Bottom/defs.h ../Bottom/porttvec.h \
            mtl_dstr.h  ../Top/mess_il.h
mtla_prs.cc: mtla_prs.y
	${YACC} ${YACC_OPTIONS} -p mtla mtla_prs.y -o mtla_prs.cc
	mv mtla_prs.cc.h mtla.h
mtlp_lex.o: mtlp_lex.cc mtlp.h mtl_decl.h mtl_dstr.h
mtlp_lex.cc: mtlp_lex.l
	${LEX} ${LEX_OPTIONS} -Pmtlp -t mtlp_lex.l >mtlp_lex.cc
mtlp.h: mtlp_prs.y
	${YACC} ${YACC_OPTIONS} -p mtlp mtlp_prs.y -o mtlp_prs.cc
	mv mtlp_prs.cc.h mtlp.h
mtlp_prs.o: mtlp_prs.cc mtl_decl.h mtl_dstr.h ../Bottom/defs.h \
            ../Bottom/porttvec.h
mtlp_prs.cc: mtlp_prs.y
	${YACC} ${YACC_OPTIONS} -p mtlp mtlp_prs.y -o mtlp_prs.cc
	mv mtlp_prs.cc.h mtlp.h
mtli_lex.o: mtli_lex.cc mtli.h mtl_decl.h mtl_dstr.h
mtli_lex.cc: mtli_lex.l
	${LEX} ${LEX_OPTIONS} -Pmtli -t mtli_lex.l >mtli_lex.cc
mtli.h: mtli_prs.y
	${YACC} ${YACC_OPTIONS} -p mtli mtli_prs.y -o mtli_prs.cc
	mv mtli_prs.cc.h mtli.h
mtli_prs.o: mtli_prs.cc mtl_decl.h mtl_dstr.h ../Top/datastr.h \
            ../Bottom/memchip.h ../Bottom/memtype.h
mtli_prs.cc: mtli_prs.y
	${YACC} ${YACC_OPTIONS} -p mtli mtli_prs.y -o mtli_prs.cc
	mv mtli_prs.cc.h mtli.h
mtl_dstr.o: mtl_dstr.cc ../Bottom/defs.h ../Bottom/porttvec.h \
            ../Bottom/memchip.h mtl_decl.h
mtl_verf.o: ../Top/mess_il.h mtl_verf.cc ../Bottom/test.h mtl_decl.h \
            mtl_dstr.h ../Top/datastr.h

clean:
	rm -f mtla.h mtla_lex.cc mtla_prs.cc mtlp.h mtlp_lex.cc mtlp_prs.cc \
        mtli.h mtli_lex.cc mtli_prs.cc *.o *.backup *.output
