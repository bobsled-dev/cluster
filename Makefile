VERSION ?= $(if $(shell git describe --tags),$(shell git describe --tags),UnknownVersion)
RKE2_VERSION = v1.28.2+rke2r1

.PHONY: help h
h: help
help: ## Display this help information
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | sort | awk 'BEGIN {FS = ":.*?## "}; \
	  {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

download-rke2: ## Download the RKE2 images and script
	scripts/get-rke2-artifacts.sh $(RKE2_VERSION)

build: download-rke2 ## Build the Cluster Package
	cp scripts/rke2-install.sh build/
	cp local-path-storage/local-path-storage.yaml build/
	mkdir -p tmp
	tar -cf tmp/cluster-package-$(VERSION).tar.gz -C build .
	rm -rf build/*
	mv tmp/cluster-package-$(VERSION).tar.gz build/
	rm -rf tmp

clean: ## Clean up the build artifacts
	rm -rf build tmp

release: ## Create a release of the Cluster Package
	gh release create --generate-notes