UNAME=$(shell uname -s | tr "[:upper:]" "[:lower:]")
VER=$(shell json -f package.json version)

node_modules: package.json
	npm install --production
	@touch node_modules

.PHONY: release github-release
release: thoth-$(UNAME)-$(VER).tar.gz

publish: release
	./tools/publish.sh "$(VER)"

thoth-$(UNAME)-$(VER).tar.gz:
	./tools/build-release.sh

clean:
	rm -rf node_modules opt
	rm -f thoth-$(UNAME)-$(VER).tar.gz
