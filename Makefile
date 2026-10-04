APP_NAME = cpu-temp
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
INSTALL_DIR = $(HOME)/Applications

.PHONY: all build run install uninstall clean

all: build

build:
	@chmod +x build.sh
	@./build.sh

run: build
	@echo "Starting $(APP_NAME) in background..."
	@open $(APP_BUNDLE)

install: build
	@mkdir -p $(INSTALL_DIR)
	@echo "Installing $(APP_NAME).app to $(INSTALL_DIR)..."
	@rm -rf $(INSTALL_DIR)/$(APP_NAME).app
	@cp -R $(APP_BUNDLE) $(INSTALL_DIR)/
	@echo "Installed! You can launch $(APP_NAME) from Spotlight or $(INSTALL_DIR)."

uninstall:
	@echo "Removing $(APP_NAME).app from $(INSTALL_DIR)..."
	@rm -rf $(INSTALL_DIR)/$(APP_NAME).app
	@echo "Uninstalled successfully."

clean:
	@rm -rf $(BUILD_DIR)
	@echo "Cleaned build artifacts."
