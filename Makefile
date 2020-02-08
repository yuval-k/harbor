# Makefile for Harbor project
#
# Targets:
#
# all:			prepare env, compile binaries, build images and install images
# prepare: 		prepare env
# compile: 		compile core and jobservice code
#
# compile_golangimage:
#			compile from golang image
#			for example: make compile_golangimage -e GOBUILDIMAGE= \
#							golang:1.13.4
# compile_core, compile_jobservice: compile specific binary
#
# build:	build Harbor docker images from photon baseimage
#
# install:		include compile binarys, build images, prepare specific \
#				version composefile and startup Harbor instance
#
# start:		startup Harbor instance
#
# down:			shutdown Harbor instance
#
# package_online:
#				prepare online install package
#			for example: make package_online -e DEVFLAG=false\
#							REGISTRYSERVER=reg-bj.goharbor.io \
#							REGISTRYPROJECTNAME=harborrelease
#
# package_offline:
#				prepare offline install package
#
# pushimage:	push Harbor images to specific registry server
#			for example: make pushimage -e DEVFLAG=false REGISTRYUSER=admin \
#							REGISTRYPASSWORD=***** \
#							REGISTRYSERVER=reg-bj.goharbor.io/ \
#							REGISTRYPROJECTNAME=harborrelease
#				note**: need add "/" on end of REGISTRYSERVER. If not setting \
#						this value will push images directly to dockerhub.
#						 make pushimage -e DEVFLAG=false REGISTRYUSER=goharbor \
#							REGISTRYPASSWORD=***** \
#							REGISTRYPROJECTNAME=goharbor
#
# clean:        remove binary, Harbor images, specific version docker-compose \
#               file, specific version tag and online/offline install package
# cleanbinary:	remove core and jobservice binary
# cleanimage: 	remove Harbor images
# cleandockercomposefile:
#				remove specific version docker-compose
# cleanversiontag:
#				cleanpackageremove specific version tag
# cleanpackage: remove online/offline install package
#
# other example:
#	clean specific version binarys and images:
#				make clean -e VERSIONTAG=[TAG]
#				note**: If commit new code to github, the git commit TAG will \
#				change. Better use this commond clean previous images and \
#				files with specific TAG.
#   By default DEVFLAG=true, if you want to release new version of Harbor, \
#		should setting the flag to false.
#				make XXXX -e DEVFLAG=false

SHELL := /bin/bash
BUILDPATH=$(CURDIR)
MAKEPATH=$(BUILDPATH)/make
MAKE_PREPARE_PATH=$(MAKEPATH)/photon/prepare
SRCPATH=./src
TOOLSPATH=$(BUILDPATH)/tools
CORE_PATH=$(BUILDPATH)/src/core
PORTAL_PATH=$(BUILDPATH)/src/portal
CHECKENVCMD=checkenv.sh

# parameters
REGISTRYSERVER=
REGISTRYPROJECTNAME=goharbor
DEVFLAG=true
NOTARYFLAG=false
CLAIRFLAG=false
HTTPPROXY=
BUILDBIN=false
MIGRATORFLAG=false
NPM_REGISTRY=https://registry.npmjs.org
# enable/disable chart repo supporting
CHARTFLAG=false
BUILDTARGET=build

# version prepare
# for docker image tag
VERSIONTAG=dev
# for base docker image tag
BASEIMAGETAG=dev
# for harbor package name
PKGVERSIONTAG=dev

PREPARE_VERSION_NAME=versions

#versions
REGISTRYVERSION=v2.7.1-patch-2819-2553
NGINXVERSION=$(VERSIONTAG)
NOTARYVERSION=v0.6.1
CLAIRVERSION=v2.1.1
MIGRATORVERSION=$(VERSIONTAG)
REDISVERSION=$(VERSIONTAG)
NOTARYMIGRATEVERSION=v3.5.4
CLAIRADAPTERVERSION=v1.0.1

# version of chartmuseum
CHARTMUSEUMVERSION=v0.9.0

# version of registry for pulling the source code
REGISTRY_SRC_TAG=v2.7.1

