PY = python3 

debug: 
	$(PY) util/debug_prod.py debug 
	make build
release: 
	$(PY) util/debug_prod.py release 
	make build 
build: 
	clang compiler/*.c -o mufi
clean: 
	rm mufi 