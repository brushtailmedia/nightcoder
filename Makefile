APP_NAME = NightCoder
APP_BUNDLE = $(APP_NAME).app
SRC = NightCoder.swift

build:
	swiftc $(SRC) -o $(APP_NAME) \
		-framework AppKit \
		-framework CoreGraphics \
		-framework Carbon \
		-suppress-warnings

run: build
	./$(APP_NAME)

bundle: build
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp $(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/
	cp Info.plist $(APP_BUNDLE)/Contents/
	cp AppIcon.icns $(APP_BUNDLE)/Contents/Resources/

install: bundle
	cp -r $(APP_BUNDLE) /Applications/
	@echo "Installed to /Applications/$(APP_BUNDLE)"

uninstall:
	rm -rf /Applications/$(APP_BUNDLE)
	@echo "Removed /Applications/$(APP_BUNDLE)"

clean:
	rm -f $(APP_NAME)
	rm -rf $(APP_BUNDLE)

.PHONY: build run bundle install uninstall clean