define VERSIONS_FOR_PREPARE
VERSION_TAG: $(VERSIONTAG)
REGISTRY_VERSION: $(REGISTRYVERSION)
NOTARY_VERSION: $(NOTARYVERSION)
CLAIR_VERSION: $(CLAIRVERSION)
CLAIR_ADAPTER_VERSION: $(CLAIRADAPTERVERSION)
CHARTMUSEUM_VERSION: $(CHARTMUSEUMVERSION)
endef

# docker parameters
DOCKERCMD=$(shell which docker)
DOCKERBUILD=$(DOCKERCMD) build
DOCKERRMIMAGE=$(DOCKERCMD) rmi
DOCKERPULL=$(DOCKERCMD) pull
DOCKERIMASES=$(DOCKERCMD) images
DOCKERSAVE=$(DOCKERCMD) save
DOCKERCOMPOSECMD=$(shell which docker-compose)
DOCKERTAG=$(DOCKERCMD) tag

# go parameters
GOCMD=$(shell which go)
GOBUILD=$(GOCMD) build
GOCLEAN=$(GOCMD) clean
GOINSTALL=$(GOCMD) install
GOTEST=$(GOCMD) test
GODEP=$(GOTEST) -i
GOFMT=gofmt -w
GOBUILDIMAGE=golang:1.13.4
GOBUILDPATHINCONTAINER=/harbor

# go build
PKG_PATH=github.com/goharbor/harbor/src/pkg
GITCOMMIT := $(shell git rev-parse --short=8 HEAD)
RELEASEVERSION := $(shell cat VERSION)
GOFLAGS=-gcflags=all="-N -l"
GOTAGS=$(if $(GOBUILDTAGS),-tags "$(GOBUILDTAGS)",)
GOLDFLAGS=$(if $(GOBUILDLDFLAGS),--ldflags "$(GOBUILDLDFLAGS)",)
CORE_LDFLAGS=-X $(PKG_PATH)/version.GitCommit=$(GITCOMMIT) -X $(PKG_PATH)/version.ReleaseVersion=$(RELEASEVERSION)
ifneq ($(GOBUILDLDFLAGS),)
	CORE_LDFLAGS += $(GOBUILDLDFLAGS)
endif

# go build command
GOIMAGEBUILDCMD=/usr/local/go/bin/go build -mod vendor
GOIMAGEBUILD_COMMON=$(GOIMAGEBUILDCMD) $(GOFLAGS) ${GOTAGS} ${GOLDFLAGS}
GOIMAGEBUILD_CORE=$(GOIMAGEBUILDCMD) $(GOFLAGS) ${GOTAGS} --ldflags "$(CORE_LDFLAGS)"

GOBUILDPATH_CORE=$(GOBUILDPATHINCONTAINER)/src/core
GOBUILDPATH_JOBSERVICE=$(GOBUILDPATHINCONTAINER)/src/jobservice
GOBUILDPATH_REGISTRYCTL=$(GOBUILDPATHINCONTAINER)/src/registryctl
GOBUILDPATH_MIGRATEPATCH=$(GOBUILDPATHINCONTAINER)/src/cmd/migrate-patch
GOBUILDMAKEPATH=make
GOBUILDMAKEPATH_CORE=$(GOBUILDMAKEPATH)/photon/core
GOBUILDMAKEPATH_JOBSERVICE=$(GOBUILDMAKEPATH)/photon/jobservice
GOBUILDMAKEPATH_REGISTRYCTL=$(GOBUILDMAKEPATH)/photon/registryctl
GOBUILDMAKEPATH_NOTARY=$(GOBUILDMAKEPATH)/photon/notary

# binary
CORE_BINARYPATH=$(BUILDPATH)/$(GOBUILDMAKEPATH_CORE)
CORE_BINARYNAME=harbor_core
JOBSERVICEBINARYPATH=$(BUILDPATH)/$(GOBUILDMAKEPATH_JOBSERVICE)
JOBSERVICEBINARYNAME=harbor_jobservice
REGISTRYCTLBINARYPATH=$(BUILDPATH)/$(GOBUILDMAKEPATH_REGISTRYCTL)
REGISTRYCTLBINARYNAME=harbor_registryctl
MIGRATEPATCHBINARYPATH=$(BUILDPATH)/$(GOBUILDMAKEPATH_NOTARY)
MIGRATEPATCHBINARYNAME=migrate-patch

