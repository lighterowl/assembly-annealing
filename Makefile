NASMFLAGS=-f elf64 -F dwarf -g -Wall
CFLAGS=-Wall -Wextra -g
OBJS=annealing.o example.o
OUTPUT=annealing

$(OUTPUT) : $(OBJS)
	$(CC) $(CFLAGS) -o $@ $^

example.o : example.c annealing.h

annealing.o : annealing.asm
	nasm $(NASMFLAGS) -o $@ annealing.asm

clean :
	rm -f $(OBJS) $(OUTPUT)

.PHONY : clean
