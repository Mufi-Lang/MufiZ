# Makefile for MufiZ Analysis API Test

CC = gcc
CFLAGS = -Wall -Wextra -std=c99 -I../../zig-out/include
LDFLAGS = -L../../zig-out/lib
LIBS = -lmufiz

# Detect OS for library path
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
    # macOS
    LDFLAGS += -Wl,-rpath,@loader_path/../../zig-out/lib
    LIBS += -framework CoreFoundation
else ifeq ($(UNAME_S),Linux)
    # Linux
    LDFLAGS += -Wl,-rpath,'$$ORIGIN/../../zig-out/lib'
    LIBS += -lpthread -lm -ldl
else
    # Windows (MinGW/Cygwin)
    LIBS += -lws2_32
endif

TARGET = test_analysis
SOURCE = test_analysis.c

all: $(TARGET)

$(TARGET): $(SOURCE)
	@echo "Building $(TARGET)..."
	$(CC) $(CFLAGS) $(SOURCE) $(LDFLAGS) $(LIBS) -o $(TARGET)
	@echo "Build complete!"

run: $(TARGET)
	@echo "Running $(TARGET)..."
	@./$(TARGET)

clean:
	rm -f $(TARGET)

rebuild: clean all

.PHONY: all run clean rebuild