# configfile
CONFIGPATH=$(MAKEPATH)
INSIDE_CONFIGPATH=/compose_location
CONFIGFILE=harbor.yml

# prepare parameters
PREPAREPATH=$(TOOLSPATH)
PREPARECMD=prepare
PREPARECMD_PARA=--conf $(INSIDE_CONFIGPATH)/$(CONFIGFILE)
ifeq ($(NOTARYFLAG), true)
	PREPARECMD_PARA+= --with-notary
endif
ifeq ($(CLAIRFLAG), true)
	PREPARECMD_PARA+= --with-clair
endif
# append chartmuseum parameters if set
ifeq ($(CHARTFLAG), true)
    PREPARECMD_PARA+= --with-chartmuseum
endif

# makefile
MAKEFILEPATH_PHOTON=$(MAKEPATH)/photon

# common dockerfile
DOCKERFILEPATH_COMMON=$(MAKEPATH)/common

# docker image name
DOCKER_IMAGE_NAME_PREPARE=goharbor/prepare
DOCKERIMAGENAME_PORTAL=goharbor/harbor-portal
DOCKERIMAGENAME_CORE=goharbor/harbor-core
DOCKERIMAGENAME_JOBSERVICE=goharbor/harbor-jobservice
DOCKERIMAGENAME_LOG=goharbor/harbor-log
DOCKERIMAGENAME_DB=goharbor/harbor-db
DOCKERIMAGENAME_CHART_SERVER=goharbor/chartmuseum-photon
DOCKERIMAGENAME_REGCTL=goharbor/harbor-registryctl

# docker-compose files
DOCKERCOMPOSEFILEPATH=$(MAKEPATH)
DOCKERCOMPOSETPLFILENAME=docker-compose.tpl
DOCKERCOMPOSEFILENAME=docker-compose.yml
DOCKERCOMPOSENOTARYTPLFILENAME=docker-compose.notary.tpl
DOCKERCOMPOSENOTARYFILENAME=docker-compose.notary.yml
DOCKERCOMPOSECLAIRTPLFILENAME=docker-compose.clair.tpl
DOCKERCOMPOSECLAIRFILENAME=docker-compose.clair.yml
DOCKERCOMPOSECHARTMUSEUMTPLFILENAME=docker-compose.chartmuseum.tpl
DOCKERCOMPOSECHARTMUSEUMFILENAME=docker-compose.chartmuseum.yml

SEDCMD=$(shell which sed)

# package
TARCMD=$(shell which tar)
ZIPCMD=$(shell which gzip)
DOCKERIMGFILE=harbor
HARBORPKG=harbor

# pushimage
PUSHSCRIPTPATH=$(MAKEPATH)
PUSHSCRIPTNAME=pushimage.sh
REGISTRYUSER=user
REGISTRYPASSWORD=default

# cmds
DOCKERSAVE_PARA=$(DOCKER_IMAGE_NAME_PREPARE):$(VERSIONTAG) \
		$(DOCKERIMAGENAME_PORTAL):$(VERSIONTAG) \
		$(DOCKERIMAGENAME_CORE):$(VERSIONTAG) \
		$(DOCKERIMAGENAME_LOG):$(VERSIONTAG) \
		$(DOCKERIMAGENAME_DB):$(VERSIONTAG) \
		$(DOCKERIMAGENAME_JOBSERVICE):$(VERSIONTAG) \
		$(DOCKERIMAGENAME_REGCTL):$(VERSIONTAG) \
		goharbor/redis-photon:$(REDISVERSION) \
		goharbor/nginx-photon:$(NGINXVERSION) goharbor/registry-photon:$(REGISTRYVERSION)-$(VERSIONTAG)

