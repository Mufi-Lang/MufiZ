PY = python3 
CC = clang 
debug: 
	$(PY) util/debug_prod.py debug 
	make build
release: 
	$(PY) util/debug_prod.py release 
	make build 
build: 
	$(CC) compiler/*.c -Werror -Wall -std=c99 -o mufi
clean: 
	rm mufi 