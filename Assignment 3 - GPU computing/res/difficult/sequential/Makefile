
debug		:= 0
include		../Makefile.inc


all: clean sequential compare
 
sequential: main.cpp filters.cpp
	$(LINKER) -o $(PROJ_BASE)/bin/sequential main.cpp filters.cpp ../src/Timer.cpp $(INCLUDES) $(LIBS) $(CFLAGS) $(LDFLAGS) 

compare: compare.cpp
	$(LINKER) -o $(PROJ_BASE)/bin/compare compare.cpp $(INCLUDES) $(LIBS) $(CFLAGS) $(LDFLAGS) 

clean:
	rm -f $(PROJ_BASE)/bin/sequential
	rm -f $(PROJ_BASE)/bin/compare