PACKAGE_OFFLINE_PARA=-zcvf harbor-offline-installer-$(PKGVERSIONTAG).tgz \
					$(HARBORPKG)/$(DOCKERIMGFILE).$(VERSIONTAG).tar.gz \
					$(HARBORPKG)/prepare \
					$(HARBORPKG)/LICENSE $(HARBORPKG)/install.sh \
					$(HARBORPKG)/common.sh \
					$(HARBORPKG)/harbor.yml.tmpl

PACKAGE_ONLINE_PARA=-zcvf harbor-online-installer-$(PKGVERSIONTAG).tgz \
					$(HARBORPKG)/prepare \
					$(HARBORPKG)/LICENSE \
					$(HARBORPKG)/install.sh \
					$(HARBORPKG)/common.sh \
					$(HARBORPKG)/harbor.yml.tmpl

DOCKERCOMPOSE_FILE_OPT=-f $(DOCKERCOMPOSEFILEPATH)/$(DOCKERCOMPOSEFILENAME)

ifeq ($(NOTARYFLAG), true)
	DOCKERSAVE_PARA+= goharbor/notary-server-photon:$(NOTARYVERSION)-$(VERSIONTAG) goharbor/notary-signer-photon:$(NOTARYVERSION)-$(VERSIONTAG)
endif
ifeq ($(CLAIRFLAG), true)
	DOCKERSAVE_PARA+= goharbor/clair-photon:$(CLAIRVERSION)-$(VERSIONTAG) goharbor/clair-adapter-photon:$(CLAIRADAPTERVERSION)-$(VERSIONTAG)
endif
ifeq ($(MIGRATORFLAG), true)
	DOCKERSAVE_PARA+= goharbor/harbor-migrator:$(MIGRATORVERSION)
endif
# append chartmuseum parameters if set
ifeq ($(CHARTFLAG), true)
	DOCKERSAVE_PARA+= $(DOCKERIMAGENAME_CHART_SERVER):$(CHARTMUSEUMVERSION)-$(VERSIONTAG)
endif

SWAGGER_IMAGENAME=goharbor/swagger
SWAGGER_VERSION=v0.21.0
SWAGGER=$(DOCKERCMD) run --rm -u $(shell id -u):$(shell id -g) -v $(BUILDPATH):$(BUILDPATH) -w $(BUILDPATH) ${SWAGGER_IMAGENAME}:${SWAGGER_VERSION}
SWAGGER_GENERATE_SERVER=${SWAGGER} generate server --template-dir=$(TOOLSPATH)/swagger/templates --exclude-main

SWAGGER_IMAGENAME:
	@if [ "$(shell ${DOCKERIMASES} -q ${SWAGGER_IMAGENAME}:$(SWAGGER_VERSION) 2> /dev/null)" == "" ]; then \
		${DOCKERBUILD} -f ${TOOLSPATH}/swagger/Dockerfile --build-arg SWAGGER_VERSION=${SWAGGER_VERSION} -t ${SWAGGER_IMAGENAME}:$(SWAGGER_VERSION) . ; \
		echo "build swagger image done"; \
	fi

# $1 the path of swagger spec
# $2 the path of base directory for generating the files
# $3 the name of the application
define swagger_generate_server
	@echo "generate all the files for API from $(1)"
	@rm -rf $(2)/{models,restapi}
	@mkdir -p $(2)
	@$(SWAGGER_GENERATE_SERVER) -f $(1) -A $(3) --target $(2)
endef

gen_apis: SWAGGER_IMAGENAME
	$(call swagger_generate_server,api/v2.0/swagger.yaml,src/server/v2.0,harbor)

export VERSIONS_FOR_PREPARE
versions_prepare:
	@echo "$$VERSIONS_FOR_PREPARE" > $(MAKE_PREPARE_PATH)/$(PREPARE_VERSION_NAME)

check_environment:
	@$(MAKEPATH)/$(CHECKENVCMD)

