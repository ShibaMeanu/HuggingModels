APP_NAME = HuggingModels
BUNDLE_ID = com.example.HuggingModels
SWIFT_FILES = $(wildcard Sources/*.swift)
BUILD_DIR = build
APP_DIR = $(BUILD_DIR)/$(APP_NAME).app

all: clean build

build:
	mkdir -p $(APP_DIR)/Contents/MacOS
	mkdir -p $(APP_DIR)/Contents/Resources
	swiftc $(SWIFT_FILES) -o $(APP_DIR)/Contents/MacOS/$(APP_NAME) -target arm64-apple-macosx13.0
	cp Info.plist $(APP_DIR)/Contents/
	cp AppIcon.icns $(APP_DIR)/Contents/Resources/
	@echo "Build complete. App is located at $(APP_DIR)"

clean:
	rm -rf $(BUILD_DIR)

install: build
	cp -R $(APP_DIR) /Applications/
	@echo "Installed $(APP_NAME) to /Applications/$(APP_NAME).app"

run: build
	open $(APP_DIR)
