SHELL=/bin/bash -o pipefail

export GO111MODULE        := on
export PATH               := .bin:${PATH}

.PHONY: install
install:
	npm install

.PHONY: test
test:
	npm run test

.PHONY: build
build:
	npx nx run-many --target=build --all
	npx nx run-many --all --target=build-storybook -- --stats-json

.PHONY: dev
dev:
	npx nx run-many --target=dev --all

PRETTIER_VERSION=$(shell cat package.json | jq -r '.devDependencies["prettier"] // .dependencies["prettier"]')

format: .bin/ory
	.bin/ory dev headers copyright --type=open-source
	@echo "Prettier Version: $(PRETTIER_VERSION)"
	npx prettier@$(PRETTIER_VERSION) --write .

licenses: .bin/licenses node_modules  # checks open-source licenses
	.bin/licenses

.bin/licenses: Makefile
	curl https://raw.githubusercontent.com/ory/ci/master/licenses/install | sh

.bin/ory: .deps/ory.version
	curl https://raw.githubusercontent.com/ory/meta/master/install.sh | bash -s -- -b .bin ory $(cat .deps/ory.version)
	touch .bin/ory

node_modules: package-lock.json
	npm ci
	touch node_modules

build-sdk:
	(cd $$KRATOS_DIR; make sdk)
	cp $$KRATOS_DIR/spec/api.json ./contrib/sdk/api.json
	npx @openapitools/openapi-generator-cli generate -i "./contrib/sdk/api.json" \
		-g typescript-axios \
		-o "./contrib/sdk/generated" \
		--git-user-id ory \
		--git-repo-id sdk \
		--git-host github.com \
		-c ./contrib/sdk/typescript.yml
	(cd ./contrib/sdk/generated; npm i; npm run build)
	rm -rf node_modules/@ory/kratos-client/*
	cp -r ./contrib/sdk/generated/* node_modules/@ory/client