compile_core: gen_apis
	@echo "compiling binary for core (golang image)..."
	@echo $(GOBUILDPATHINCONTAINER)
	@$(DOCKERCMD) run --rm -v $(BUILDPATH):$(GOBUILDPATHINCONTAINER) -w $(GOBUILDPATH_CORE) $(GOBUILDIMAGE) $(GOIMAGEBUILD_CORE) -o $(GOBUILDPATHINCONTAINER)/$(GOBUILDMAKEPATH_CORE)/$(CORE_BINARYNAME)
	@echo "Done."

compile_jobservice:
	@echo "compiling binary for jobservice (golang image)..."
	@$(DOCKERCMD) run --rm -v $(BUILDPATH):$(GOBUILDPATHINCONTAINER) -w $(GOBUILDPATH_JOBSERVICE) $(GOBUILDIMAGE) $(GOIMAGEBUILD_COMMON) -o $(GOBUILDPATHINCONTAINER)/$(GOBUILDMAKEPATH_JOBSERVICE)/$(JOBSERVICEBINARYNAME)
	@echo "Done."

compile_registryctl:
	@echo "compiling binary for harbor registry controller (golang image)..."
	@$(DOCKERCMD) run --rm -v $(BUILDPATH):$(GOBUILDPATHINCONTAINER) -w $(GOBUILDPATH_REGISTRYCTL) $(GOBUILDIMAGE) $(GOIMAGEBUILD_COMMON) -o $(GOBUILDPATHINCONTAINER)/$(GOBUILDMAKEPATH_REGISTRYCTL)/$(REGISTRYCTLBINARYNAME)
	@echo "Done."

compile_notary_migrate_patch:
	@echo "compiling binary for migrate patch (golang image)..."
	@$(DOCKERCMD) run --rm -v $(BUILDPATH):$(GOBUILDPATHINCONTAINER) -w $(GOBUILDPATH_MIGRATEPATCH) $(GOBUILDIMAGE) $(GOIMAGEBUILD_COMMON) -o $(GOBUILDPATHINCONTAINER)/$(GOBUILDMAKEPATH_NOTARY)/$(MIGRATEPATCHBINARYNAME)
	@echo "Done."

compile: check_environment versions_prepare compile_core compile_jobservice compile_registryctl compile_notary_migrate_patch

prepare:
	@echo "preparing..."
	@$(MAKEPATH)/$(PREPARECMD) $(PREPARECMD_PARA)

build:
	make -f $(MAKEFILEPATH_PHOTON)/Makefile $(BUILDTARGET) -e DEVFLAG=$(DEVFLAG) -e GOBUILDIMAGE=$(GOBUILDIMAGE) \
	 -e REGISTRYVERSION=$(REGISTRYVERSION) -e REGISTRY_SRC_TAG=$(REGISTRY_SRC_TAG) -e NGINXVERSION=$(NGINXVERSION) -e NOTARYVERSION=$(NOTARYVERSION) -e NOTARYMIGRATEVERSION=$(NOTARYMIGRATEVERSION) \
	 -e CLAIRVERSION=$(CLAIRVERSION) -e CLAIRADAPTERVERSION=$(CLAIRADAPTERVERSION) -e VERSIONTAG=$(VERSIONTAG) \
	 -e BUILDBIN=$(BUILDBIN) -e REDISVERSION=$(REDISVERSION) -e MIGRATORVERSION=$(MIGRATORVERSION) \
	 -e CHARTMUSEUMVERSION=$(CHARTMUSEUMVERSION) -e DOCKERIMAGENAME_CHART_SERVER=$(DOCKERIMAGENAME_CHART_SERVER) \
	 -e NPM_REGISTRY=$(NPM_REGISTRY) -e BASEIMAGETAG=$(BASEIMAGETAG)

build_base_docker:
	@for name in chartserver clair clair-adapter core db jobservice log nginx notary-server notary-signer portal prepare redis registry registryctl; do \
		echo $$name ; \
		$(DOCKERBUILD) --pull -f $(MAKEFILEPATH_PHOTON)/$$name/Dockerfile.base -t goharbor/harbor-$$name-base:$(BASEIMAGETAG) . ; \
		$(PUSHSCRIPTPATH)/$(PUSHSCRIPTNAME) goharbor/harbor-$$name-base:$(BASEIMAGETAG) $(REGISTRYUSER) $(REGISTRYPASSWORD) ; \
	done

install: compile build prepare start

package_online:
	@echo "packing online package ..."
	@cp -r make $(HARBORPKG)
	@if [ -n "$(REGISTRYSERVER)" ] ; then \
		$(SEDCMD) -i -e 's/image\: goharbor/image\: $(REGISTRYSERVER)\/$(REGISTRYPROJECTNAME)/' \
		$(HARBORPKG)/docker-compose.yml ; \
	fi
	@cp LICENSE $(HARBORPKG)/LICENSE

	@$(TARCMD) $(PACKAGE_ONLINE_PARA)
	@rm -rf $(HARBORPKG)
	@echo "Done."

package_offline: compile build

	@echo "packing offline package ..."
	@cp -r make $(HARBORPKG)
	@cp LICENSE $(HARBORPKG)/LICENSE

	@echo "saving harbor docker image"
	@$(DOCKERSAVE) $(DOCKERSAVE_PARA) > $(HARBORPKG)/$(DOCKERIMGFILE).$(VERSIONTAG).tar
	@gzip $(HARBORPKG)/$(DOCKERIMGFILE).$(VERSIONTAG).tar

	@$(TARCMD) $(PACKAGE_OFFLINE_PARA)
	@rm -rf $(HARBORPKG)
	@echo "Done."

gosec:
	#go get github.com/securego/gosec/cmd/gosec
	#go get github.com/dghubble/sling
	@echo "run secure go scan ..."
	@if [ "$(GOSECRESULTS)" != "" ] ; then \
		$(GOPATH)/bin/gosec -fmt=json -out=$(GOSECRESULTS) -quiet ./... | true ; \
	else \
		$(GOPATH)/bin/gosec -fmt=json -out=harbor_gas_output.json -quiet ./... | true ; \
	fi

go_check: gen_apis misspell golint govet gofmt commentfmt

gofmt:
	@echo checking gofmt...
	@res=$$(gofmt -d -e -s $$(find . -type d \( -path ./src/vendor -o -path ./tests \) -prune -o -name '*.go' -print)); \
	if [ -n "$${res}" ]; then \
		echo checking gofmt fail... ; \
		echo "$${res}"; \
		exit 1; \
	fi

commentfmt:
	@echo checking comment format...
	@res=$$(find . -type d \( -path ./src/vendor -o -path ./tests \) -prune -o -name '*.go' -print | xargs egrep '(^|\s)\/\/(\S)'); \
	if [ -n "$${res}" ]; then \
		echo checking comment format fail.. ; \
		echo missing whitespace between // and comment body;\
		echo "$${res}"; \
		exit 1; \
	fi

misspell:
	@echo checking misspell...
	@find . -type d \( -path ./src/vendor -o -path ./tests \) -prune -o -name '*.go' -print | xargs misspell -error

golint:
	@echo checking golint...
	@go list ./... | grep -v -E 'vendor|test' | xargs -L1 fgt golint

govet:
	@echo checking govet...
	@go list ./... | grep -v -E 'vendor|test' | xargs -L1 go vet

pushimage:
	@echo "pushing harbor images ..."
	@$(DOCKERTAG) $(DOCKER_IMAGE_NAME_PREPARE):$(VERSIONTAG) $(REGISTRYSERVER)$(DOCKER_IMAGE_NAME_PREPARE):$(VERSIONTAG)
	@$(PUSHSCRIPTPATH)/$(PUSHSCRIPTNAME) $(REGISTRYSERVER)$(DOCKER_IMAGE_NAME_PREPARE):$(VERSIONTAG) \
		$(REGISTRYUSER) $(REGISTRYPASSWORD) $(REGISTRYSERVER)
	@$(DOCKERRMIMAGE) $(REGISTRYSERVER)$(DOCKER_IMAGE_NAME_PREPARE):$(VERSIONTAG)

	@$(DOCKERTAG) $(DOCKERIMAGENAME_PORTAL):$(VERSIONTAG) $(REGISTRYSERVER)$(DOCKERIMAGENAME_PORTAL):$(VERSIONTAG)
	@$(PUSHSCRIPTPATH)/$(PUSHSCRIPTNAME) $(REGISTRYSERVER)$(DOCKERIMAGENAME_PORTAL):$(VERSIONTAG) \
		$(REGISTRYUSER) $(REGISTRYPASSWORD) $(REGISTRYSERVER)
	@$(DOCKERRMIMAGE) $(REGISTRYSERVER)$(DOCKERIMAGENAME_PORTAL):$(VERSIONTAG)

	@$(DOCKERTAG) $(DOCKERIMAGENAME_CORE):$(VERSIONTAG) $(REGISTRYSERVER)$(DOCKERIMAGENAME_CORE):$(VERSIONTAG)
	@$(PUSHSCRIPTPATH)/$(PUSHSCRIPTNAME) $(REGISTRYSERVER)$(DOCKERIMAGENAME_CORE):$(VERSIONTAG) \
		$(REGISTRYUSER) $(REGISTRYPASSWORD) $(REGISTRYSERVER)
	@$(DOCKERRMIMAGE) $(REGISTRYSERVER)$(DOCKERIMAGENAME_CORE):$(VERSIONTAG)

	@$(DOCKERTAG) $(DOCKERIMAGENAME_JOBSERVICE):$(VERSIONTAG) $(REGISTRYSERVER)$(DOCKERIMAGENAME_JOBSERVICE):$(VERSIONTAG)
	@$(PUSHSCRIPTPATH)/$(PUSHSCRIPTNAME) $(REGISTRYSERVER)$(DOCKERIMAGENAME_JOBSERVICE):$(VERSIONTAG) \
		$(REGISTRYUSER) $(REGISTRYPASSWORD) $(REGISTRYSERVER)
	@$(DOCKERRMIMAGE) $(REGISTRYSERVER)$(DOCKERIMAGENAME_JOBSERVICE):$(VERSIONTAG)

	@$(DOCKERTAG) $(DOCKERIMAGENAME_LOG):$(VERSIONTAG) $(REGISTRYSERVER)$(DOCKERIMAGENAME_LOG):$(VERSIONTAG)
	@$(PUSHSCRIPTPATH)/$(PUSHSCRIPTNAME) $(REGISTRYSERVER)$(DOCKERIMAGENAME_LOG):$(VERSIONTAG) \
		$(REGISTRYUSER) $(REGISTRYPASSWORD) $(REGISTRYSERVER)
	@$(DOCKERRMIMAGE) $(REGISTRYSERVER)$(DOCKERIMAGENAME_LOG):$(VERSIONTAG)

	@$(DOCKERTAG) $(DOCKERIMAGENAME_DB):$(VERSIONTAG) $(REGISTRYSERVER)$(DOCKERIMAGENAME_DB):$(VERSIONTAG)
	@$(PUSHSCRIPTPATH)/$(PUSHSCRIPTNAME) $(REGISTRYSERVER)$(DOCKERIMAGENAME_DB):$(VERSIONTAG) \
		$(REGISTRYUSER) $(REGISTRYPASSWORD) $(REGISTRYSERVER)
	@$(DOCKERRMIMAGE) $(REGISTRYSERVER)$(DOCKERIMAGENAME_DB):$(VERSIONTAG)

start:
	@echo "loading harbor images..."
	@$(DOCKERCOMPOSECMD) $(DOCKERCOMPOSE_FILE_OPT) up -d
	@echo "Start complete. You can visit harbor now."

down:
	@while [ -z "$$CONTINUE" ]; do \
        read -r -p "Type anything but Y or y to exit. [Y/N]: " CONTINUE; \
    done ; \
    [ $$CONTINUE = "y" ] || [ $$CONTINUE = "Y" ] || (echo "Exiting."; exit 1;)
	@echo "stoping harbor instance..."
	@$(DOCKERCOMPOSECMD) $(DOCKERCOMPOSE_FILE_OPT) down -v
	@echo "Done."

swagger_client:
	@echo "Generate swagger client"
	wget -q http://central.maven.org/maven2/io/swagger/swagger-codegen-cli/2.3.1/swagger-codegen-cli-2.3.1.jar -O swagger-codegen-cli.jar
	rm -rf harborclient
	mkdir harborclient
	java -jar swagger-codegen-cli.jar generate -i api/harbor/swagger.yaml -l python -o harborclient
	cd harborclient; python ./setup.py install
	pip install docker -q
	pip freeze

cleanbinary:
	@echo "cleaning binary..."
	if [ -f $(CORE_BINARYPATH)/$(CORE_BINARYNAME) ] ; then rm $(CORE_BINARYPATH)/$(CORE_BINARYNAME) ; fi
	if [ -f $(JOBSERVICEBINARYPATH)/$(JOBSERVICEBINARYNAME) ] ; then rm $(JOBSERVICEBINARYPATH)/$(JOBSERVICEBINARYNAME) ; fi
	if [ -f $(REGISTRYCTLBINARYPATH)/$(REGISTRYCTLBINARYNAME) ] ; then rm $(REGISTRYCTLBINARYPATH)/$(REGISTRYCTLBINARYNAME) ; fi
	if [ -f $(MIGRATEPATCHBINARYPATH)/$(MIGRATEPATCHBINARYNAME) ] ; then rm $(MIGRATEPATCHBINARYPATH)/$(MIGRATEPATCHBINARYNAME) ; fi
	rm -rf make/photon/*/binary/


cleanimage:
	@echo "cleaning image for photon..."
	- $(DOCKERRMIMAGE) -f $(DOCKERIMAGENAME_CORE):$(VERSIONTAG)
	- $(DOCKERRMIMAGE) -f $(DOCKERIMAGENAME_DB):$(VERSIONTAG)
	- $(DOCKERRMIMAGE) -f $(DOCKERIMAGENAME_JOBSERVICE):$(VERSIONTAG)
	- $(DOCKERRMIMAGE) -f $(DOCKERIMAGENAME_LOG):$(VERSIONTAG)

cleandockercomposefile:
	@echo "cleaning docker-compose files in $(DOCKERCOMPOSEFILEPATH)"
	@find $(DOCKERCOMPOSEFILEPATH) -maxdepth 1 -name "docker-compose*.yml" -exec rm -f {} \;
	@find $(DOCKERCOMPOSEFILEPATH) -maxdepth 1 -name "docker-compose*.yml-e" -exec rm -f {} \;

cleanpackage:
	@echo "cleaning harbor install package"
	@if [ -d $(BUILDPATH)/harbor ] ; then rm -rf $(BUILDPATH)/harbor ; fi
	@if [ -f $(BUILDPATH)/harbor-online-installer-$(VERSIONTAG).tgz ] ; \
	then rm $(BUILDPATH)/harbor-online-installer-$(VERSIONTAG).tgz ; fi
	@if [ -f $(BUILDPATH)/harbor-offline-installer-$(VERSIONTAG).tgz ] ; \
	then rm $(BUILDPATH)/harbor-offline-installer-$(VERSIONTAG).tgz ; fi

cleanconfig:
	@echo "clean generated config files"
	rm -f $(BUILDPATH)/make/photon/prepare/versions
	rm -f $(BUILDPATH)/UIVERSION
	rm -rf $(BUILDPATH)/make/common
	rm -rf $(BUILDPATH)/harborclient
	rm -rf $(BUILDPATH)/src/portal/dist
	rm -rf $(BUILDPATH)/src/portal/lib/dist
	rm -f $(BUILDPATH)/src/portal/proxy.config.json

.PHONY: cleanall
cleanall: cleanbinary cleanimage cleandockercomposefile cleanconfig cleanpackage

clean:
	@echo "  make cleanall:		remove binary, Harbor images, specific version docker-compose"
	@echo "		file, specific version tag, online and offline install package"
	@echo "  make cleanbinary:		remove core and jobservice binary"
	@echo "  make cleanimage:		remove Harbor images"
	@echo "  make cleandockercomposefile:	remove specific version docker-compose"
	@echo "  make cleanpackage:		remove online and offline install package"

all: install
